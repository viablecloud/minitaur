//Azure Storage Architecture
//This configuration implements Azure Storage using Microsoft's "Azure Verified Modules" (AVM)
//The architecture consists of two storage accounts:
//1. A primary storage account for general-purpose storage
//2. A secondary storage account dedicated to AKS cluster storage needs

//1. Resource Naming Configuration
//Uses Azure CAF (Cloud Adoption Framework) naming module to ensure consistent, compliant resource naming
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
}

//2. Region Configuration
//Defines available regions for storage account deployment
locals {
  test_regions = ["eastasia", "southeastasia"]
}

//3. Region Selection
//Randomly selects a region from the available regions for deployment
resource "random_integer" "region_index" {
  max = length(local.test_regions) - 1
  min = 0
}

//4. Resource Name Randomization
//Ensures unique resource names across Azure
resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}

//5. Primary Storage Resource Group
//Creates a dedicated resource group for the primary storage account
resource "azurerm_resource_group" "this" {
  location = var.primary_location
  name     = module.naming.resource_group.name_unique
}

//6. Managed Service Identity Configuration
//Creates a User-Assigned MSI for storage account authentication
resource "azurerm_user_assigned_identity" "storage_msi" {
  name                = "storage-msi"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

//7. IP Configuration for Storage Access
//Variable to bypass IP CIDR restrictions if needed
variable "bypass_ip_cidr" {
  type        = string
  default     = null
  description = "value to bypass the IP CIDR on firewall rules"
}

//8. MSI Output Configuration
//Provides necessary MSI information for other resources
output "msi_id" {
  description = "The ID of the User-Assigned Managed Service Identity."
  value       = azurerm_user_assigned_identity.storage_msi.id
}

output "msi_principal_id" {
  description = "The Principal ID (Object ID) of the Managed Service Identity."
  value       = azurerm_user_assigned_identity.storage_msi.principal_id
}

output "msi_client_id" {
  description = "The Client ID of the Managed Service Identity."
  value       = azurerm_user_assigned_identity.storage_msi.client_id
}

//9. Public IP Configuration
//Required for storage account creation but not used for internet communication
module "public_ip" {
  count   = var.bypass_ip_cidr == null ? 1 : 0
  source  = "lonegunmanb/public-ip/lonegunmanb"
  version = "0.1.0"
}

//10. Azure AD Configuration
//Gets current user's object_id for role assignments
//data "azurerm_client_config" "current" {}

//11. Additional Identity Configuration
//Creates an additional MSI for enhanced security options
resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

//12. Role Definition Configuration
//Gets the Contributor role definition for role assignments
data "azurerm_role_definition" "example" {
  name = "Contributor"
}

//13. Primary Storage Account Configuration
//Deploys the main storage account with comprehensive security and networking settings
module "this" {
  source = "./modules/terraform-azurerm-avm-res-storage-storageaccount"

  # Basic Configuration
  account_replication_type = "ZRS" // Zone Redundant Storage for high availability
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  location                 = azurerm_resource_group.this.location
  name                     = module.naming.storage_account.name_unique

  # Security Configuration
  https_traffic_only_enabled    = true
  resource_group_name           = azurerm_resource_group.this.name
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = true
  public_network_access_enabled = true

  # Identity Configuration
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  # Authentication Configuration
  azure_files_authentication = {
    default_share_level_permission = "StorageFileDataSmbShareReader"
    directory_type                 = "AADKERB"
  }

  # Tagging
  tags = {
    env   = "Dev"
    owner = "Mini Taur"
    dept  = "IT"
  }

  # Blob Configuration
  blob_properties = {
    versioning_enabled = true
  }

  # Role Assignments
  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name       = data.azurerm_role_definition.example.name
      principal_id                     = coalesce(azurerm_user_assigned_identity.storage_msi.principal_id, data.azurerm_client_config.current.object_id)
      skip_service_principal_aad_check = false
    },
    role_assignment_2 = {
      role_definition_id_or_name       = "Owner"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    },
  }

  # Network Rules
  network_rules = {
    bypass         = ["AzureServices"]
    default_action = "Deny"
    ip_rules       = [try(module.public_ip[0].public_ip, var.bypass_ip_cidr)]
    virtual_network_subnet_ids = toset(
      [
        module.spoke_virtual_network.subnet_ids_map["sbnt-000"],
        module.spoke_virtual_network.subnet_ids_map["subnet-001"],
        module.spoke_virtual_network.subnet_ids_map["subnet-003"],
        module.spoke_virtual_network.subnet_ids_map["subnet-004"]
    ])
  }

  # Container Configuration
  containers = {
    blob_container0 = {
      name = "blob-container-example-0"
    }
    blob_container1 = {
      name = "blob-container-example-1"
    }
  }

  # File Share Configuration
  shares = {
    share0 = {
      name  = "share-common-0"
      quota = 10
      signed_identifiers = [
        {
          id = "1"
          access_policy = {
            expiry_time = "2025-01-01T00:00:00Z"
            permission  = "r"
            start_time  = "2024-01-01T00:00:00Z"
          }
        }
      ]
    }
    share1 = {
      name        = "share-common-1"
      quota       = 10
      access_tier = "Hot"
      metadata = {
        key1 = "value1"
        key2 = "value2"
      }
    }
  }
}

//14. AKS Storage Configuration
//Additional naming module for AKS storage resources
module "naming_aks_storage" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
}

//15. AKS Storage Resource Group
//Creates a dedicated resource group for AKS storage
resource "azurerm_resource_group" "that" {
  location = var.primary_location
  name     = module.naming_aks_storage.resource_group.name_unique
}

//16. AKS Storage Account
//Deploys a storage account specifically for AKS cluster needs
module "that" {
  source = "./modules/terraform-azurerm-avm-res-storage-storageaccount"

  # Basic Configuration
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  location                 = azurerm_resource_group.this.location
  name                     = module.naming_aks_storage.storage_account.name_unique

  # Security Configuration
  https_traffic_only_enabled    = true
  resource_group_name           = azurerm_resource_group.that.name
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = true
  public_network_access_enabled = true

  # Identity Configuration
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  # Authentication Configuration
  azure_files_authentication = {
    default_share_level_permission = "StorageFileDataSmbShareReader"
    directory_type                 = "AADKERB"
  }

  # Tagging
  tags = {
    env   = "Dev"
    owner = "Mini Taur"
    dept  = "IT"
  }

  # Blob Configuration
  blob_properties = {
    versioning_enabled = true
  }

  # Role Assignments
  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name       = data.azurerm_role_definition.example.name
      principal_id                     = coalesce(azurerm_user_assigned_identity.storage_msi.principal_id, data.azurerm_client_config.current.object_id)
      skip_service_principal_aad_check = false
    },
    role_assignment_2 = {
      role_definition_id_or_name       = "Owner"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    },
  }

  # Network Rules
  network_rules = {
    bypass         = ["AzureServices"]
    default_action = "Deny"
    ip_rules       = [try(module.public_ip[0].public_ip, var.bypass_ip_cidr)]
    virtual_network_subnet_ids = toset(
      [
        module.vnet_secondary.subnet_ids_map["aks-subnet"],
        module.vnet_secondary.subnet_ids_map["gateway"]
    ])
  }

  # Container Configuration
  containers = {
    blob_container0 = {
      name = "blob-container-example-0"
    }
    blob_container1 = {
      name = "blob-container-example-1"
    }
  }

  # File Share Configuration
  shares = {
    share0 = {
      name  = "share-common-0"
      quota = 10
      signed_identifiers = [
        {
          id = "1"
          access_policy = {
            expiry_time = "2025-01-01T00:00:00Z"
            permission  = "r"
            start_time  = "2024-01-01T00:00:00Z"
          }
        }
      ]
    }
    share1 = {
      name        = "share-common-1"
      quota       = 10
      access_tier = "Hot"
      metadata = {
        key1 = "value1"
        key2 = "value2"
      }
    }
  }
}
