# Dedicated subnet for the private web VM.
resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  virtual_network_name            = azurerm_virtual_network.erp.name
  address_prefixes                = ["10.2.2.0/24"]
  default_outbound_access_enabled = false
}

# Send all web-subnet outbound traffic through Azure Firewall.
resource "azurerm_subnet_route_table_association" "web" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.erp.id
}

# NSG dedicated to the web subnet.
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.prefix}-web"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-http-from-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "10.2.2.10"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# Separate SSH key for the web VM.
resource "tls_private_key" "web" {
  algorithm = "ED25519"
}

# Private NIC. No public IP is attached.
resource "azurerm_network_interface" "web" {
  name                = "nic-${var.prefix}-web"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.2.10"
  }
}

# Private Ubuntu VM running Nginx.
resource "azurerm_linux_virtual_machine" "web" {
  name                            = "vm-${var.prefix}-web"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  location                        = data.azurerm_resource_group.sandbox.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web.id]
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.web.public_key_openssh
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

  custom_data = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - nginx

    write_files:
      - path: /var/www/html/index.html
        permissions: "0644"
        content: |
          <!DOCTYPE html>
          <html>
          <head>
            <title>Contoso Web VM</title>
          </head>
          <body>
            <h1>Contoso Web VM</h1>
            <p>This private VM is published through Azure Firewall DNAT.</p>
            <p>Private address: 10.2.2.10</p>
          </body>
          </html>

    runcmd:
      - systemctl enable nginx
      - systemctl restart nginx
  CLOUD_INIT
  )

  boot_diagnostics {}

  depends_on = [
    azurerm_firewall.this,
    azurerm_firewall_policy_rule_collection_group.egress,
    azurerm_subnet_route_table_association.web,
    azurerm_subnet_network_security_group_association.web
  ]
}

# Publish firewall public TCP/80 to the private web VM.
resource "azurerm_firewall_policy_rule_collection_group" "web_ingress" {
  name               = "rcg-web-ingress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  nat_rule_collection {
    name     = "dnat-web-http"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "publish-private-web-vm"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.firewall.ip_address
      destination_ports   = ["80"]
      translated_address  = azurerm_network_interface.web.private_ip_address
      translated_port     = 80
    }
  }
}
