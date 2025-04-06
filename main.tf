terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.25.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "e505d846-51fe-453e-8cfc-7db51f2e5ca6"
}

resource "random_integer" "randomint" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "TaskBoardRG" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_mssql_server" "TaskBoardDS" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.TaskBoardRG.name
  location                     = azurerm_resource_group.TaskBoardRG.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "TaskBoardDB" {
  name                 = var.sql_database_name
  server_id            = azurerm_mssql_server.TaskBoardDS.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  license_type         = "LicenseIncluded"
  sku_name             = "S0"
  zone_redundant       = false
  storage_account_type = "Zone"
  geo_backup_enabled   = false
}

resource "azurerm_mssql_firewall_rule" "TaskBoardFR" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.TaskBoardDS.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_service_plan" "TaskBoardSP" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.TaskBoardRG.name
  location            = azurerm_resource_group.TaskBoardRG.location
  sku_name            = "F1"
  os_type             = "Linux"
}

resource "azurerm_linux_web_app" "TaskBoardWA" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.TaskBoardRG.name
  location            = azurerm_service_plan.TaskBoardSP.location
  service_plan_id     = azurerm_service_plan.TaskBoardSP.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.TaskBoardDS.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.TaskBoardDB.name};User ID=${azurerm_mssql_server.TaskBoardDS.administrator_login};Password=${azurerm_mssql_server.TaskBoardDS.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id                 = azurerm_linux_web_app.TaskBoardWA.id
  repo_url               = var.repo_url
  branch                 = "main"
  use_manual_integration = true
}