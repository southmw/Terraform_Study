# Azure 구독 범위 랜딩 존 (Terraform)

테넌트/관리 그룹 권한 부재로, 엔터프라이즈급 ALZ 대신 **권한 있는 단일 구독 범위의 랜딩 존**을 Terraform으로 구축하는 학습/실무 프로젝트.

- 모듈: 하이브리드 — 허브 네트워크만 `avm-ptn-hubnetworking`, Log Analytics·Key Vault·스포크 VNet은 `azurerm` 직접
- State: 단일 구독 내 Azure Storage 원격(Entra 인증)
- CI/CD: GitHub Actions + UAMI OIDC

## 디렉토리 구조

```
doc/                  설계서·작업 로그 (모든 작업은 구현 전 여기 먼저 정리)
src/
  bootstrap/          State 백엔드 & ID 부트스트랩 (Phase 1)
  envs/dev/           플랫폼 구성 (Phase 2)
  modules/            래퍼 모듈 (필요 시)
.github/workflows/    CI/CD (Phase 3) — working-directory: src/envs/dev
```

## 문서

- 설계서(SSOT): [doc/azure-landing-zone-design.md](doc/azure-landing-zone-design.md)
- 작업 로그: [doc/worklog.md](doc/worklog.md)

> **작업 규칙**: 모든 신규/변경 작업은 코드 구현 전에 `doc/` 문서를 먼저 작성·갱신한다.
