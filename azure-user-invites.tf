//Manage user invites to the Azure Cloud Tenant here.
//Including RBAC with basic roles like "Contributor" and "Owner"
//
data "local_file" "users_dat" {
  filename = "${path.module}/users.dat"
}

# Local variable to read and parse users.dat file
locals {
  # Read the users.dat file and split into lines
  user_lines = compact(split("\n", data.local_file.users_dat.content))
  
  # Validate format and parse each line into user objects
  users = [
    for line in local.user_lines : {
      email = trimspace(split(",", line)[0])
      role  = length(split(",", line)) == 2 ? trimspace(split(",", line)[1]) : "Contributor"  # Default to Contributor if no role specified
    }
  ]

  # Validation of roles
  valid_roles = alltrue([
    for user in local.users :
    contains(["Contributor", "Owner"], user.role)
  ])

  # Validate the roles and fail if invalid
  validate_roles = regex("^$", local.valid_roles ? "" : tobool("Invalid role specified. Must be either 'Contributor' or 'Owner'"))
}

# Create guest user invitations
resource "azuread_invitation" "user_invites" {
  for_each = { for user in local.users : user.email => user }

  user_email_address = each.key
  redirect_url       = "https://portal.azure.com"
  message {
    additional_recipients = []
    body                 = "You have been invited to access our Azure environment."
  }

  lifecycle {
    ignore_changes = [
      redirect_url,
      message
    ]
  }
}

# Wait for invitation acceptance and get user objects
data "azuread_user" "invited_users" {
  for_each = { for user in local.users : user.email => user }

  mail = each.key

  depends_on = [
    azuread_invitation.user_invites
  ]
}

# Assign roles to users
resource "azurerm_role_assignment" "user_roles" {
  for_each = { for user in local.users : user.email => user }

  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = each.value.role
  principal_id         = data.azuread_user.invited_users[each.key].object_id

  depends_on = [
    data.azuread_user.invited_users
  ]
}

# Debug outputs
output "file_content" {
  description = "Raw content of users.dat"
  value       = data.local_file.users_dat.content
  sensitive   = false
}

output "user_lines" {
  description = "Lines after splitting"
  value       = local.user_lines
  sensitive   = false
}

output "parsed_users" {
  description = "Parsed user data"
  value       = local.users
  sensitive   = false
}

# Main output
output "invited_users" {
  description = "Details of invited users and their role assignments"
  value = {
    for email, user in local.users : email => {
      email = email
      role  = user.role
      invitation_status = contains(keys(azuread_invitation.user_invites), email) ? "Invited" : "Existing"
      object_id = try(data.azuread_user.invited_users[email].object_id, null)
    }
  }
  sensitive = false
} 
