data "azurerm_client_config" "current" {}

locals {
  hub_vnet_name = "vnet-${var.prefix}-hub"
  sub_scope     = "/subscriptions/${var.subscription_id}"
  builtin       = "/providers/Microsoft.Authorization/policyDefinitions/"
  # 허브 VNet의 결정적 리소스 ID (스포크→허브 피어링용)
  hub_vnet_id = "${azurerm_resource_group.hub.id}/providers/Microsoft.Network/virtualNetworks/${local.hub_vnet_name}"
}

# ---------------------------------------------------------------------------
# 리소스 그룹
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "mgmt" {
  name     = "rg-${var.prefix}-mgmt"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-${var.prefix}-security"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.prefix}-hub"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.prefix}-spoke-dev"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# 관리: Log Analytics
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "mgmt" {
  name                = "log-${var.prefix}-dev"
  resource_group_name = azurerm_resource_group.mgmt.name
  location            = azurerm_resource_group.mgmt.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# 보안: Key Vault (RBAC 모델, purge protection)
# ---------------------------------------------------------------------------
resource "random_string" "kv" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_key_vault" "security" {
  name                = "kv-${var.prefix}-${random_string.kv.result}"
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true # 스터디용. 운영 시 private endpoint 권장.

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 네트워크: 허브 (AVM 패턴 모듈) — Firewall/Bastion 미생성
# ---------------------------------------------------------------------------
module "hub" {
  source  = "Azure/avm-ptn-hubnetworking/azurerm"
  version = "0.13.2"

  enable_telemetry = false

  hub_virtual_networks = {
    hub = {
      name                 = local.hub_vnet_name
      address_space        = var.hub_address_space
      location             = var.location
      parent_id            = azurerm_resource_group.hub.id
      mesh_peering_enabled = false

      subnets = {
        shared = {
          name             = "shared"
          address_prefixes = [var.hub_shared_subnet_prefix]
        }
      }

      # Firewall은 토글 활성 시 별도 구성 (현재 비활성)
      firewall = null
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 네트워크: 스포크(dev) — azurerm 직접
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.prefix}-spoke-dev"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  address_space       = var.spoke_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "spoke_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_workload_subnet_prefix]
}

# 허브 ↔ 스포크 양방향 피어링
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke-dev"
  resource_group_name          = azurerm_resource_group.hub.name
  virtual_network_name         = local.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [module.hub]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-dev-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = local.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [module.hub]
}

# ---------------------------------------------------------------------------
# Azure Policy (구독 범위, audit/deny — 관리 ID 불필요)
# ---------------------------------------------------------------------------
resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations (deny)"
  subscription_id      = local.sub_scope
  policy_definition_id = "${local.builtin}e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_subscription_policy_assignment" "require_rg_tag" {
  name                 = "require-rg-tag"
  display_name         = "Require a tag on resource groups (deny)"
  subscription_id      = local.sub_scope
  policy_definition_id = "${local.builtin}871b6d14-10aa-478d-b590-94f262ecfa99"

  parameters = jsonencode({
    tagName = { value = var.required_tag_name }
  })
}

resource "azurerm_subscription_policy_assignment" "audit_kv_purge_protection" {
  name                 = "audit-kv-purge-protection"
  display_name         = "Key vaults should have deletion protection enabled (audit)"
  subscription_id      = local.sub_scope
  policy_definition_id = "${local.builtin}0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
}

resource "azurerm_subscription_policy_assignment" "audit_storage_public_access" {
  name                 = "audit-storage-public-access"
  display_name         = "Storage accounts should disable public network access (audit)"
  subscription_id      = local.sub_scope
  policy_definition_id = "${local.builtin}b2982f36-99f2-4db5-8eff-283140c09693"
}
