data "azurerm_client_config" "current" {}

# Storage 계정명 전역 고유성 확보용 접미사
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# ---------------------------------------------------------------------------
# 리소스 그룹
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.prefix}-tfstate"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-${var.prefix}-identity"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# State용 Storage Account + 컨테이너
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "tfstate" {
  name                     = "st${var.prefix}tfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = var.storage_shared_access_key_enabled
  public_network_access_enabled   = true # 스터디용: private endpoint 미사용. 운영 시 제한 권장.
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# CI/CD용 User-Assigned Managed Identity + GitHub OIDC 연합 자격증명
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "cicd" {
  name                = "id-${var.prefix}-cicd"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = var.tags
}

locals {
  # GitHub Actions OIDC subject 목록
  federated_subjects = merge(
    { for env in var.github_environments : "env-${env}" => "repo:${var.github_org}/${var.github_repo}:environment:${env}" },
    {
      "pull_request" = "repo:${var.github_org}/${var.github_repo}:pull_request"
      "main_branch"  = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
    }
  )
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = local.federated_subjects

  name                      = "gh-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.cicd.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = each.value
}

# ---------------------------------------------------------------------------
# 역할 할당 (Owner/User Access Administrator 권한 필요 — 없으면 토글 off)
# ---------------------------------------------------------------------------

# UAMI: 구독 범위 control-plane 역할 (리소스 배포)
resource "azurerm_role_assignment" "uami_subscription" {
  count = var.assign_uami_subscription_role ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = var.uami_subscription_role
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}

# UAMI: state Storage 데이터플레인 역할 (원격 state 접근)
resource "azurerm_role_assignment" "uami_state_blob" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}

# 로컬 운영자: state Storage 데이터플레인 역할 (로컬에서 remote state 사용)
resource "azurerm_role_assignment" "current_user_state_blob" {
  count = var.grant_current_user_state_access ? 1 : 0

  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
