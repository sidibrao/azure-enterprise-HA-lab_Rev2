mock_provider "azurerm" {}

run "corp_landing_zone_contract" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000001"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
  }

  assert {
    condition     = azurerm_virtual_network.hub.address_space == toset(["10.1.0.0/16"])
    error_message = "The hub CIDR must remain 10.1.0.0/16."
  }

  assert {
    condition     = azurerm_virtual_network.erp.address_space == toset(["10.2.0.0/16"])
    error_message = "The ERP spoke CIDR must remain 10.2.0.0/16."
  }

  assert {
    condition     = one(azurerm_route_table.erp.route).next_hop_in_ip_address == "10.1.0.4"
    error_message = "The ERP default route must use the hub firewall at 10.1.0.4."
  }

  assert {
    condition     = one(azurerm_route_table.erp.route).address_prefix == "0.0.0.0/0"
    error_message = "The ERP route table must retain its default route."
  }

  assert {
    condition     = azurerm_firewall.this.sku_tier == "Basic"
    error_message = "The learning lab must use the cost-conscious Basic firewall tier."
  }

  assert {
    condition     = azurerm_subnet.firewall_management.name == "AzureFirewallManagementSubnet"
    error_message = "Basic Azure Firewall requires its dedicated management subnet."
  }

  assert {
    condition     = azurerm_network_interface.vm[0].ip_configuration[0].private_ip_address == "10.2.1.10"
    error_message = "The test VM must retain the documented private address."
  }

  assert {
    condition     = azurerm_network_interface.web.ip_configuration[0].private_ip_address == "10.2.2.10"
    error_message = "The web VM must retain its documented private address."
  }

  assert {
    condition     = contains(flatten([for collection in azurerm_firewall_policy_rule_collection_group.egress.application_rule_collection : [for rule in collection.rule : [for protocol in rule.protocols : "${protocol.type}:${protocol.port}"]]]), "Http:80")
    error_message = "Ubuntu package installation requires HTTP/80 egress through Azure Firewall."
  }

}
