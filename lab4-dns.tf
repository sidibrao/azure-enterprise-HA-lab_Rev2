resource "azurerm_private_dns_zone" "online" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "online.contoso.internal"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.lab4_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "online" {
  count                 = var.enable_lab4 ? 1 : 0
  name                  = "link-online-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.online[0].name
  virtual_network_id    = azurerm_virtual_network.online[0].id
  registration_enabled  = false
  tags                  = local.lab4_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_to_online" {
  count                 = var.enable_lab4 ? 1 : 0
  name                  = "link-online-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.hub.name
  virtual_network_id    = azurerm_virtual_network.online[0].id
  registration_enabled  = false
  tags                  = local.lab4_tags
}

resource "azurerm_private_dns_a_record" "online_frontends" {
  for_each            = var.enable_lab4 ? local.lab4_frontends : {}
  name                = "fe-${each.key}"
  zone_name           = azurerm_private_dns_zone.online[0].name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 30
  records             = [each.value.private_ip]
  tags                = local.lab4_tags
}

resource "azurerm_private_dns_a_record" "online_frontend_pool" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "frontend"
  zone_name           = azurerm_private_dns_zone.online[0].name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 30
  records             = values(local.lab4_frontends)[*].private_ip
  tags                = local.lab4_tags
}

resource "azurerm_private_dns_a_record" "online_apis" {
  for_each            = var.enable_lab4 ? local.lab4_apis : {}
  name                = "api-${each.key}"
  zone_name           = azurerm_private_dns_zone.online[0].name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 30
  records             = [each.value.private_ip]
  tags                = local.lab4_tags
}

resource "azurerm_private_dns_a_record" "online_api_pool" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "api"
  zone_name           = azurerm_private_dns_zone.online[0].name
  resource_group_name = data.azurerm_resource_group.sandbox.name
  ttl                 = 30
  records             = [azurerm_lb.online_api[0].private_ip_address]
  tags                = local.lab4_tags
}
