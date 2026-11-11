resource "azurerm_resource_group" "rg" {
  name     = "rg-portfolio-standby"
  location = "francecentral"
}

# Storage account names must be 3-24 characters, numbers and lowercase only
resource "azurerm_storage_account" "standby" {
  name                     = "samuelojostandby2026"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }
}

output "azure_standby_domain" {
  description = "Web endpoint for the Azure static site"
  value       = azurerm_storage_account.standby.primary_web_host
}

output "azure_storage_account_name" {
  value = azurerm_storage_account.standby.name
}