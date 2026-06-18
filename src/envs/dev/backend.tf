# envs/dev 원격 state (Phase 1에서 생성한 Storage 재사용)
# 인증: use_azuread_auth=true (Entra). 로컬은 az CLI, CI는 ARM_USE_OIDC=true.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-alz-tfstate"
    storage_account_name = "stalztfstatehbxh4l"
    container_name       = "tfstate"
    key                  = "envs/dev.terraform.tfstate"
    use_azuread_auth     = true
  }
}
