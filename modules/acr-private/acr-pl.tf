# Add new variables for naming
variable "deployment_environment" {
  type        = string
  description = "Deployment environment (e.g., 'dev', 'prod')"
}

variable "organisation_id" {
  type        = string
  description = "Organization identifier"
}

variable "location_short" {
  type        = string
  description = "Short location identifier (e.g., 'ea' for East Asia)"
}

# Azure Container Registry with Private Link Configuration
resource "azurerm_container_registry" "acr" {
  # Format: acr-{org_id}-{env}-{location}-{name}
  name                          = lower(replace("acr-${var.organisation_id}-${var.deployment_environment}-${var.location_short}-${var.acrname}", "-", ""))
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku                         = "Premium"
  admin_enabled               = false
  public_network_access_enabled = false
  zone_redundancy_enabled     = true
  export_policy_enabled       = false
  
  network_rule_set {
    default_action = "Deny"
  }

  retention_policy {
    days    = 7
    enabled = true
  }

  trust_policy {
    enabled = false
  }

  tags = var.tags
}

# Private Endpoint Configuration
resource "azurerm_private_endpoint" "acr_pe_hub" {
  name                = "${var.acrname}-pe-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.hub_subnet_id

  private_service_connection {
    name                           = "${var.acrname}-psc-hub"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection          = false
    subresource_names            = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_zone_id]
  }
}

resource "azurerm_private_endpoint" "acr_pe_spoke" {
  name                = "${var.acrname}-pe-spoke"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.spoke_subnet_id

  private_service_connection {
    name                           = "${var.acrname}-psc-spoke"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection          = false
    subresource_names            = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_zone_id]
  }
}

# Variables
variable "acrname" {
  type        = string
  description = "Name of the Azure Container Registry"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure region location"
}

variable "aks_sub_id" {
  type        = string
  description = "Subscription ID where AKS is deployed"
}

variable "private_zone_id" {
  type        = string
  description = "ID of the private DNS zone for ACR"
}

variable "hub_subnet_id" {
  type        = string
  description = "ID of the subnet in hub VNET for private endpoint"
}

variable "spoke_subnet_id" {
  type        = string
  description = "ID of the subnet in spoke VNET for private endpoint"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

# Outputs
output "acr_id" {
  description = "The ID of the Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  description = "The login server URL for the Container Registry"
  value       = azurerm_container_registry.acr.login_server
}