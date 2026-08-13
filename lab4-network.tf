locals {
  lab4_prefix = "contoso-online"
  lab4_frontends = {
    zone1 = { zone = "1", private_ip = "10.3.1.11" }
    zone2 = { zone = "2", private_ip = "10.3.1.12" }
  }
  lab4_apis = {
    zone1 = { zone = "1", private_ip = "10.3.2.11" }
    zone2 = { zone = "2", private_ip = "10.3.2.12" }
  }
  lab4_tags = merge(local.common_tags, { workload = "online-portal", landing_zone = "online", lab = "4" })
}

resource "azurerm_virtual_network" "online" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "vnet-${local.lab4_prefix}"
  address_space       = ["10.3.0.0/16"]
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.lab4_tags
}

resource "azurerm_subnet" "appgw" {
  count                = var.enable_lab4 ? 1 : 0
  name                 = "snet-appgw"
  resource_group_name  = data.azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.online[0].name
  address_prefixes     = ["10.3.0.0/24"]
}

resource "azurerm_subnet" "online_frontend" {
  count                           = var.enable_lab4 ? 1 : 0
  name                            = "snet-frontend"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  virtual_network_name            = azurerm_virtual_network.online[0].name
  address_prefixes                = ["10.3.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "online_api" {
  count                           = var.enable_lab4 ? 1 : 0
  name                            = "snet-api"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  virtual_network_name            = azurerm_virtual_network.online[0].name
  address_prefixes                = ["10.3.2.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "online_private_endpoints" {
  count                = var.enable_lab4 ? 1 : 0
  name                 = "snet-private-endpoints"
  resource_group_name  = data.azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.online[0].name
  address_prefixes     = ["10.3.3.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_online" {
  count                     = var.enable_lab4 ? 1 : 0
  name                      = "peer-hub-to-online"
  resource_group_name       = data.azurerm_resource_group.sandbox.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.online[0].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "online_to_hub" {
  count                     = var.enable_lab4 ? 1 : 0
  name                      = "peer-online-to-hub"
  resource_group_name       = data.azurerm_resource_group.sandbox.name
  virtual_network_name      = azurerm_virtual_network.online[0].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_route_table" "online" {
  count                         = var.enable_lab4 ? 1 : 0
  name                          = "rt-${local.lab4_prefix}-egress"
  location                      = data.azurerm_resource_group.sandbox.location
  resource_group_name           = data.azurerm_resource_group.sandbox.name
  bgp_route_propagation_enabled = false
  tags                          = local.lab4_tags

  route {
    name                   = "default-via-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"
  }
}

resource "azurerm_subnet_route_table_association" "online_frontend" {
  count          = var.enable_lab4 ? 1 : 0
  subnet_id      = azurerm_subnet.online_frontend[0].id
  route_table_id = azurerm_route_table.online[0].id
}

resource "azurerm_subnet_route_table_association" "online_api" {
  count          = var.enable_lab4 ? 1 : 0
  subnet_id      = azurerm_subnet.online_api[0].id
  route_table_id = azurerm_route_table.online[0].id
}

resource "azurerm_network_security_group" "online_frontend" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "nsg-${local.lab4_prefix}-frontend"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.lab4_tags

  security_rule {
    name                       = "allow-http-from-appgw"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.3.0.0/24"
    destination_address_prefix = "10.3.1.0/24"
  }
}

resource "azurerm_network_security_group" "online_api" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "nsg-${local.lab4_prefix}-api"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.lab4_tags

  security_rule {
    name                       = "allow-api-from-frontend"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "10.3.1.0/24"
    destination_address_prefix = "10.3.2.0/24"
  }

  security_rule {
    name                       = "allow-api-lb-probe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "10.3.2.0/24"
  }
}

resource "azurerm_subnet_network_security_group_association" "online_frontend" {
  count                     = var.enable_lab4 ? 1 : 0
  subnet_id                 = azurerm_subnet.online_frontend[0].id
  network_security_group_id = azurerm_network_security_group.online_frontend[0].id
}

resource "azurerm_subnet_network_security_group_association" "online_api" {
  count                     = var.enable_lab4 ? 1 : 0
  subnet_id                 = azurerm_subnet.online_api[0].id
  network_security_group_id = azurerm_network_security_group.online_api[0].id
}
