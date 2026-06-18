# 비밀 없는 변수값 — 커밋 대상. 비밀은 절대 여기 넣지 않음.
subscription_id = "abefcbfc-9c77-46d4-bc22-cef5aab13f22"
location        = "koreacentral"
prefix          = "alz"

# 네트워크 (10.0.0.0/16 기반)
hub_address_space            = ["10.0.0.0/24"]
hub_shared_subnet_prefix     = "10.0.0.0/26"
spoke_address_space          = ["10.1.0.0/24"]
spoke_workload_subnet_prefix = "10.1.0.0/25"

# 상시 과금 리소스 (학습: 비활성)
enable_firewall = false

# 정책
allowed_locations = ["koreacentral", "koreasouth"]
required_tag_name = "project"
