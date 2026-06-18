# Azure 구독 범위 랜딩 존 — 설계서

> 본 문서는 프로젝트의 단일 진실 소스(Single Source of Truth)다. 모든 신규/변경 작업은 **구현 전에** 이 문서(또는 `doc/` 하위 작업 문서)를 먼저 갱신한다. → [문서화 워크플로](#문서화-워크플로-상시-규칙)

작성일: 2026-06-18 · 상태: 설계 확정, 구현 전

---

## 1. Context (배경)

당초 목표는 Microsoft 공식 **AVM ALZ 패턴 모듈 + ALZ Terraform 가속기(Deploy-Accelerator)**로 엔터프라이즈급 Azure Landing Zone(ALZ)을 구축하는 것이었다.

그러나 **현재 테넌트에 관리 그룹/테넌트 루트(`/`) 권한이 없음**이 확인되었다. ALZ의 핵심인 관리 그룹 계층과 테넌트 범위 정책은 테넌트 루트 권한이 필수이므로 구현이 불가능하다.

따라서 범위를 **권한이 있는 단일 구독 내부의 "구독 범위 랜딩 존"**으로 축소한다.

- 가속기(`Deploy-Accelerator`)와 관리 그룹 모듈(`avm-ptn-alz`)은 **제외**
- 모듈은 **하이브리드** 방식: 허브 네트워크만 AVM, 나머지는 `azurerm` 직접 작성
- 향후 테넌트 권한 확보 시 관리 그룹 계층/가속기로 **승격하는 경로**를 본 문서에 남긴다

### 확정 사항

| 항목 | 결정 |
|---|---|
| 범위 | 단일 구독 — 허브-스포크 네트워크 + 구독/RG 범위 Azure Policy + Log Analytics + Key Vault |
| 모듈 방식 | 하이브리드 (허브 = `avm-ptn-hubnetworking`, 나머지 = `azurerm` 직접) |
| State 백엔드 | 동일 구독 내 Azure Storage 원격 (Entra 인증, 계정 키 미사용) |
| CI/CD | GitHub Actions + UAMI OIDC (Entra 앱 등록 불필요) |

참고:
- [Terraform 접근법(AVM)](https://azure.github.io/Azure-Landing-Zones/terraform/)
- [avm-ptn-hubnetworking](https://github.com/Azure/terraform-azurerm-avm-ptn-hubnetworking)

---

## 2. 문서화 워크플로 (상시 규칙)

**모든 신규/변경 작업은 코드 작업을 시작하기 전에 먼저 `doc/` 폴더의 문서로 정리한다.**

- 위치: 프로젝트 루트의 **`doc/`** 폴더
- 절차: ① 작업 전 설계/변경 내용을 문서에 작성·갱신 → ② 사용자 확인 → ③ 그다음 구현
- 산출물:
  - `doc/azure-landing-zone-design.md` — 본 설계서(전체 설계의 SSOT)
  - `doc/worklog.md` — 작업 로그(날짜·작업명·변경요약·결정사항). 새 작업마다 항목 추가
  - 개별 기능/변경 건은 `doc/` 하위에 작업 단위 문서로 작성 후 구현

---

## 3. 권한 요건 (먼저 확인)

| 작업 | 필요 권한 | 없을 때 |
|---|---|---|
| 리소스 배포(VNet, LA, KV 등) | 구독/RG **Contributor** (control plane) | 필수 |
| **State 접근(Entra 인증)** | Storage 계정에 **Storage Blob Data Contributor** (data plane) | `init` 실패 — Contributor만으론 blob 접근 불가 |
| **Key Vault 시크릿 관리** | **Key Vault Administrator** (또는 Secrets Officer, data plane) | 시크릿 쓰기/읽기 불가 |
| RBAC 역할 할당 | **Owner** 또는 User Access Administrator | 역할 할당·DINE 정책 생략 |
| 정책 할당(구독/RG) | **Owner** 또는 Resource Policy Contributor | 정책 생략 또는 audit/deny만 |
| UAMI + 연합 자격증명 | 구독 **Contributor** (Microsoft.ManagedIdentity) | 로컬 `az login`으로 대체 |

> **핵심 함정**: control-plane Contributor는 **데이터 플레인 접근(Storage blob, KV 시크릿)을 주지 않는다.** UAMI와 로컬 운영자 **둘 다** 위 data-plane 역할이 필요하며 RBAC 전파에 수 분 소요.
>
> DeployIfNotExists/Modify 효과 정책은 시스템 할당 ID + 범위 RBAC가 필요 → **Owner/UAA 없으면 audit/deny 효과만 사용.**

---

## 4. 아키텍처 개요 (단일 구독)

```
[구독] (권한 보유)
  ├─ rg-tfstate   : State Storage Account(키 비활성, 공용접근 제한, 버전관리/소프트삭제 ON) + 컨테이너
  ├─ rg-identity  : UAMI + GitHub OIDC 연합 자격증명(plan/apply 환경별)
  ├─ rg-mgmt      : Log Analytics Workspace              ← azurerm 직접
  ├─ rg-security  : Key Vault(RBAC 모델, purge protection) ← azurerm 직접
  ├─ rg-hub       : 허브 VNet + (토글)Firewall/Bastion       ← avm-ptn-hubnetworking
  └─ rg-spoke-*   : 스포크 VNet + 허브 피어링            ← azurerm 직접
  +  구독/RG 범위 Azure Policy 할당(태그·리전·보안 기준)   ← azurerm_subscription_policy_assignment
```

---

## 5. 사전 준비

1. **Azure**: 권한 있는 구독 1개. 리소스 프로바이더 등록 — `Microsoft.Network`, `Microsoft.OperationalInsights`, `Microsoft.KeyVault`, `Microsoft.ManagedIdentity`, `Microsoft.Storage`, `Microsoft.PolicyInsights`, `Microsoft.Authorization`, `Microsoft.Insights`
2. **GitHub**: 리포 생성 + 환경(plan/apply) 구성 권한
3. **로컬(Windows 11)**: Terraform CLI, Azure CLI(`az`), Git, GitHub CLI(`gh`)

---

## 6. 작업 단계

### Phase 0 — 문서화 & 리포 스캐폴딩
- **먼저** `doc/` 폴더 + 설계 문서 작성(문서 우선 원칙) — 본 문서, `doc/worklog.md`
- git 초기화, 디렉토리 구조 (**모든 Terraform 소스는 `src/` 하위**):
  ```
  doc/                  azure-landing-zone-design.md, worklog.md, (작업 단위 문서)
  src/
    bootstrap/          state account + UAMI + 연합자격증명 (로컬 state, 1회성)
    envs/dev/           main.tf, variables.tf, terraform.tfvars(비밀無), backend.tf, providers.tf
    modules/            (필요 시 래퍼)
  .github/workflows/    plan.yml, apply.yml   (GitHub 요구사항상 리포 루트 유지, working-directory=src/envs/dev)
  .gitignore
  ```
- **`.gitignore`(주의)**: `*.tfstate*`, `.terraform/`, `*.auto.tfvars`, `*.secret.tfvars`만 제외. 비밀 없는 `terraform.tfvars`는 커밋(CI가 비대화식으로 읽음). 비밀은 tfvars에 **아예 넣지 않음**(KV/OIDC만).

### Phase 1 — State 백엔드 & ID 부트스트랩 (로컬 1회)
- `src/bootstrap/`에서 **로컬 state**로 생성:
  - Storage Account(키 액세스 비활성, 공용 접근 제한, **blob 버전관리·소프트삭제·change-feed ON**), 컨테이너 `tfstate`(+ `bootstrap`용 별도 키)
  - UAMI 생성 → 구독/RG RBAC(Owner 또는 Contributor) **및 Storage Blob Data Contributor** 부여
  - GitHub OIDC **연합 자격증명을 subject별로 분리 생성**:
    - `repo:<org>/<repo>:environment:plan`
    - `repo:<org>/<repo>:environment:apply`
    - (필요 시) `repo:<org>/<repo>:pull_request`, `:ref:refs/heads/main`
  - 로컬 운영자 본인에게도 Storage Blob Data Contributor / Key Vault Administrator 부여
- **부트스트랩 state 귀착**: 생성 직후 `terraform init -migrate-state`로 부트스트랩 state를 같은 계정의 `bootstrap` 키로 이전(채택)
- 파이프라인 첫 실행 전 **UAMI·RBAC(blob data 포함)·연합자격증명 3가지가 모두 완료**돼야 함

### Phase 2 — 플랫폼 구성 (`src/envs/dev`)
- **`providers.tf`**: `required_providers`에 `azurerm`(+`azapi`,`random`,`modtm` — hubnetworking 모듈용) 버전 핀. AVM 모듈은 `enable_telemetry=false`로 modtm 비활성 가능.
- **`backend.tf`**: azurerm 백엔드에 `use_azuread_auth = true`만 코드에 둠. **`use_oidc`는 하드코딩 안 함** → CI에서 `ARM_USE_OIDC=true` 환경변수로 구동(로컬은 `az login` CLI 인증). 동일 backend가 로컬·CI 양쪽 동작.
- 리소스:
  - Log Analytics: `azurerm_log_analytics_workspace`(보존기간 등)
  - Key Vault: `azurerm_key_vault`(`enable_rbac_authorization=true`, `purge_protection_enabled=true`, 공용접근 제한)
  - 허브: `Azure/avm-ptn-hubnetworking/azurerm`(버전 핀, 토글 Firewall/Bastion)
  - 스포크: `azurerm_virtual_network` + `azurerm_virtual_network_peering`(양방향)
  - 정책: `azurerm_subscription_policy_assignment`/`_resource_group_policy_assignment`(허용 리전, 태그 강제, Storage 키 비활성, KV purge protection). **DINE/Modify는 Owner/UAA 있을 때만**, 없으면 audit/deny.
  - 비용 가드: `azurerm_consumption_budget_subscription`(알림 임계치)

### Phase 3 — GitHub Actions 파이프라인
- `plan.yml`(PR) / `apply.yml`(승인 후 main). `permissions: id-token: write, contents: read`
- `azure/login@v2`에 UAMI `client-id`/`tenant-id`/`subscription-id` 지정(시크릿 없음), 잡 env에 `ARM_USE_OIDC=true`
- plan → 환경 승인 게이트 → apply. 환경별 federated subject가 정확히 매칭돼야 인증 성공.

### Phase 4 — 검증 후 스포크 확장
- 워크로드별 스포크 VNet + 피어링 추가, 동일 plan→승인→apply 반복

---

## 7. 시크릿 / 접속 문자열 관리

원칙: **파이프라인=OIDC 단기토큰, state=Entra 인증, 앱 시크릿=Key Vault+Managed Identity, 로컬엔 어떤 비밀도 영속 저장 안 함.**

| 대상 | 방식 | 비고 |
|---|---|---|
| 배포 인증(Actions→Azure) | **UAMI WIF(OIDC)** | GitHub에 클라이언트 시크릿/인증서 저장 안 함, 단기 토큰 |
| state 백엔드 | `use_azuread_auth=true`(+CI `ARM_USE_OIDC`) | 계정 키/connection string 미사용, Entra RBAC(+blob data role) |
| tfstate 파일 | 암호화+RBAC 최소권한+네트워크 제한+버전관리/소프트삭제 | 로컬 저장 금지 |
| 앱 시크릿(접속 문자열/API 키) | **Key Vault + Managed Identity + KV 참조** | tfvars/코드 하드코딩 금지. 정책으로 KV 소프트삭제/purge protection 강제 |
| 부트스트랩 GitHub PAT | 로컬 1회성, 사용 후 폐기/만료 | 필요 시 `TF_VAR_*` 또는 KV data source |

---

## 8. 검증 (Verification)

1. **State**: `terraform init` 성공(blob data role 전파 후), Storage에 state·blob lease 잠금 동작, 계정 키 비활성 확인
2. **OIDC**: plan 워크플로가 시크릿 없이 Azure 인증 성공
3. **리소스**: apply 후 Log Analytics / Key Vault(RBAC·purge protection) / 허브 VNet / 스포크 피어링(`Connected`) CLI·포털 확인
4. **정책**: 비허용 리전 deny, 태그 누락 audit 동작 확인
5. **시크릿**: `git grep`으로 코드/리포에 평문 비밀·접속 문자열 없음 확인
6. **비용**: 예산 알림 구성 확인

---

## 9. 리스크 / 주의사항

- **데이터플레인 권한 누락**이 가장 흔한 init/배포 실패 원인 → Storage Blob Data Contributor / Key Vault Administrator 선부여
- **권한 부족 분기**: Owner 없으면 RBAC·DINE 정책 막힘 → audit/deny·역할할당 생략으로 진행
- **purge protection 부작용**: destroy 후에도 KV 이름·소프트삭제 state account가 잔존 → 이름 재사용 지연
- **비용**: Firewall/Bastion/DDoS/게이트웨이·Log Analytics 수집은 상시 과금 → 토글 비활성 + 예산 알림 + 정리 시 `terraform destroy` 순서 문서화
- **모듈 버전 핀 고정**으로 재현성 확보

---

## 10. 향후 승격 경로 (테넌트 권한 확보 시)

테넌트 루트/관리 그룹 권한을 확보하면 본 구독 범위 구성을 엔터프라이즈급 ALZ로 승격한다.

- ALZ Terraform 가속기(`Deploy-Accelerator`)로 부트스트랩(관리 그룹·정책·CI/CD)
- `avm-ptn-alz`(관리 그룹 계층 + 정책), `avm-ptn-alz-management`, `avm-ptn-alz-sub-vending`(구독 벤딩) 도입
- 현 단일 구독을 ALZ 관리 그룹 계층 아래 랜딩 존 구독으로 편입
