output "tfstate_resource_group_name" {
  description = "State Storage가 위치한 리소스 그룹"
  value       = azurerm_resource_group.tfstate.name
}

output "tfstate_storage_account_name" {
  description = "State Storage 계정 이름"
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  description = "State 컨테이너 이름"
  value       = azurerm_storage_container.tfstate.name
}

output "uami_client_id" {
  description = "CI/CD UAMI client ID (azure/login client-id)"
  value       = azurerm_user_assigned_identity.cicd.client_id
}

output "uami_principal_id" {
  description = "CI/CD UAMI principal(object) ID"
  value       = azurerm_user_assigned_identity.cicd.principal_id
}

output "tenant_id" {
  description = "Entra 테넌트 ID (azure/login tenant-id)"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "대상 구독 ID (azure/login subscription-id)"
  value       = var.subscription_id
}

# envs/dev backend.tf 의 azurerm 백엔드에 그대로 사용
output "backend_config_hint" {
  description = "envs/dev backend 설정에 사용할 값"
  value = {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    key                  = "envs/dev.terraform.tfstate"
    use_azuread_auth     = true
  }
}
