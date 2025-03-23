//terraform configuration bloc for landing zone lz001
//Configure the minimum required providers supported by this module
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.116.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.2.0" # Use the latest 2.x version
    }
    time = {
      source = "hashicorp/time"
      //version = "= 0.8.0"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.5.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = ">= 0.4.18"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"  # Use the latest version available
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  required_version = ">= 0.15.1"

  backend "azurerm" {}

}
