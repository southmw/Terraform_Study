output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace 리소스 ID"
  value       = azurerm_log_analytics_workspace.mgmt.id
}

output "key_vault_id" {
  description = "Key Vault 리소스 ID"
  value       = azurerm_key_vault.security.id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.security.vault_uri
}

output "hub_vnet_id" {
  description = "허브 VNet 리소스 ID"
  value       = local.hub_vnet_id
}

output "spoke_vnet_id" {
  description = "스포크(dev) VNet 리소스 ID"
  value       = azurerm_virtual_network.spoke.id
}

output "resource_groups" {
  description = "생성된 리소스 그룹"
  value = {
    mgmt     = azurerm_resource_group.mgmt.name
    security = azurerm_resource_group.security.name
    hub      = azurerm_resource_group.hub.name
    spoke    = azurerm_resource_group.spoke.name
  }
}
