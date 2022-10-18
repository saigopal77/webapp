terraform {    
  required_providers {    
    azurerm = {    
      source = "hashicorp/azurerm"    
    }   
  }    
} 
   
provider "azurerm" {    
  features {}    
}

# Create Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = "gopal-terrafrom"
  location = "East US"
}

# Create Virtual Network and subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "Gopal-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_subnet" "vnet" {
  name                 = "tf-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]

  delegation {
    name = "vnet-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# SQL server 
resource "azurerm_mssql_server" "db" {
  name                         = "gopaldb"
  resource_group_name          = azurerm_resource_group.resource_group.name
  location                     = azurerm_resource_group.resource_group.location
  version                      = "12.0"
  administrator_login          = "gopal"
  administrator_login_password = "guntur123test-"
  public_network_access_enabled = true
}

#create database sql
resource "azurerm_mssql_database" "db" {
  name           = "gopal-db"
  server_id      = azurerm_mssql_server.db.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  read_scale     = false
  sku_name       = "Basic"
  storage_account_type = "Geo"
}

#enable encryption for sql db
resource "azurerm_mssql_server_transparent_data_encryption" "db" {
  server_id = azurerm_mssql_server.db.id
}

#attache vnet to sql server
resource "azurerm_mssql_virtual_network_rule" "db" {
  name      = "tf-db-vnet"
  server_id = azurerm_mssql_server.db.id
  subnet_id = azurerm_subnet.vnet.id
}

#Create app service plan
resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "gopalterraform1122"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "app_service" {
  name                = "gopalterraform"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id

}

#create auto sclae for app service plan
resource "azurerm_monitor_autoscale_setting" "autoscale-example" {
  name                = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  target_resource_id  = azurerm_app_service_plan.app_service_plan.id
  profile {
    name = "default"
    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.app_service_plan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 90
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.app_service_plan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }  
}