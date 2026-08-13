resource "azurerm_public_ip" "lab4_waf" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "pip-${local.lab4_prefix}-waf"
  location            = data.azurerm_resource_group.sandbox.location
  resource_group_name = data.azurerm_resource_group.sandbox.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  domain_name_label   = "contoso-portal-${random_string.suffix.result}"
  tags                = local.lab4_tags
}

resource "azurerm_web_application_firewall_policy" "lab4" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "wafp-${local.lab4_prefix}"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  location            = data.azurerm_resource_group.sandbox.location
  tags                = local.lab4_tags

  policy_settings {
    enabled                     = true
    mode                        = var.lab4_waf_mode
    request_body_check          = true
    file_upload_limit_in_mb     = 10
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  custom_rules {
    name      = "BlockLabTestHeader"
    priority  = 10
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "X-Lab-Block"
      }
      operator           = "Equal"
      match_values       = ["true"]
      transforms         = ["Lowercase"]
      negation_condition = false
    }
  }
}

resource "azurerm_application_gateway" "lab4" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "agw-${local.lab4_prefix}"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  location            = data.azurerm_resource_group.sandbox.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.lab4[0].id
  zones               = ["1", "2"]
  http2_enabled       = true
  tags                = local.lab4_tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip"
    subnet_id = azurerm_subnet.appgw[0].id
  }

  frontend_ip_configuration {
    name                 = "frontend-public"
    public_ip_address_id = azurerm_public_ip.lab4_waf[0].id
  }

  frontend_port {
    name = "port-http"
    port = 80
  }

  backend_address_pool {
    name         = "pool-zonal-frontends"
    ip_addresses = values(local.lab4_frontends)[*].private_ip
  }

  probe {
    name                = "probe-frontend-health"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 10
    timeout             = 5
    unhealthy_threshold = 3
    match { status_code = ["200-399"] }
  }

  backend_http_settings {
    name                  = "setting-frontend-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "probe-frontend-health"
  }

  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "frontend-public"
    frontend_port_name             = "port-http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-portal-http"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "pool-zonal-frontends"
    backend_http_settings_name = "setting-frontend-http"
  }

  depends_on = [
    azurerm_linux_virtual_machine.online_frontend,
    azurerm_subnet_network_security_group_association.online_frontend
  ]
}

resource "azurerm_monitor_diagnostic_setting" "lab4_waf" {
  count                      = var.enable_lab4 ? 1 : 0
  name                       = "send-waf-to-central-law"
  target_resource_id         = azurerm_application_gateway.lab4[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id

  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }
}
