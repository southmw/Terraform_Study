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
  description = "리소스 이름 접두사 (소문자/숫자)"
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.prefix))
    error_message = "prefix는 소문자/숫자 2~10자여야 합니다."
  }
}

# ---- 네트워크 ----
variable "hub_address_space" {
  type        = list(string)
  description = "허브 VNet 주소 공간"
  default     = ["10.0.0.0/24"]
}

variable "hub_shared_subnet_prefix" {
  type        = string
  description = "허브 shared 서브넷 prefix"
  default     = "10.0.0.0/26"
}

variable "spoke_address_space" {
  type        = list(string)
  description = "스포크(dev) VNet 주소 공간"
  default     = ["10.1.0.0/24"]
}

variable "spoke_workload_subnet_prefix" {
  type        = string
  description = "스포크 workload 서브넷 prefix"
  default     = "10.1.0.0/25"
}

# ---- 토글 (상시 과금 리소스) ----
variable "enable_firewall" {
  type        = bool
  description = "Azure Firewall 활성 여부 (상시 과금)"
  default     = false
}

# ---- 관리/보안 ----
variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics 보존 기간(일)"
  default     = 30
}

# ---- 정책 ----
variable "allowed_locations" {
  type        = list(string)
  description = "허용 리전 (allowed locations 정책)"
  default     = ["koreacentral", "koreasouth"]
}

variable "required_tag_name" {
  type        = string
  description = "RG 필수 태그 이름"
  default     = "project"
}

variable "tags" {
  type        = map(string)
  description = "공통 태그"
  default = {
    project   = "azure-landing-zone"
    managedBy = "terraform"
    layer     = "platform-dev"
  }
}
