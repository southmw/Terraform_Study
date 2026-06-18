# 부트스트랩 state 원격 백엔드 (Phase 1에서 생성한 Storage로 이전)
# 최초 로컬 apply 이후 `terraform init -migrate-state` 로 이전함.
# 인증: use_azuread_auth=true (Entra) — 운영자는 Storage Blob Data Contributor 필요.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-alz-tfstate"
    storage_account_name = "stalztfstatehbxh4l"
    container_name       = "tfstate"
    key                  = "bootstrap.terraform.tfstate"
    use_azuread_auth     = true
  }
}
