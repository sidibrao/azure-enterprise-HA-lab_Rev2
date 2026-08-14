resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

data "azurerm_resource_group" "sandbox" {
  name = var.existing_resource_group_name
}

resource "azurerm_log_analytics_workspace" "central" {
  name                = "law-${var.prefix}-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub"
  address_space       = ["10.1.0.0/16"]
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = data.azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.1.0.0/26"]
}

resource "azurerm_subnet" "firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = data.azurerm_resource_group.sandbox.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.1.1.0/26"]
}

resource "azurerm_virtual_network" "erp" {
  name                = "vnet-${var.prefix}-erp-prod"
  address_space       = ["10.2.0.0/16"]
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "erp" {
  name                = "nsg-${var.prefix}-erp-app"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "erp_app" {
  name                            = "snet-erp-app"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  virtual_network_name            = azurerm_virtual_network.erp.name
  address_prefixes                = ["10.2.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "erp" {
  subnet_id                 = azurerm_subnet.erp_app.id
  network_security_group_id = azurerm_network_security_group.erp.id
}

resource "azurerm_virtual_network_peering" "hub_to_erp" {
  name                      = "peer-hub-to-erp"
  resource_group_name       = data.azurerm_resource_group.sandbox.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.erp.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "erp_to_hub" {
  name                      = "peer-erp-to-hub"
  resource_group_name       = data.azurerm_resource_group.sandbox.name
  virtual_network_name      = azurerm_virtual_network.erp.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.prefix}-firewall"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "erp-web-${random_string.suffix.result}"
  tags                = local.common_tags
}

resource "azurerm_public_ip" "firewall_management" {
  name                = "pip-${var.prefix}-firewall-management"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_firewall_policy" "this" {
  name                = "afwp-${var.prefix}"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  location            = data.azurerm_resource_group.sandbox.location
  sku                 = "Basic"
  tags                = local.common_tags
}

resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "rcg-allowed-egress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  application_rule_collection {
    name     = "allow-ubuntu-packages"
    priority = 100
    action   = "Allow"

    rule {
      name = "ubuntu-https"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses = ["10.2.0.0/16", "10.3.0.0/16"]
      destination_fqdns = [
        "ubuntu.com",
        "*.ubuntu.com",
        "packages.microsoft.com",
        "*.packages.microsoft.com",
      ]
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "afw-${var.prefix}-hub"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = local.common_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "management-configuration"
    subnet_id            = azurerm_subnet.firewall_management.id
    public_ip_address_id = azurerm_public_ip.firewall_management.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.egress]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "send-to-central-law"
  target_resource_id         = azurerm_firewall.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_route_table" "erp" {
  name                          = "rt-${var.prefix}-erp-egress"
  location                      = data.azurerm_resource_group.sandbox.location
  resource_group_name           = data.azurerm_resource_group.sandbox.name
  bgp_route_propagation_enabled = false
  tags                          = local.common_tags

  route {
    name                   = "default-via-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"
  }
}

resource "azurerm_subnet_route_table_association" "erp" {
  subnet_id      = azurerm_subnet.erp_app.id
  route_table_id = azurerm_route_table.erp.id
}

resource "tls_private_key" "vm" {
  count     = var.deploy_test_vm ? 1 : 0
  algorithm = "ED25519"
}

resource "azurerm_network_interface" "vm" {
  count               = var.deploy_test_vm ? 1 : 0
  name                = "nic-${var.prefix}-erp-test"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.erp_app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.10"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count                           = var.deploy_test_vm ? 1 : 0
  name                            = "vm-${var.prefix}-erp-test"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  location                        = data.azurerm_resource_group.sandbox.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm[0].id]
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {}

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.egress,
    azurerm_subnet_route_table_association.erp
  ]
}
