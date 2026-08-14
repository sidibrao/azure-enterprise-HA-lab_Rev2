resource "tls_private_key" "lab4" {
  count     = var.enable_lab4 ? 1 : 0
  algorithm = "ED25519"
}

resource "azurerm_lb" "online_api" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "lbi-${local.lab4_prefix}-api"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  sku                 = "Standard"
  tags                = local.lab4_tags

  frontend_ip_configuration {
    name                          = "fe-api-private"
    subnet_id                     = azurerm_subnet.online_api[0].id
    private_ip_address            = "10.3.2.20"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "online_api" {
  count           = var.enable_lab4 ? 1 : 0
  name            = "bepool-api"
  loadbalancer_id = azurerm_lb.online_api[0].id
}

resource "azurerm_lb_probe" "online_api" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "probe-api-health"
  loadbalancer_id     = azurerm_lb.online_api[0].id
  protocol            = "Http"
  port                = 8000
  request_path        = "/health"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "online_api" {
  count                          = var.enable_lab4 ? 1 : 0
  name                           = "rule-api"
  loadbalancer_id                = azurerm_lb.online_api[0].id
  protocol                       = "Tcp"
  frontend_port                  = 8000
  backend_port                   = 8000
  frontend_ip_configuration_name = "fe-api-private"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.online_api[0].id]
  probe_id                       = azurerm_lb_probe.online_api[0].id
  disable_outbound_snat          = true
}

resource "azurerm_network_interface" "online_frontend" {
  for_each            = var.enable_lab4 ? local.lab4_frontends : {}
  name                = "nic-${local.lab4_prefix}-fe-${each.key}"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "frontend" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.online_frontend[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
  }
}

resource "azurerm_network_interface" "online_api" {
  for_each            = var.enable_lab4 ? local.lab4_apis : {}
  name                = "nic-${local.lab4_prefix}-api-${each.key}"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "api" })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.online_api[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "online_api" {
  for_each                = var.enable_lab4 ? local.lab4_apis : {}
  network_interface_id    = azurerm_network_interface.online_api[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.online_api[0].id
}

resource "azurerm_linux_virtual_machine" "online_api" {
  for_each                        = var.enable_lab4 ? local.lab4_apis : {}
  name                            = "vm-${local.lab4_prefix}-api-${each.key}"
  computer_name                   = "api-${each.key}"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  location                        = data.azurerm_resource_group.sandbox.location
  zone                            = each.value.zone
  size                            = var.lab4_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.online_api[each.key].id]
  tags                            = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "api" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.lab4[0].public_key_openssh
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
    azurerm_firewall.this,
    azurerm_firewall_policy_rule_collection_group.egress,
    azurerm_network_interface_backend_address_pool_association.online_api,
    azurerm_private_dns_zone_virtual_network_link.sql_online,
    azurerm_private_endpoint.sql,
    azurerm_subnet_route_table_association.online_api,
    azurerm_virtual_network_peering.hub_to_online,
    azurerm_virtual_network_peering.online_to_hub,
  ]
}

resource "azurerm_virtual_machine_extension" "online_api_config" {
  for_each                   = var.enable_lab4 ? local.lab4_apis : {}
  name                       = "configure-contoso-api"
  virtual_machine_id         = azurerm_linux_virtual_machine.online_api[each.key].id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  protected_settings = jsonencode({
    commandToExecute = "echo '${base64encode(templatefile("${path.module}/templates/configure-lab4-api.sh.tftpl", {
      zone               = each.value.zone
      api_source_b64     = base64encode(templatefile("${path.module}/templates/lab4-api.py.tftpl", { zone = each.value.zone, private_ip = each.value.private_ip }))
      sql_connection_b64 = base64encode("SQL_CONNECTION=${local.lab4_sql_connection}\n")
      sql_fqdn           = azurerm_mssql_server.lab4[0].fully_qualified_domain_name
    }))}' | base64 -d > /tmp/configure-contoso-api.sh && chmod 0700 /tmp/configure-contoso-api.sh && /tmp/configure-contoso-api.sh"
  })
  tags = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "api" })

  depends_on = [
    azurerm_firewall.this,
    azurerm_private_dns_zone_virtual_network_link.sql_online,
    azurerm_private_endpoint.sql,
    azurerm_virtual_network_peering.hub_to_online,
    azurerm_virtual_network_peering.online_to_hub,
  ]
}

resource "azurerm_linux_virtual_machine" "online_frontend" {
  for_each                        = var.enable_lab4 ? local.lab4_frontends : {}
  name                            = "vm-${local.lab4_prefix}-fe-${each.key}"
  computer_name                   = "fe-${each.key}"
  resource_group_name             = data.azurerm_resource_group.sandbox.name
  location                        = data.azurerm_resource_group.sandbox.location
  zone                            = each.value.zone
  size                            = var.lab4_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.online_frontend[each.key].id]
  tags                            = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "frontend" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.lab4[0].public_key_openssh
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
    azurerm_firewall.this,
    azurerm_firewall_policy_rule_collection_group.egress,
    azurerm_private_dns_a_record.online_api_pool,
    azurerm_subnet_route_table_association.online_frontend,
    azurerm_virtual_network_peering.hub_to_online,
    azurerm_virtual_network_peering.online_to_hub,
  ]
}

resource "azurerm_virtual_machine_extension" "online_frontend_config" {
  for_each                   = var.enable_lab4 ? local.lab4_frontends : {}
  name                       = "configure-contoso-frontend"
  virtual_machine_id         = azurerm_linux_virtual_machine.online_frontend[each.key].id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true
  protected_settings = jsonencode({
    commandToExecute = "echo '${base64encode(templatefile("${path.module}/templates/configure-lab4-frontend.sh.tftpl", {
      zone     = each.value.zone
      zone_key = each.key
      frontend_html_b64 = base64encode(templatefile("${path.module}/templates/lab4-frontend.html.tftpl", {
        zone       = each.value.zone
        private_ip = each.value.private_ip
        vm_name    = "vm-${local.lab4_prefix}-fe-${each.key}"
        region     = data.azurerm_resource_group.sandbox.location
      }))
    }))}' | base64 -d > /tmp/configure-contoso-frontend.sh && chmod 0700 /tmp/configure-contoso-frontend.sh && /tmp/configure-contoso-frontend.sh"
  })
  tags = merge(local.lab4_tags, { availability_zone = each.value.zone, tier = "frontend" })

  depends_on = [
    azurerm_firewall.this,
    azurerm_private_dns_a_record.online_api_pool,
    azurerm_virtual_network_peering.hub_to_online,
    azurerm_virtual_network_peering.online_to_hub,
  ]
}
