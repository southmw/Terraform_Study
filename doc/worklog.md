# 작업 로그 (Worklog)

> 모든 신규/변경 작업은 **구현 전에** 이 로그와 관련 설계 문서를 먼저 갱신한다.
> 형식: 날짜 · 작업명 · 변경 요약 · 결정사항 · 상태

---

## 2026-06-18 — 설계 확정 및 문서화 착수

- **작업명**: Azure 구독 범위 랜딩 존 설계 정리
- **변경 요약**:
  - `doc/azure-landing-zone-design.md` 설계서 작성(전체 설계 SSOT)
  - `doc/worklog.md` 작업 로그 시작
- **주요 결정사항**:
  - 테넌트/관리 그룹 권한 부재 → 엔터프라이즈 ALZ 대신 **단일 구독 범위 랜딩 존**으로 축소
  - 모듈: **하이브리드** (허브=`avm-ptn-hubnetworking`, 나머지=`azurerm` 직접)
  - State: Azure Storage 원격(Entra 인증, 계정 키 미사용)
  - CI/CD: GitHub Actions + UAMI OIDC
  - **문서 우선 워크플로** 채택: 모든 작업 전 `doc/` 문서 선작성
- **상태**: ✅ 설계 문서화 완료 / ⏳ 구현(Phase 0 스캐폴딩) 대기

### 다음 작업 (예정)
- [ ] Phase 2: 플랫폼 구성(LA, Key Vault, 허브, 스포크, 정책)
- [ ] Phase 3: GitHub Actions 파이프라인
- [ ] Phase 4: 스포크 확장

---

## 2026-06-18 — Phase 0: 리포 스캐폴딩

- **작업명**: 프로젝트 디렉토리 구조 및 기본 파일 생성
- **변경 요약**:
  - 모든 Terraform 소스를 **`src/` 하위**로 배치하도록 구조 결정(사용자 요청)
  - `src/bootstrap/`, `src/envs/dev/`, `src/modules/` 디렉토리 + `.gitkeep`
  - `.gitignore`(루트) — `*.tfstate*`, `.terraform/`, `*.auto.tfvars`, `*.secret.tfvars` 제외
  - `README.md`(루트) — 프로젝트 개요 및 doc 링크
- **결정사항**:
  - `.github/workflows/`는 GitHub 요구사항상 리포 루트 유지, 워크플로의 `working-directory`는 `src/envs/dev`
  - 비밀 없는 `terraform.tfvars`는 커밋 대상
- **상태**: ✅ 완료 (git 루트 = 프로젝트 폴더, 모든 파일 스테이징됨 / 커밋은 사용자 요청 시)

---

## 2026-06-18 — Phase 1: State 백엔드 & ID 부트스트랩 (코드 작성)

- **작업명**: `src/bootstrap/` Terraform 코드 작성
- **입력값**: 구독 `abefcbfc-9c77-46d4-bc22-cef5aab13f22`, 리전 `koreacentral`, GitHub `southmw/Terraform_Study`
- **변경 요약**:
  - `providers.tf` — azurerm ~>4 (resource_provider_registrations=none), random ~>3.6
  - `variables.tf` — subscription/location/prefix/github_*/역할·키 토글 변수
  - `main.tf` — RG(tfstate/identity), Storage(버전관리·소프트삭제·change-feed), 컨테이너, UAMI, OIDC 연합자격증명 4건, 역할 할당 3종
  - `outputs.tf` — backend/UAMI/tenant 출력
  - `terraform.tfvars` — 확정 입력값(비밀 없음, 커밋 대상)
  - `backend.tf` — 원격 state 이전용 주석 블록
- **설계 결정**:
  - 부트스트랩 단계 Storage 키 비활성화는 보류(기본 true) → 운영 강화 시 false 전환(후속)
  - 역할 할당은 Owner/UAA 필요 → 토글로 분기 가능
- **상태**: ✅ 코드 작성 완료 / ⏳ `terraform validate` 미실행 — **Terraform CLI 미설치**(az는 설치됨)
- **블로커**: 로컬에 Terraform CLI 없음 → 설치 후 fmt/validate/apply 필요

### 검증 결과 (2026-06-18)
- Terraform v1.15.6 (설치 위치: `C:\Terraform` — bash PATH에 수동 추가 필요)
- `terraform fmt` 정상(diff 없음)
- `terraform init -backend=false` → azurerm v4.77.0, random v3.9.0 설치
- `terraform validate` → **Success**
- `.terraform.lock.hcl` 생성됨(커밋 대상)

### 배포 결과 (2026-06-18) — ✅ Apply 완료
- 로그인: `southmw@cloocus.com`, 구독 `abefcbfc-...ab13f22`(소유자), 테넌트 `a74b5451-...153c71`
- **13개 리소스 생성** (RG 2, Storage+컨테이너, UAMI, OIDC 연합자격증명 4, 역할할당 3, random 1)
- 주요 출력값(비밀 아님):
  - State RG: `rg-alz-tfstate` / Storage: `stalztfstatehbxh4l` / 컨테이너: `tfstate`
  - UAMI client_id: `9418c180-e418-4f3d-a1ac-70315e4c0e53`
  - UAMI principal_id: `91c96adc-9286-4264-b122-07c94d2f0f20`
- 코드 보정: federated credential `parent_id` → `user_assigned_identity_id`(v5.0 대비), re-plan No changes 확인
- 다음: **Phase 2** (envs/dev 플랫폼 구성)

### 부트스트랩 state 원격 이전 (2026-06-18) — ✅ 완료 (작업 A)
- `backend.tf` 활성화: `stalztfstatehbxh4l`/`tfstate`/key `bootstrap.terraform.tfstate`, `use_azuread_auth=true`
- `terraform init -migrate-state` 성공(RBAC 전파 정상) → 원격 blob에 state 저장 확인(30,557 bytes)
- `terraform plan` No changes 확인, 로컬 `terraform.tfstate*` 정리

---

## 2026-06-18 — Phase 2: 플랫폼 구성 (envs/dev) — ✅ 완료

- **작업명**: `src/envs/dev/` 플랫폼 배포 (LA, KV, 허브/스포크, 정책)
- **입력값**: 허브 10.0.0.0/24, 스포크 10.1.0.0/24, Firewall/Bastion 비활성, 허용 리전 koreacentral/koreasouth, 필수 태그 project
- **변경 요약**: providers/backend(key `envs/dev.terraform.tfstate`)/variables/main/outputs/tfvars 작성
- **생성 리소스(17)**: RG 4(mgmt/security/hub/spoke-dev), Log Analytics `log-alz-dev`, Key Vault `kv-alz-l3ss45`(RBAC·purge protection), 허브 VNet `vnet-alz-hub`+shared 서브넷(avm-ptn-hubnetworking 0.13.2), 스포크 VNet `vnet-alz-spoke-dev`+snet-workload, 피어링 2(양방향 Connected), 구독 정책 4(allowed-locations deny, require-rg-tag deny, KV/Storage audit)
- **이슈/해결**: `resource_provider_registrations=none` 때문에 1차 apply에서 `MissingSubscriptionRegistration`(Microsoft.OperationalInsights, Microsoft.KeyVault) → `az provider register`로 수동 등록(+Insights, PolicyInsights) 후 재적용 성공
- **코드 보정**: KV `enable_rbac_authorization` → `rbac_authorization_enabled`(v5.0 대비)
- **검증**: validate Success, peering 양방향 Connected, outputs 정상
- **다음**: Phase 3 (GitHub Actions 파이프라인) / 후속(예산 알림, 진단설정, Firewall 토글)

---

## 2026-06-18 — Phase 3: GitHub Actions 파이프라인 (코드 작성)

- **작업명**: `.github/workflows/` plan/apply 워크플로 작성
- **변경 요약**:
  - `plan.yml` — PR 트리거, environment `plan`, OIDC 로그인, init/fmt/validate/plan
  - `apply.yml` — main 푸시 트리거, environment `apply`(승인 게이트), init/apply
  - 인증: UAMI OIDC(시크릿 없음), `ARM_USE_OIDC`/`ARM_USE_AZUREAD` + 리포 Variables
  - 설계 문서 `doc/phase3-pipeline.md` 작성
- **검증**: 두 워크플로 YAML 문법 OK
- **남은 작업(사용자/UI)**: GitHub Variables(AZURE_CLIENT_ID/TENANT_ID/SUBSCRIPTION_ID) + Environments(plan, apply+필수리뷰어) 설정 후 브랜치 푸시→PR
- **상태**: ✅ 코드 작성 완료 / ⏳ GitHub 설정·커밋·푸시 대기(확인 필요)

### GitHub 설정·배포 (2026-06-18) — gh CLI 자동화
- gh v2.94.0 설치 위치: `C:\Program Files\GitHub CLI` (bash PATH 수동 추가 필요), 인증: southmw
- Variables 3개 설정(AZURE_CLIENT_ID/TENANT_ID/SUBSCRIPTION_ID)
- Environments: `plan`(무보호), `apply`(필수 리뷰어=southmw, 승인 게이트)
- 기본 브랜치 `master`→`main` 변경, 로컬 main 푸시(초기 커밋 a14850c)
- `terraform-apply` 워크플로 트리거 → **waiting(승인 게이트 대기)** = 정상 동작
- 다음: 승인 시 No-changes apply 확인(이미 로컬 적용됨). PR로 plan 워크플로 검증 가능

### apply 승인·완료 (2026-06-18) — ✅ 파이프라인 검증 완료
- 사용자 승인 → `terraform-apply` run 27743901588 **success**
- OIDC 인증(시크릿 없음) → 원격 state 접근 → `No changes` / Apply complete: 0 added/changed/destroyed
- Phase 0~3 전체 완료. 시크릿 없는 CI/CD 동작 확인

### 브랜치 정리 (2026-06-18)
- 빈 `master` 브랜치 삭제(원격), 기본 브랜치 `main` 단일화, 로컬 추적 참조 prune

### plan 워크플로 검증 (2026-06-18) — ✅ (작업 2)
- feature 브랜치 `chore/validate-plan-pipeline` + PR #1 (src/envs/dev/main.tf 주석만 변경)
- `terraform-plan` run 27744282184 **success** — OIDC 인증, `No changes`
- PR-트리거 plan 파이프라인 동작 확인 완료

---

## 2026-06-18 — 전체 리소스 teardown (사용자 요청)

- **작업명**: terraform 배포 리소스 전부 삭제
- **순서**: ① envs/dev destroy(17) → ② bootstrap state 로컬 환원 → ③ bootstrap destroy(13)
- **주의**: Key Vault purge protection → 소프트 삭제(7일 후 자동 purge), 이름 랜덤이라 재사용 무관
- **GitHub**: gh로 만든 Variables/Environments/워크플로는 terraform 자원이 아니므로 별도(요청 시 정리)
- **상태**: ⏳ 진행 중

### teardown 결과 (2026-06-18) — ✅ 완료
- envs/dev 17개 + bootstrap 13개 = **총 30개 리소스 삭제**
- 검증: alz 리소스 그룹 0개, 구독 정책 할당 0개
- Key Vault `kv-alz-l3ss45`만 소프트 삭제 상태(purge protection) → 2026-06-25 자동 purge 예정(수동 purge 불가)
- bootstrap state 로컬 환원 후 destroy, 로컬 state 파일 정리
- **잔존(비-terraform)**: GitHub Variables/Environments/워크플로(gh로 생성) — 별도 정리 필요 시 요청

### GitHub 정리 (2026-06-18) — ✅ 완료 (작업 A)
- 워크플로 `terraform-plan`/`terraform-apply` → `gh workflow disable`(상태 disabled_manually, 파일 보존)
- Variables 3개 삭제, Environments `plan`/`apply` 삭제
- 워크플로 YAML 상단에 비활성·재활성 안내 주석 추가
- 검증: Variables 0, Environments 0, 워크플로 2개 disabled
- 재활성: 부트스트랩 재배포 → Variables/Environments 재생성 → `gh workflow enable`
