output "firewall_private_ip" {
  description = "Next hop used by the ERP spoke UDR."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "test_vm_private_ip" {
  value = var.deploy_test_vm ? azurerm_network_interface.vm[0].private_ip_address : null
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.central.id
}

output "policy_assignment_scope" {
  value = local.policy_scope
}

output "test_vm_private_key" {
  description = "Lab-only SSH key. Save securely and never commit it. Prefer Azure Run Command for this private VM."
  value       = var.deploy_test_vm ? tls_private_key.vm[0].private_key_openssh : null
  sensitive   = true
}

output "web_vm_private_ip" {
  description = "Private IP addresses of both zonal web VMs."
  value       = { for key, nic in azurerm_network_interface.web : key => nic.private_ip_address }
}

output "web_public_ip" {
  description = "Azure Firewall public IP used for HTTP DNAT."
  value       = azurerm_public_ip.firewall.ip_address
}

output "web_url" {
  description = "Public HTTP URL forwarded through Azure Firewall."
  value       = "http://${azurerm_public_ip.firewall.ip_address}"
}

output "web_vm_zones" {
  description = "Availability Zone assigned to each private web VM."
  value       = { for key, vm in azurerm_linux_virtual_machine.web : key => vm.zone }
}

output "internal_load_balancer_ip" {
  description = "Private frontend address used as the Azure Firewall DNAT target."
  value       = azurerm_lb.web.private_ip_address
}

output "load_balancer_backend_pool_id" {
  value = azurerm_lb_backend_address_pool.web.id
}

output "load_balancer_probe_id" {
  value = azurerm_lb_probe.web.id
}

output "ha_test_url" {
  description = "Public HTTP URL that enters through Azure Firewall and is balanced across zones."
  value       = "http://${azurerm_public_ip.firewall.ip_address}"
}

output "web_vm_private_key" {
  description = "Lab-only SSH private key for the private web VM."
  value       = tls_private_key.web.private_key_openssh
  sensitive   = true
}
