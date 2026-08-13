resource "random_password" "lab4_sql" {
  count            = var.enable_lab4 ? 1 : 0
  length           = 24
  special          = true
  override_special = "!#%_-"
}

resource "azurerm_mssql_server" "lab4" {
  count                                = var.enable_lab4 ? 1 : 0
  name                                 = "sql-${local.lab4_prefix}-${random_string.suffix.result}"
  resource_group_name                  = data.azurerm_resource_group.sandbox.name
  location                             = data.azurerm_resource_group.sandbox.location
  version                              = "12.0"
  administrator_login                  = "sqladminsid"
  administrator_login_password         = random_password.lab4_sql[0].result
  minimum_tls_version                  = "1.2"
  public_network_access_enabled        = false
  outbound_network_restriction_enabled = false
  tags                                 = local.lab4_tags
}

resource "azurerm_mssql_database" "lab4" {
  count       = var.enable_lab4 ? 1 : 0
  name        = "sqldb-customer-messages"
  server_id   = azurerm_mssql_server.lab4[0].id
  sku_name    = "Basic"
  max_size_gb = 2
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  tags        = local.lab4_tags
}

resource "azurerm_private_dns_zone" "sql" {
  count               = var.enable_lab4 ? 1 : 0
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.sandbox.name
  tags                = local.lab4_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_online" {
  count                 = var.enable_lab4 ? 1 : 0
  name                  = "link-online-vnet"
  resource_group_name   = data.azurerm_resource_group.sandbox.name
  private_dns_zone_name = azurerm_private_dns_zone.sql[0].name
  virtual_network_id    = azurerm_virtual_network.online[0].id
  registration_enabled  = false
  tags                  = local.lab4_tags
}

resource "azurerm_private_endpoint" "sql" {
  count                         = var.enable_lab4 ? 1 : 0
  name                          = "pep-${local.lab4_prefix}-sql"
  location                      = data.azurerm_resource_group.sandbox.location
  resource_group_name           = data.azurerm_resource_group.sandbox.name
  subnet_id                     = azurerm_subnet.online_private_endpoints[0].id
  custom_network_interface_name = "nic-pep-${local.lab4_prefix}-sql"
  tags                          = local.lab4_tags

  private_service_connection {
    name                           = "psc-${local.lab4_prefix}-sql"
    private_connection_resource_id = azurerm_mssql_server.lab4[0].id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-private-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql[0].id]
  }
}

locals {
  lab4_sql_connection = var.enable_lab4 ? "DRIVER=/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so;SERVER=${azurerm_mssql_server.lab4[0].fully_qualified_domain_name};PORT=1433;DATABASE=${azurerm_mssql_database.lab4[0].name};UID=${azurerm_mssql_server.lab4[0].administrator_login};PWD=${random_password.lab4_sql[0].result};TDS_Version=7.4;Encrypt=yes;TrustServerCertificate=no" : ""
}
