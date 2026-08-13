locals {
  web_nodes = {
    zone1 = {
      zone       = "1"
      private_ip = "10.2.2.11"
      label      = "Web Node - Availability Zone 1"
    }
    zone2 = {
      zone       = "2"
      private_ip = "10.2.2.12"
      label      = "Web Node - Availability Zone 2"
    }
  }
}

resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  virtual_network_name            = azurerm_virtual_network.erp.name
  address_prefixes                = ["10.2.2.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_route_table_association" "web" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.erp.id
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.prefix}-web"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-http-from-azure-load-balancer"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "tls_private_key" "web" {
  algorithm = "ED25519"
}

resource "azurerm_lb" "web" {
  name                = "lbi-${var.prefix}-web"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  sku                 = "Standard"
  tags                = local.common_tags

  frontend_ip_configuration {
    name                          = "fe-web-private"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address            = "10.2.2.20"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "bepool-web"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "web" {
  name                = "probe-http-health"
  loadbalancer_id     = azurerm_lb.web.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "web" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fe-web-private"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.web.id
  disable_outbound_snat          = true
}

resource "azurerm_network_interface" "web" {
  for_each            = local.web_nodes
  name                = "nic-${var.prefix}-web-${each.key}"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = merge(local.common_tags, { availability_zone = each.value.zone })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  for_each                = local.web_nodes
  network_interface_id    = azurerm_network_interface.web[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

resource "azurerm_linux_virtual_machine" "web" {
  for_each                        = local.web_nodes
  name                            = "vm-${var.prefix}-web-${each.key}"
  computer_name                   = "web-${each.key}"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  location                        = data.azurerm_resource_group.sandbox.location
  zone                            = each.value.zone
  size                            = var.web_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web[each.key].id]
  tags                            = merge(local.common_tags, { availability_zone = each.value.zone })

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
          <head><title>Contoso HA Web Tier</title></head>
          <body style="font-family: sans-serif; max-width: 760px; margin: 4rem auto;">
            <h1>Contoso HA Web Tier</h1>
            <h2>${each.value.label}</h2>
            <p>Private IP: ${each.value.private_ip}</p>
            <p>Traffic path: Azure Firewall DNAT → Internal Load Balancer → zonal VM.</p>
          </body>
          </html>
      - path: /var/www/html/health
        permissions: "0644"
        content: "healthy - ${each.key}\n"

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
    azurerm_subnet_network_security_group_association.web,
    azurerm_network_interface_backend_address_pool_association.web
  ]
}

resource "azurerm_firewall_policy_rule_collection_group" "web_ingress" {
  name               = "rcg-web-ingress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  nat_rule_collection {
    name     = "dnat-web-http"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "publish-ha-web-tier"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.firewall.ip_address
      destination_ports   = ["80"]
      translated_address  = azurerm_lb.web.private_ip_address
      translated_port     = 80
    }
  }
}
