# teardown 시 state를 로컬로 환원한 상태(원격 Storage를 곧 삭제하므로).
# 재구축 시 원격 backend 블록을 다시 활성화하고 terraform init -migrate-state 실행.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-alz-tfstate"
#     storage_account_name = "stalztfstatehbxh4l"
#     container_name       = "tfstate"
#     key                  = "bootstrap.terraform.tfstate"
#     use_azuread_auth     = true
#   }
# }
