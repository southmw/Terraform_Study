variable "subscription_id" {
  type        = string
  description = "대상 Azure 구독 ID"
}

variable "location" {
  type        = string
  description = "리소스 배포 리전"
  default     = "koreacentral"
}

variable "prefix" {
  type        = string
  description = "리소스 이름 접두사 (소문자/숫자, 짧게)"
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.prefix))
    error_message = "prefix는 소문자/숫자 2~10자여야 합니다."
  }
}

variable "github_org" {
  type        = string
  description = "GitHub 조직/사용자 (예: southmw)"
}

variable "github_repo" {
  type        = string
  description = "GitHub 리포지토리 이름 (예: Terraform_Study)"
}

variable "github_environments" {
  type        = list(string)
  description = "OIDC 연합 자격증명을 만들 GitHub 환경 이름"
  default     = ["plan", "apply"]
}

variable "uami_subscription_role" {
  type        = string
  description = "UAMI에 구독 범위로 부여할 역할 (Contributor 또는 Owner). DINE/Modify 정책·RBAC가 필요하면 Owner."
  default     = "Contributor"
}

variable "assign_uami_subscription_role" {
  type        = bool
  description = "UAMI에 구독 범위 역할을 할당할지 여부 (Owner/UAA 권한 필요). 권한 없으면 false."
  default     = true
}

variable "grant_current_user_state_access" {
  type        = bool
  description = "로컬 운영자(현재 az login 사용자)에게 state Storage Blob Data Contributor를 부여할지 여부."
  default     = true
}

variable "storage_shared_access_key_enabled" {
  type        = bool
  description = "Storage 계정 키 액세스 허용 여부. 부트스트랩 신뢰성을 위해 기본 true, 운영 강화 시 false."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "공통 태그"
  default = {
    project   = "azure-landing-zone"
    managedBy = "terraform"
    layer     = "bootstrap"
  }
}
