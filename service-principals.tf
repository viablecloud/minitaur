## Data source to read the service principals CSV file
data "local_file" "sp_data" {
  filename = "${path.module}/service-principals.dat"
}

## Data source for existing Key Vault
# WARNING: THIS KEYVAULT MUST HAVE ALREADY BEEN CREATED BEFORE YOU ENABLE THIS DATA SOURCE!!
# data "azurerm_key_vault" "existing_kv" {
#  name                = "kv-${var.organisation_id}-${var.deployment_environment}-${var.location_short}-001"
#  resource_group_name = "rg-kv-${var.location_short}-${var.deployment_environment}"
#}

## Debug outputs: ONLY USE WHEN NEEDED
/*
output "debug_info" {
  value = {
    current_client_id     = data.azurerm_client_config.current.client_id
    current_object_id     = data.azurerm_client_config.current.object_id
    current_tenant_id     = data.azurerm_client_config.current.tenant_id
    subscription_id       = data.azurerm_subscription.current.subscription_id
    key_vault_id         = data.azurerm_key_vault.existing_kv.id
  }
  sensitive = false
}
*/

## Add Key Vault Secrets Officer role at Key Vault level
# WARNING: YOU MUST HAVE THE KEYVAULT DEPLOYED FIRST BEFORE CREATING THIS ROLE - OBVIOUSLY ;-)
/*
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = data.azurerm_key_vault.existing_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  # Add a description to help identify the purpose
  description = "Allows Terraform to manage secrets in the Key Vault"
}

## Use local-exec to create secrets without checking existence
resource "null_resource" "create_secrets" {
  for_each = { for sp in local.service_principals : sp.name => sp }

  triggers = {
    client_id     = azuread_application.sp_apps[each.key].client_id
    client_secret = azuread_service_principal_password.sp_passwords[each.key].value
    secret_name   = "sp-${each.key}-credentials"
  }

  provisioner "local-exec" {
    command = <<EOT
      az keyvault secret set \
        --vault-name "${data.azurerm_key_vault.existing_kv.name}" \
        --name "${self.triggers.secret_name}" \
        --value '${jsonencode({
          client_id     = self.triggers.client_id
          client_secret = self.triggers.client_secret
          tenant_id     = data.azurerm_client_config.current.tenant_id
        })}' \
        --content-type "application/json" \
        --tags "ServicePrincipal=${each.key}" "Role=${each.value.role}" "Subscription=${each.value.subscription}"
    EOT
  }

  depends_on = [
    azurerm_role_assignment.terraform_kv_secrets_officer
  ]
}
*/

# Local variables for parsing and validation
/*
locals {
  # Parse the CSV file into lines
  sp_lines = compact(split("\n", data.local_file.sp_data.content))
  
  # Convert lines into structured data
  service_principals = [
    for line in local.sp_lines : {
      name           = trimspace(split(",", line)[0])
      role          = trimspace(split(",", line)[1])
      subscription  = trimspace(split(",", line)[2])
    }
  ]

  # Validate roles for service principals
  sp_valid_roles = alltrue([
    for sp in local.service_principals :
    contains(["Contributor", "Reader"], sp.role)
  ])

  # Validate the service principal roles and fail if invalid
  sp_validate_roles = regex("^$", local.sp_valid_roles ? "" : tobool("Invalid role specified. Must be either 'Contributor' or 'Reader'"))

  # Create a map of secret names to validate against
  secret_names = { for sp in local.service_principals : 
    "sp-${sp.name}-credentials" => sp.name 
  }
}
*/

# Local variables for parsing and validation
# Local variables for parsing and validation
locals {
  # Parse the CSV file into lines
  sp_lines = compact(split("\n", data.local_file.sp_data.content))
    
  # Convert lines into structured data
  service_principals = [
    for line in local.sp_lines : {
      name          = trimspace(split(",", line)[0])
      role          = trimspace(split(",", line)[1])
      subscription  = trimspace(split(",", line)[2])
    }
  ]
  
  # Validate roles for service principals
  sp_valid_roles = alltrue([
    for sp in local.service_principals :
    contains(["Contributor", "Reader"], sp.role)
  ])

  # Trigger validation failure
  sp_validation_message = local.sp_valid_roles ? "All roles are valid." : "Invalid role specified. Must be either 'Contributor' or 'Reader'."

  # Create a map of secret names to validate against
  secret_names = { for sp in local.service_principals :
    "sp-${sp.name}-credentials" => sp.name
  } 
}

# Use a data block to halt execution if roles are invalid
data "null_data_source" "validation" {
  count = local.sp_valid_roles ? 0 : 1
  inputs = {
    message = local.sp_validation_message
  }
}

## Create Azure AD Applications for each service principal
resource "azuread_application" "sp_apps" {
  for_each = { for sp in local.service_principals : sp.name => sp }

  display_name = each.key
}

## Create Service Principals
resource "azuread_service_principal" "service_principals" {
  for_each = { for sp in local.service_principals : sp.name => sp }

  client_id = azuread_application.sp_apps[each.key].client_id
  
  # Optional: Add any additional configurations like tags
  tags = ["Terraform Managed"]
}

## Generate random passwords for service principals
#resource "random_password" "sp_passwords" {
#  for_each = { for sp in local.service_principals : sp.name => sp }
#
#  length  = 32
#  special = true
#}

## Create service principal passwords
resource "azuread_service_principal_password" "sp_passwords" {
  for_each = { for sp in local.service_principals : sp.name => sp }

  service_principal_id = azuread_service_principal.service_principals[each.key].id
  end_date            = timeadd(timestamp(), "8760h") # 1 year from now
}

## Assign roles to service principals
#resource "azurerm_role_assignment" "sp_role_assignments" {
#  for_each = { for sp in local.service_principals : sp.name => sp }
#
#  scope                = "/subscriptions/${each.value.subscription}"
#  role_definition_name = each.value.role
#  principal_id         = azuread_service_principal.service_principals[each.key].object_id
#}
#
## Output the created service principals and their details
#output "service_principals" {
#  description = "Created service principals and their configurations"
#  value = {
#    for sp in local.service_principals : sp.name => {
#      name          = sp.name
#      role          = sp.role
#      subscription  = sp.subscription
#      client_id     = azuread_application.sp_apps[sp.name].client_id
#      key_vault_secret = "sp-${sp.name}-credentials"
#    }
#  }
#  //set to "true" if you don't want this data to be displayed in the console or ci/cd pipeline output
#  sensitive = false
#}
#
## Output created service principals for verification
#output "created_service_principals" {
#  value = {
#    for name, sp in azuread_service_principal.service_principals : name => {
#      client_id = azuread_application.sp_apps[name].client_id
#      object_id = sp.object_id
#      display_name = sp.display_name
#    }
#  }
#  sensitive = false
#} 
