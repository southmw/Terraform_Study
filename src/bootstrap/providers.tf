terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  # 권한이 제한된 구독을 고려해 자동 RP 등록 비활성화 (필요한 RP는 수동 등록)
  resource_provider_registrations = "none"

  features {}
}
