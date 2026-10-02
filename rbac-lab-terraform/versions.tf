# Lab 2 only needs the azurerm provider. No random or time providers are
# needed because no new infrastructure is being created.
terraform {
required_version = ">= 1.5.0"
required_providers {
azurerm = { source = "hashicorp/azurerm" 
version = "~> 3.0" }
}
}
provider "azurerm" { 
  features {}  
  }