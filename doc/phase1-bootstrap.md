# Phase 1 — State 백엔드 & ID 부트스트랩 (설계)

> 이 작업은 **로컬 state로 1회 실행**하여 원격 state 백엔드와 CI/CD용 ID(UAMI+OIDC)를 만든다.
> 상위 설계: [azure-landing-zone-design.md](azure-landing-zone-design.md)

작성일: 2026-06-18 · 위치: `src/bootstrap/`

---

## 1. 입력값 (확정)

| 변수 | 값 |
|---|---|
| `subscription_id` | `abefcbfc-9c77-46d4-bc22-cef5aab13f22` |
| `location` | `koreacentral` (Korea Central) |
| `github_org` | `southmw` |
| `github_repo` | `Terraform_Study` (https://github.com/southmw/Terraform_Study.git) |
| `prefix` | `alz` (리소스 이름 접두사) |

---

## 2. 생성 리소스

| 리소스 | Terraform | 설명 |
|---|---|---|
| 리소스 그룹 (state) | `azurerm_resource_group` | `rg-<prefix>-tfstate` |
| 리소스 그룹 (identity) | `azurerm_resource_group` | `rg-<prefix>-identity` |
| 랜덤 접미사 | `random_string` | Storage 계정명 전역 고유성 확보(6자) |
| Storage Account | `azurerm_storage_account` | TLS1.2, blob 버전관리·소프트삭제·change-feed ON, public access(스터디용 허용) |
| State 컨테이너 | `azurerm_storage_container` | `tfstate` |
| UAMI | `azurerm_user_assigned_identity` | CI/CD용 ID (`id-<prefix>-cicd`) |
| OIDC 연합 자격증명 | `azurerm_federated_identity_credential` (for_each) | GitHub Actions subject별 |
| 역할 할당 (UAMI/구독) | `azurerm_role_assignment` | Contributor @ 구독 (토글) |
| 역할 할당 (UAMI/blob) | `azurerm_role_assignment` | Storage Blob Data Contributor @ Storage |
| 역할 할당 (운영자/blob) | `azurerm_role_assignment` | 로컬 운영자 Storage Blob Data Contributor (토글) |

### OIDC 연합 자격증명 subject (issuer=`https://token.actions.githubusercontent.com`, audience=`api://AzureADTokenExchange`)
- `repo:southmw/Terraform_Study:environment:plan`
- `repo:southmw/Terraform_Study:environment:apply`
- `repo:southmw/Terraform_Study:pull_request`
- `repo:southmw/Terraform_Study:ref:refs/heads/main`

---

## 3. 주요 설계 결정

- **Provider**: `azurerm ~> 4`, `resource_provider_registrations = "none"`(권한 제한 대비, RP는 수동 등록), `subscription_id`는 변수 주입(4.x 필수)
- **Storage 키 비활성화 보류**: 부트스트랩 단계에서는 컨테이너 생성 신뢰성을 위해 **`shared_access_key_enabled = true`** 유지(변수로 토글). 원격 backend는 어차피 `use_azuread_auth=true`(Entra)로 동작하며, 키는 사용하지 않음. **운영 강화 시 false로 전환**(운영자/UAMI에 Blob Data 역할 전파 확인 후) — 후속 작업으로 분리.
- **데이터플레인 권한**: control-plane Contributor로는 state blob 접근 불가 → UAMI와 로컬 운영자 **둘 다** `Storage Blob Data Contributor` 부여. 단, 역할 할당 자체는 구독 Owner/User Access Administrator 권한 필요 → 권한 없으면 해당 토글 끄고 수동 부여.
- **DINE/Modify 정책용 권한**: UAMI에 Owner가 필요할 수 있음 → 기본은 Contributor, 변수 `uami_subscription_role`로 조정 가능.
- **부트스트랩 state 귀착**: 최초 `terraform apply`는 로컬 state. 이후 `terraform init -migrate-state`로 같은 Storage의 `tfstate` 컨테이너, 키 `bootstrap.terraform.tfstate`로 이전.

---

## 4. 실행 절차

```bash
cd src/bootstrap
az login                       # 구독 컨텍스트 설정
az account set --subscription abefcbfc-9c77-46d4-bc22-cef5aab13f22
terraform init                 # 로컬 state
terraform plan
terraform apply
# (선택) 원격으로 state 이전:
#   backend.tf 의 azurerm 블록 활성화 후
terraform init -migrate-state
```

출력값으로 `envs/dev` backend에 넣을 storage account/컨테이너/RG, UAMI client_id/principal_id, tenant_id 제공.

---

## 5. 검증

1. `terraform validate` 통과 (코드 작성 직후)
2. apply 후 `rg-alz-tfstate` / `rg-alz-identity` 및 Storage·컨테이너·UAMI 생성 확인
3. UAMI에 연합 자격증명 4건, Blob Data Contributor 역할 확인
4. `terraform init -migrate-state`로 원격 state 이전 성공

---

## 6. 권한 부족 시 분기

- 구독 Owner/UAA 없음 → `assign_uami_subscription_role=false`, `grant_current_user_state_access=false`로 두고, 역할은 관리자에게 수동 요청
- RP 미등록 오류(`MissingSubscriptionRegistration`) → 사전 준비의 `az provider register` 수동 실행
