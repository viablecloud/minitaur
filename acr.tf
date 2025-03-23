# Azure Container Registry (ACR) Configuration
# This configuration creates a private ACR instance accessible only through private endpoints
# from designated subnets in both the hub and spoke VNets.

# Create a dedicated Resource Group for ACR
# Best practice: Separate resource group for better lifecycle management and access control
resource "azurerm_resource_group" "acr_rg" {
  name     = "rg-acr-001"
  location = var.primary_location

  tags = {
    environment = "production"
    purpose     = "container-registry"
  }
}

# Create Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.acr_rg.name
}

# Link Private DNS Zone to VNets
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "hub-vnet-link"
  resource_group_name   = azurerm_resource_group.acr_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = module.spoke_virtual_network.virtual_network_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  name                  = "spoke-vnet-link"
  resource_group_name   = azurerm_resource_group.acr_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = module.vnet_secondary.virtual_network_id
}

# Get current subscription details
data "azurerm_client_config" "current" {}

# Deploy Azure Container Registry using the private ACR module
# This module sets up a premium tier registry with private endpoint access
module "acr" {
  source = "./modules/acr-private"

  # Basic configuration
  acrname             = "001"  # Shortened to just a number since other parts will be added
  resource_group_name = azurerm_resource_group.acr_rg.name
  location            = azurerm_resource_group.acr_rg.location
  
  # Naming components
  deployment_environment = var.deployment_environment
  organisation_id       = var.organisation_id
  location_short        = var.location_short
  
  # Network configuration
  aks_sub_id         = data.azurerm_client_config.current.subscription_id
  private_zone_id    = azurerm_private_dns_zone.acr.id
  hub_subnet_id      = module.spoke_virtual_network.subnet_ids_map["subnet-001"]
  spoke_subnet_id    = module.vnet_secondary.subnet_ids_map["aks-subnet"]
}

# Add role assignments for AKS to pull images
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity[0].object_id
}

# Additional Security Considerations:
# 1. Network Security:
#    - Only private endpoints are enabled
#    - No public access is allowed
#    - Separate endpoints for different VNets
#
# 2. Authentication:
#    - Admin account is disabled
#    - RBAC is used for access control
#    - Anonymous access is disabled
#
# 3. Data Protection:
#    - Zone redundancy is enabled
#    - Retention policy is configured
#    - Export policy is disabled
#
# 4. Monitoring and Compliance:
#    - Tags are applied for resource tracking
#    - Premium SKU enables advanced security features 
