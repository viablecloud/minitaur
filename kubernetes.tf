/*
This configuration provides a fully functional kubernetes cluster with ingress based on Azure Application Gateway.
It demonstrates how top deploy your applications to kubernetes and get them accessible from the public internet, i.e:

1. A simple NGINX deployment defined in terraform (non-https).
2. A simple NGINX deployment using TLS/HTTPS
3. A kubernetes-based TLS solution used to issue certificates to services deployed on the cluster ("cert-manager") 
4. Configuration on the Application Gateway required to make your applications accessible from the internet.

Use this foundational configuration to develop your own complex application on kubernetes!
*/

// Dedicated resource group for AKS cluster
resource "azurerm_resource_group" "lz000_aks000_rg" {
  name     = "lz000_aks000_rg"
  location = var.primary_location
  tags = {
    owner     = local.tags_lz000_aks000["owner"]
    team      = local.tags_lz000_aks000["team"]
    lifecycle = local.tags_lz000_aks000["lifecycle"]
    expiry    = local.tags_lz000_aks000["expiry_date"]
  }
}

resource "random_id" "prefix" {
  byte_length = 8
}

resource "random_id" "name" {
  byte_length = 8
}

resource "azurerm_resource_group" "main" {
  count    = var.create_resource_group ? 1 : 0
  location = var.primary_location
  name     = coalesce("${resource.azurerm_resource_group.lz000_aks000_rg.name}", "${random_id.prefix.hex}-rg")
}

# Locals block for hardcoded names
locals {
  backend_address_pool_name      = try("hub-vnet-lz000-net-beap", "")
  frontend_ip_configuration_name = try("hub-vnet-lz000-net-feip", "")
  frontend_port_name             = try("hub-vnet-lz000-net-feport", "")
  http_setting_name              = try("hub-vnet-lz000-net-be-htst", "")
  listener_name                  = try("hub-vnet-lz000-net-httplstn", "")
  request_routing_rule_name      = try("hub-vnet-lz000-net-rqrt", "")
}

resource "azurerm_public_ip" "pip" {
  count = var.use_brown_field_application_gateway && var.bring_your_own_vnet ? 1 : 0

  allocation_method   = "Static"
  location            = resource.azurerm_resource_group.lz000_aks000_rg.location
  name                = "appgw-pip"
  resource_group_name = resource.azurerm_resource_group.lz000_aks000_rg.name
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  count               = var.use_brown_field_application_gateway && var.bring_your_own_vnet ? 1 : 0
  location            = local.resource_group.location
  name                = "ingress"
  resource_group_name = resource.azurerm_resource_group.lz000_aks000_rg.name

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    cookie_based_affinity = "Disabled"
    name                  = local.http_setting_name
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 20
    probe_name           = "jenkins-probe"
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pip[0].id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = module.vnet_secondary.subnet_ids_map["gateway"]
  }

  http_listener {
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    name                           = local.listener_name
    protocol                       = "Http"
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name            = "https-port"
    protocol                      = "Https"
    ssl_certificate_name          = "jenkins-tls-cert"
  }

  request_routing_rule {
    http_listener_name         = local.listener_name
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }

  probe {
    name                = "jenkins-probe"
    host                = "cicd.viable.one"
    protocol            = "Http"
    path                = "/login"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
  }

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
    ]
  }
}

# Create a local variable for the body content
locals {
  aks_update_properties = {
    properties = {
      kubernetesVersion = "1.29"
    }
  }
}

module "aks" {
  #checkov:skip=CKV_AZURE_141:We enable admin account here so we can provision K8s resources directly in this simple example
  source = "./modules/avm-aks-7.3.0"

  prefix                    = random_id.name.hex
  resource_group_name       = resource.azurerm_resource_group.lz000_aks000_rg.name
  kubernetes_version        = "1.29" # don't specify the patch version!
  automatic_channel_upgrade = "patch"
  agents_availability_zones = ["1", "2"]
  agents_count              = null
  agents_max_count          = 3
  agents_max_pods           = 100
  agents_min_count          = 2
  agents_pool_name          = "nodepool000"
  agents_pool_linux_os_configs = [
    {
      transparent_huge_page_enabled = "always"
      sysctl_configs = [
        {
          fs_aio_max_nr               = 65536
          fs_file_max                 = 100000
          fs_inotify_max_user_watches = 1000000
        }
      ]
    }
  ]
  agents_type            = "VirtualMachineScaleSets"
  azure_policy_enabled   = false
  enable_auto_scaling    = true
  enable_host_encryption = false

  providers = {
    azapi = azapi.v1
  }

  green_field_application_gateway_for_ingress = var.use_brown_field_application_gateway ? null : {
    name        = "ingress"
    subnet_cidr = local.appgw_cidr
  }

  brown_field_application_gateway_for_ingress = null

  create_role_assignments_for_application_gateway = var.create_role_assignments_for_application_gateway
  local_account_disabled                          = false
  log_analytics_workspace_enabled                 = false
  net_profile_dns_service_ip                      = "10.0.0.10"
  net_profile_service_cidr                        = "10.0.0.0/16"
  network_plugin                                  = "azure"
  network_policy                                  = "azure"
  os_disk_size_gb                                 = 60
  private_cluster_enabled                         = false
  rbac_aad                                        = true
  rbac_aad_managed                                = true
  role_based_access_control_enabled               = true
  sku_tier                                        = "Standard"
  vnet_subnet_id                                  = module.vnet_secondary.subnet_ids_map["aks-subnet"]

  depends_on = [
    azurerm_resource_group.lz000_aks000_rg
  ]
}

# Create an override for the azapi_update_resource
resource "azapi_update_resource" "aks_cluster_post_create_override" {
  type        = "Microsoft.ContainerService/managedClusters@2023-07-02-preview"
  resource_id = module.aks.aks_id
  body        = local.aks_update_properties

  depends_on = [
    module.aks
  ]
}

# Add provider configuration for azapi v1
provider "azapi" {
  alias = "v1"
}

//Variable Settings
variable "bring_your_own_vnet" {
  type    = bool
  default = true
}

variable "create_resource_group" {
  type     = bool
  default  = false
  nullable = false
}

variable "create_role_assignments_for_application_gateway" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type    = string
  default = "aks-primary"
}

variable "use_brown_field_application_gateway" {
  type    = bool
  default = false
}

locals {
  appgw_cidr = !var.use_brown_field_application_gateway && !var.bring_your_own_vnet ? "10.225.0.0/16" : "10.216.63.0/24" //This must be a valid CIDR block for the subnet and selected from AKS assigned subnet.
  resource_group = {
    name     = var.create_resource_group ? resource.azurerm_resource_group.lz000_aks000_rg.name : var.resource_group_name
    location = var.primary_location
  }

  tags_lz000_aks000 = {
    owner       = "matt@whconsultancy.co"
    team        = "apps"
    lifecycle   = "active"
    expiry_date = "15122025"
  }


}

// Avoid this in production. We use it to bootstrap initial deployment until 
//you have TLS PKI infrastructure in place
provider "kubernetes" {
  host                   = module.aks.admin_host
  client_certificate     = base64decode(module.aks.admin_client_certificate)
  client_key             = base64decode(module.aks.admin_client_key)
  cluster_ca_certificate = base64decode(module.aks.admin_cluster_ca_certificate)
}

// Add this to your existing providers block
provider "helm" {
  kubernetes {
    host                   = module.aks.admin_host
    client_certificate     = base64decode(module.aks.admin_client_certificate)
    client_key             = base64decode(module.aks.admin_client_key)
    cluster_ca_certificate = base64decode(module.aks.admin_cluster_ca_certificate)
  }
}

# Create namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  depends_on = [
    module.aks
  ]
}

# Install cert-manager using Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.3"
  create_namespace = false

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.cert_manager.metadata[0].name
  }

  # Add webhook configurations
  set {
    name  = "webhook.enabled"
    value = "true"
  }

  set {
    name  = "webhook.timeoutSeconds"
    value = "30"
  }

  # Add security context
  set {
    name  = "securityContext.enabled"
    value = "true"
  }

  # Add more detailed logging
  set {
    name  = "global.logLevel"
    value = "4"  # Debug level logging
  }

  depends_on = [
    kubernetes_namespace.cert_manager
  ]
}

# Create a Role for cert-manager namespace-specific permissions
resource "kubernetes_role" "cert_manager_namespace_role" {
  metadata {
    name      = "cert-manager-namespace-role"
    namespace = "cert-manager"
  }

  rule {
    api_groups = [""]  # Core API group
    resources  = ["pods", "services", "secrets", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }
}

# Create a RoleBinding for namespace-specific permissions
resource "kubernetes_role_binding" "cert_manager_namespace_binding" {
  metadata {
    name      = "cert-manager-namespace-binding"
    namespace = "cert-manager"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.cert_manager_namespace_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "internal-kubectl"
    namespace = "minitaur"
  }
}

# Certificate Management Service Account Configuration
# Purpose: Creates a dedicated service account for secure certificate operations
# Location: cert-manager namespace (standard namespace for certificate management)
# Usage: This service account will be used to:
#   - Create and manage TLS certificates
#   - Handle certificate signing requests
#   - Manage certificate secrets
#   - Interface with the cluster issuer
resource "kubernetes_service_account" "cert_manager_ops" {
  metadata {
    name      = "cert-manager-ops"
    namespace = "cert-manager"  # Isolated namespace for certificate operations
  }
}

# Certificate Manager RBAC Configuration
# Purpose: Defines granular permissions for certificate management operations
# Scope: Cluster-wide permissions (ClusterRole)
# Operations allowed:
#   - Namespace operations: For creating/managing certificate namespaces
#   - Secret operations: For storing TLS certificates
#   - Certificate operations: For managing cert-manager resources
resource "kubernetes_cluster_role" "cert_manager_ops" {
  metadata {
    name = "cert-manager-ops"
  }

  rule {
    # Core Kubernetes API permissions
    # Required for: 
    #   - Creating namespaces for certificate isolation
    #   - Managing TLS secrets across namespaces
    api_groups = [""]
    resources  = ["namespaces", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    # Cert-manager specific API permissions
    # Required for:
    #   - Certificate resource management
    #   - Certificate request handling
    #   - ClusterIssuer configuration
    api_groups = ["cert-manager.io"]
    resources  = ["certificates", "certificaterequests", "clusterissuers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# RBAC Binding Configuration
# Purpose: Associates the permissions with the service account
# Scope: Cluster-wide (ClusterRoleBinding)
# Links: 
#   - ServiceAccount: cert-manager-ops
#   - ClusterRole: cert-manager-ops
# This binding enables the service account to perform certificate operations
resource "kubernetes_cluster_role_binding" "cert_manager_ops" {
  metadata {
    name = "cert-manager-ops"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cert_manager_ops.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cert_manager_ops.metadata[0].name
    namespace = kubernetes_service_account.cert_manager_ops.metadata[0].namespace
  }
}

# Self-Signed Certificate Issuer Configuration
# Purpose: Creates a cluster-wide certificate issuer for TLS certificates
# Type: Self-signed (suitable for development/testing)
# Usage: Will be used as the root CA for all certificates
# Note: For production, consider using Let's Encrypt or other trusted CAs
resource "local_file" "selfsigned_cluster_issuer" {
  filename = "./selfsigned-cluster-issuer.yaml"
  content  = <<-EOT
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOT
}

# TLS Certificate Configuration
# Purpose: Defines the TLS certificate for HTTPS encryption
# Details:
#   - Name: jenkins-tls
#   - Namespace: jenkins
#   - DNS: cicd.viable.one
#   - Secret: jenkins-tls-secret (will contain the certificate)
# Usage: Will be used by Application Gateway for SSL termination
resource "local_file" "jenkins_certificate" {
  filename = "./jenkins-certificate.yaml"
  content  = <<-EOT
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: jenkins-tls
  namespace: jenkins
spec:
  secretName: jenkins-tls-secret
  dnsNames:
  - cicd.viable.one
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOT
}

# Certificate Application and Verification Process
# Purpose: Handles the actual creation and verification of certificates
# Process Flow:
#   1. Creates temporary kubeconfig with service account credentials
#   2. Ensures jenkins namespace exists
#   3. Creates the cluster issuer
#   4. Waits for issuer readiness
#   5. Creates the certificate
#   6. Verifies all resources are created
#   7. Cleans up temporary credentials
resource "null_resource" "apply_certificate" {
  triggers = {
    # Trigger recreation if certificate configurations change
    manifest_sha1 = sha1(join("", [
      local_file.selfsigned_cluster_issuer.content,
      local_file.jenkins_certificate.content
    ]))
  }

  provisioner "local-exec" {
    command = <<EOF
      # Step 1: Service Account Authentication Setup
      # Creates a temporary kubeconfig with the cert-manager service account's credentials
      # This ensures secure, isolated certificate operations
      SA_SECRET=$(kubectl -n cert-manager get serviceaccount ${kubernetes_service_account.cert_manager_ops.metadata[0].name} -o jsonpath='{.secrets[0].name}')
      SA_TOKEN=$(kubectl -n cert-manager get secret $SA_SECRET -o jsonpath='{.data.token}' | base64 --decode)
      
      # Step 2: Temporary Kubeconfig Creation
      # Creates a dedicated kubeconfig for certificate operations
      # Includes:
      #   - Cluster information
      #   - Service account token
      #   - Context configuration
      cat << KUBECONFIG > /tmp/cert-manager-kubeconfig
      apiVersion: v1
      kind: Config
      clusters:
      - name: cluster
        cluster:
          certificate-authority-data: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
          server: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
      contexts:
      - name: cert-manager-context
        context:
          cluster: cluster
          user: cert-manager-ops
      current-context: cert-manager-context
      users:
      - name: cert-manager-ops
        user:
          token: $SA_TOKEN
      KUBECONFIG
      
      # Step 3: Certificate Resource Creation
      export KUBECONFIG=/tmp/cert-manager-kubeconfig
      
      # Create namespace (idempotent operation)
      kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
      
      # Apply cluster issuer configuration
      kubectl apply -f ${local_file.selfsigned_cluster_issuer.filename}
      
      # Wait for issuer readiness
      echo "Waiting for ClusterIssuer..."
      sleep 5
      
      # Create certificate (triggers secret creation)
      kubectl apply -f ${local_file.jenkins_certificate.filename}
      
      # Allow time for secret creation
      echo "Waiting for secret..."
      sleep 10
      
      # Step 4: Verification
      # Verify all components are created successfully
      kubectl get clusterissuer selfsigned-issuer
      kubectl get certificate -n jenkins jenkins-tls
      kubectl get secret -n jenkins jenkins-tls-secret
      
      # Step 5: Cleanup
      rm -f /tmp/cert-manager-kubeconfig
    EOF
  }

  depends_on = [
    kubernetes_cluster_role_binding.cert_manager_ops,
    kubernetes_service_account.cert_manager_ops
  ]
}

# HTTPS Ingress Configuration
# Purpose: Configures Application Gateway for HTTPS traffic
# Features:
#   - SSL termination at Application Gateway
#   - Automatic HTTP to HTTPS redirection
#   - Custom timeout settings
#   - Backend HTTP communication
resource "kubernetes_ingress_v1" "ing2" {
  metadata {
    name      = "nginxssl-service"
    namespace = "jenkins"
    annotations = {
      # Application Gateway Configuration
      "kubernetes.io/ingress.class" = "azure/application-gateway"  # Use Azure Application Gateway ingress
      
      # SSL/TLS Configuration
      "appgw.ingress.kubernetes.io/ssl-redirect" = "true"         # Force HTTPS
      "appgw.ingress.kubernetes.io/ssl-certificate" = "jenkins-tls-secret"  # TLS certificate reference
      
      # Protocol and Port Configuration
      "appgw.ingress.kubernetes.io/backend-protocol" = "HTTP"     # Backend communication protocol
      "appgw.ingress.kubernetes.io/frontend-port" = "443"         # HTTPS port
      
      # Performance Configuration
      "appgw.ingress.kubernetes.io/request-timeout" = "20"        # Request timeout in seconds
    }
  }

  spec {
    # TLS Configuration
    # Defines the certificate and domain for HTTPS
    tls {
      secret_name = "jenkins-tls-secret"  # Must match the certificate's secretName
      hosts       = ["cicd.viable.one"]   # Domain name for HTTPS
    }
    
    # Traffic Routing Configuration
    # Defines how incoming requests are handled
    rule {
      host = "cicd.viable.one"  # Domain name for routing
      http {
        path {
          path      = "/"       # Root path
          path_type = "Prefix"  # Match all paths starting with /
          backend {
            service {
              name = "nginxssl-service"  # Target service
              port {
                number = 80     # Service port (internal HTTP)
              }
            }
          }
        }
      }
    }
  }

  # Ensure certificate exists before creating ingress
  depends_on = [
    null_resource.apply_certificate
  ]
}

# Create a cluster role binding for Azure AD user
resource "kubernetes_cluster_role_binding" "admin_user" {
  metadata {
    name = "azure-ad-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"  # Using built-in cluster-admin role
  }

  subject {
    kind      = "User"
    name      = "f106c660-ecc4-4f31-b3ca-f96a6709714b"  # Your Azure AD User Object ID
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    module.aks
  ]
}

# Keep only these debug resources
output "app_gateway_info" {
  value = {
    resource_group = resource.azurerm_resource_group.lz000_aks000_rg.name
    location      = resource.azurerm_resource_group.lz000_aks000_rg.location
  }
}

# Create a dedicated service account for debugging
resource "kubernetes_service_account" "debug_sa" {
  metadata {
    name      = "debug-sa"
    namespace = "kube-system"
  }
}

# Create a ClusterRole with the necessary permissions
resource "kubernetes_cluster_role" "debug_role" {
  metadata {
    name = "debug-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "secrets", "services", "namespaces", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates", "certificaterequests", "clusterissuers"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }
}

# Bind the role to the service account
resource "kubernetes_cluster_role_binding" "debug_binding" {
  metadata {
    name = "debug-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.debug_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.debug_sa.metadata[0].name
    namespace = kubernetes_service_account.debug_sa.metadata[0].namespace
  }
}

# Single debug script using the new service account
resource "null_resource" "debug_appgw" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      # Get the token for the debug service account
      echo "Getting service account token..."
      TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get serviceaccount debug-sa -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode)

      # Create temporary kubeconfig
      echo "Creating temporary kubeconfig..."
      cat << KUBECONFIG > /tmp/debug-kubeconfig
      apiVersion: v1
      kind: Config
      clusters:
      - name: cluster
        cluster:
          certificate-authority-data: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
          server: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
      contexts:
      - name: debug-context
        context:
          cluster: cluster
          user: debug-sa
      current-context: debug-context
      users:
      - name: debug-sa
        user:
          token: $TOKEN
      KUBECONFIG

      export KUBECONFIG=/tmp/debug-kubeconfig

      echo "=== Starting Debug Analysis ==="

      echo "1. Finding Application Gateway name..."
      APP_GW_NAME=$(az network application-gateway list \
        --resource-group ${resource.azurerm_resource_group.lz000_aks000_rg.name} \
        --query "[0].name" -o tsv)
      echo "Application Gateway found: $APP_GW_NAME"

      if [ ! -z "$APP_GW_NAME" ]; then
        echo "2. Checking Application Gateway configuration..."
        az network application-gateway show \
          --name $APP_GW_NAME \
          --resource-group ${resource.azurerm_resource_group.lz000_aks000_rg.name} \
          --query '{frontendPorts:frontendPorts[].{name:name,port:port},httpListeners:httpListeners[].{name:name,protocol:protocol}}' \
          -o table
      fi

      echo "3. Checking AGIC pod..."
      kubectl get pods -n kube-system -l app=ingress-appgw

      echo "4. Checking ingress configuration..."
      kubectl get ingress -n jenkins nginxssl-service -o yaml

      echo "5. Checking certificate..."
      kubectl get certificate -n jenkins jenkins-tls -o yaml

      # Cleanup
      rm -f /tmp/debug-kubeconfig

      echo "=== Debug Analysis Complete ==="
    EOF
  }

  depends_on = [
    kubernetes_cluster_role_binding.debug_binding,
    kubernetes_ingress_v1.ing2,
    null_resource.apply_certificate
  ]
}

output "aks_info" {
  value = {
    node_resource_group = module.aks.node_resource_group
    resource_group     = resource.azurerm_resource_group.lz000_aks000_rg.name
  }
}

