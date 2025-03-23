//Manage internal, private DNS here

#Create Private DNS Zone
resource "azurerm_private_dns_zone" "mini_int" {
  name                = "mini.int"
  resource_group_name = azurerm_resource_group.standalone_services_rsg.name

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
}

# Link Private DNS Zone to Hub VNET
resource "azurerm_private_dns_zone_virtual_network_link" "hub_mini_int" {
  name                  = "hub-vnet-link"
  resource_group_name   = azurerm_resource_group.standalone_services_rsg.name
  private_dns_zone_name = azurerm_private_dns_zone.mini_int.name
  virtual_network_id    = module.spoke_virtual_network.virtual_network_id
  registration_enabled  = false

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
}

# Link Private DNS Zone to Secondary (Spoke) VNET
resource "azurerm_private_dns_zone_virtual_network_link" "secondary_mini_int" {
  name                  = "secondary-vnet-link"
  resource_group_name   = azurerm_resource_group.standalone_services_rsg.name
  private_dns_zone_name = azurerm_private_dns_zone.mini_int.name
  virtual_network_id    = module.vnet_secondary.virtual_network_id
  registration_enabled  = false

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
}

# Create DNS A Record for manage.mini.int
resource "azurerm_private_dns_a_record" "manage" {
  name                = "manage"
  zone_name           = azurerm_private_dns_zone.mini_int.name
  resource_group_name = azurerm_resource_group.standalone_services_rsg.name
  ttl                = 300
  records            = ["10.216.48.14"]

  tags = {
    Environment      = local.deploy_environment["environment"]
    ApplicationOwner = local.deploy_environment["owner"]
    Application      = local.deploy_environment["application"]
    CostCenter       = local.deploy_environment["costcenter"]
    Department       = local.deploy_environment["department"]
  }
} 