resource "azurerm_private_dns_zone" "hub" {
  name                = "hub.contoso.internal"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "corp" {
  name                = "corp.contoso.internal"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_to_hub" {
  name                  = "link-hub-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.hub.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_to_corp" {
  name                  = "link-corp-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.hub.name
  virtual_network_id    = azurerm_virtual_network.erp.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "corp" {
  name                  = "link-corp-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.corp.name
  virtual_network_id    = azurerm_virtual_network.erp.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_a_record" "firewall" {
  name                = "firewall"
  zone_name           = azurerm_private_dns_zone.hub.name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 60
  records             = [azurerm_firewall.this.ip_configuration[0].private_ip_address]
  tags                = local.common_tags
}

resource "azurerm_private_dns_a_record" "corp_web" {
  name                = "web"
  zone_name           = azurerm_private_dns_zone.corp.name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 60
  records             = [azurerm_lb.web.private_ip_address]
  tags                = local.common_tags
}

resource "azurerm_private_dns_a_record" "corp_web_nodes" {
  for_each            = local.web_nodes
  name                = "web-${each.key}"
  zone_name           = azurerm_private_dns_zone.corp.name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 60
  records             = [each.value.private_ip]
  tags                = local.common_tags
}
