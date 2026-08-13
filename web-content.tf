locals {
  web_page = {
    for key, node in local.web_nodes : key => templatefile("${path.module}/templates/index.html.tftpl", {
      node_key           = key
      zone               = node.zone
      region             = data.azurerm_resource_group.sandbox.location
      vm_name            = azurerm_linux_virtual_machine.web[key].name
      hostname           = azurerm_linux_virtual_machine.web[key].computer_name
      private_ip         = node.private_ip
      nic_name           = azurerm_network_interface.web[key].name
      load_balancer_ip   = azurerm_lb.web.private_ip_address
      firewall_public_ip = azurerm_public_ip.firewall.ip_address
      environment        = lookup(local.common_tags, "environment", "lab")
    })
  }
}

resource "azurerm_virtual_machine_extension" "web_content" {
  for_each                   = local.web_nodes
  name                       = "configure-dark-web-dashboard"
  virtual_machine_id         = azurerm_linux_virtual_machine.web[each.key].id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = "echo '${base64encode(local.web_page[each.key])}' | base64 -d > /var/www/html/index.html && printf 'healthy - ${each.key}\\n' > /var/www/html/health && systemctl enable nginx && systemctl restart nginx"
  })

  tags = merge(local.common_tags, { availability_zone = each.value.zone })
}
