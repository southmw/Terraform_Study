# Phase 3 — GitHub Actions 파이프라인 (설계)

> 위치: `.github/workflows/` (리포 루트) · 대상: `src/envs/dev`
> 상위 설계: [azure-landing-zone-design.md](azure-landing-zone-design.md)

작성일: 2026-06-18 · 리포: `southmw/Terraform_Study`

---

## 1. 목표

GitHub Actions에서 **시크릿 없이(UAMI OIDC)** Terraform plan/apply를 실행한다.
- PR → `plan` (검토용)
- main 푸시 → `apply` (환경 승인 게이트 후 배포)

Phase 1에서 생성한 OIDC 연합 자격증명 subject를 그대로 사용:
- `repo:southmw/Terraform_Study:environment:plan`
- `repo:southmw/Terraform_Study:environment:apply`
- `repo:southmw/Terraform_Study:pull_request`
- `repo:southmw/Terraform_Study:ref:refs/heads/main`

---

## 2. 인증 방식 (시크릿 없음)

- 워크플로 권한: `id-token: write`, `contents: read`
- `azure/login@v2` (OIDC) + Terraform azurerm provider/backend OIDC
- 환경변수(시크릿 아님 → **리포 Variables**로 저장):
  - `ARM_USE_OIDC=true`, `ARM_USE_AZUREAD=true`
  - `ARM_CLIENT_ID=${{ vars.AZURE_CLIENT_ID }}` ← UAMI client_id `9418c180-e418-4f3d-a1ac-70315e4c0e53`
  - `ARM_TENANT_ID=${{ vars.AZURE_TENANT_ID }}` ← `a74b5451-a280-4768-a5cd-cb47af153c71`
  - `ARM_SUBSCRIPTION_ID=${{ vars.AZURE_SUBSCRIPTION_ID }}` ← `abefcbfc-9c77-46d4-bc22-cef5aab13f22`
- backend는 `use_azuread_auth=true` → state 접근도 OIDC(UAMI=Storage Blob Data Contributor)

> 이 값들은 비밀이 아닌 식별자이므로 **Variables**(Settings → Secrets and variables → Actions → Variables)로 등록. 시크릿 불필요.

---

## 3. 워크플로

### `plan.yml` (PR 트리거)
- `on: pull_request` (paths: `src/envs/dev/**`, `.github/workflows/**`)
- `environment: plan` → OIDC subject `environment:plan` 매칭
- steps: checkout → setup-terraform → azure/login(OIDC) → `terraform init` → `fmt -check` → `validate` → `plan` → (선택) PR 코멘트

### `apply.yml` (main 푸시 트리거)
- `on: push` (branches: main, paths: `src/envs/dev/**`, `.github/workflows/**`)
- `environment: apply` → **환경 보호 규칙(필수 리뷰어)으로 승인 게이트**
- steps: checkout → setup-terraform → azure/login(OIDC) → `terraform init` → `apply -auto-approve`

공통: `defaults.run.working-directory: src/envs/dev`

---

## 4. GitHub 사전 설정 (UI, 1회)

`gh` CLI 미설치 → GitHub 웹 UI에서 설정:

1. **Variables** (Settings → Secrets and variables → Actions → Variables → New repository variable):
   - `AZURE_CLIENT_ID` = `9418c180-e418-4f3d-a1ac-70315e4c0e53`
   - `AZURE_TENANT_ID` = `a74b5451-a280-4768-a5cd-cb47af153c71`
   - `AZURE_SUBSCRIPTION_ID` = `abefcbfc-9c77-46d4-bc22-cef5aab13f22`
2. **Environments** (Settings → Environments → New environment):
   - `plan` (보호 규칙 없음)
   - `apply` (Required reviewers에 본인 추가 → 승인 게이트)

> RP 사전 등록(Phase 2 이슈)도 완료 상태여야 함(OperationalInsights/KeyVault/Insights/PolicyInsights).

---

## 5. 검증

1. 워크플로 파일 푸시 후, PR 생성 → `plan` 워크플로가 **시크릿 없이** Azure 인증 성공, plan 출력
2. main 머지 → `apply` 워크플로가 승인 게이트 대기 → 승인 후 `No changes`(이미 로컬 apply 완료 상태이므로) 확인
3. Actions 로그에 `Login successful` (OIDC) 및 backend 접근 성공 확인

---

## 6. 주의

- 로컬에서 이미 `apply` 완료했으므로 CI의 첫 apply는 `No changes`가 정상(파이프라인 동작 검증 목적)
- `terraform.tfvars`(비밀 없음)는 커밋되어 CI가 비대화식으로 읽음
- 향후: plan 결과 PR 코멘트, drift 감지 스케줄, 다중 환경(envs/prod) 확장
