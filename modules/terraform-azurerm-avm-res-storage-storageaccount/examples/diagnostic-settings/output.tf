output "eventhub_authorization_rule_primary_key" {
  description = "Primary key for the event hub authorisation rule"
  value       = azurerm_eventhub_authorization_rule.this.primary_key
  sensitive   = true
}
output "shares" {
  description = "value of shares"
  value       = module.this.shares
}
output "queue" {
  description = "value of queues"
  value       = module.this.queues
}
output "tables" {
  description = "value of tables"
  value       = module.this.tables
}
output "containers" {
  description = "value of containers"
  value       = module.this.containers
}

output "resource" {
  description = "value of storage_account"
  value       = module.this.resource
  sensitive   = true
}
