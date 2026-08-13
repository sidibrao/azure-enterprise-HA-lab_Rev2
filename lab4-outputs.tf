output "lab1_public_fqdn" {
  value       = azurerm_public_ip.firewall.fqdn
  description = "Public Azure DNS hostname for the existing Firewall-DNAT HA site."
}

output "lab1_public_dns_url" {
  value = "http://${azurerm_public_ip.firewall.fqdn}"
}

output "lab1_private_dns" {
  value = {
    firewall      = azurerm_private_dns_a_record.firewall.fqdn
    load_balancer = azurerm_private_dns_a_record.corp_web.fqdn
    web_nodes     = { for key, record in azurerm_private_dns_a_record.corp_web_nodes : key => record.fqdn }
  }
}

output "lab4_waf_public_ip" {
  value = var.enable_lab4 ? azurerm_public_ip.lab4_waf[0].ip_address : null
}

output "lab4_waf_public_fqdn" {
  value = var.enable_lab4 ? azurerm_public_ip.lab4_waf[0].fqdn : null
}

output "lab4_waf_url" {
  value = var.enable_lab4 ? "http://${azurerm_public_ip.lab4_waf[0].fqdn}" : null
}

output "lab4_private_dns" {
  value = var.enable_lab4 ? {
    frontend_pool     = azurerm_private_dns_a_record.online_frontend_pool[0].fqdn
    frontend_nodes    = { for key, record in azurerm_private_dns_a_record.online_frontends : key => record.fqdn }
    api_load_balancer = azurerm_private_dns_a_record.online_api_pool[0].fqdn
    api_nodes         = { for key, record in azurerm_private_dns_a_record.online_apis : key => record.fqdn }
    database          = azurerm_mssql_server.lab4[0].fully_qualified_domain_name
  } : null
}

output "lab4_sql_admin_login" {
  value = var.enable_lab4 ? azurerm_mssql_server.lab4[0].administrator_login : null
}

output "lab4_sql_admin_password" {
  value       = var.enable_lab4 ? random_password.lab4_sql[0].result : null
  sensitive   = true
  description = "Lab-only generated SQL password. Do not commit or expose it."
}

output "lab4_vm_private_key" {
  value       = var.enable_lab4 ? tls_private_key.lab4[0].private_key_openssh : null
  sensitive   = true
  description = "Lab-only SSH key for private Lab 4 VMs."
}
