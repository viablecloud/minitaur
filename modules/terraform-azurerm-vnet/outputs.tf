output "subnet_address_prefixes_map" {
  description = "Map of subnet names to address prefixes"
  value       = { for subnet in azurerm_subnet.snet : subnet.name => subnet.address_prefixes }
} 
