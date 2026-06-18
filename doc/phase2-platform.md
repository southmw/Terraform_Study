# Phase 2 — 플랫폼 구성 (설계)

> 위치: `src/envs/dev/` · 원격 backend(key `envs/dev.terraform.tfstate`)
> 상위 설계: [azure-landing-zone-design.md](azure-landing-zone-design.md) · 선행: [phase1-bootstrap.md](phase1-bootstrap.md)

작성일: 2026-06-18

---

## 1. 입력값 (확정)

| 항목 | 값 |
|---|---|
| 주소 대역 | 10.0.0.0/16 기반 — 허브 `10.0.0.0/24`, 스포크(dev) `10.1.0.0/24` |
| Firewall / Bastion | **모두 비활성**(토글로 향후 활성). 상시 과금 회피 |
| 정책 강도 | 기본 가드레일(허용 리전 deny, RG 태그 강제 deny, KV/Storage 보안 audit) |
| 허용 리전 | `koreacentral`, `koreasouth` |
| 필수 태그 | `project` |

---

## 2. 생성 리소스

| 리소스 그룹 | 리소스 | 모듈/리소스 |
|---|---|---|
| `rg-alz-mgmt` | Log Analytics Workspace | `azurerm_log_analytics_workspace` |
| `rg-alz-security` | Key Vault (RBAC, purge protection) | `azurerm_key_vault` (+`random_string` 접미사) |
| `rg-alz-hub` | 허브 VNet + 서브넷(shared) | `Azure/avm-ptn-hubnetworking/azurerm` `0.13.2` |
| `rg-alz-spoke-dev` | 스포크 VNet + workload 서브넷 | `azurerm_virtual_network` (+subnet) |
| — | 허브↔스포크 양방향 피어링 | `azurerm_virtual_network_peering` ×2 |
| 구독 범위 | Azure Policy 할당 4종 | `azurerm_subscription_policy_assignment` |

### 네트워크 상세
- 허브 VNet `vnet-alz-hub` (`10.0.0.0/24`)
  - subnet `shared` `10.0.0.0/26` (firewall/bastion 서브넷은 토글 활성 시 추가)
  - `firewall` 인자 생략 → Azure Firewall 미생성 / `mesh_peering_enabled=false`(단일 허브)
- 스포크 VNet `vnet-alz-spoke-dev` (`10.1.0.0/24`)
  - subnet `snet-workload` `10.1.0.0/25`
- 피어링: 허브→스포크, 스포크→허브 (`allow_forwarded_traffic=true`, 게이트웨이 전송 비활성)

### 정책 할당 (모두 audit/deny — DINE 없음 → 관리 ID 불필요)
| 정책 | 효과 | 정의 ID(빌트인) |
|---|---|---|
| 허용 리전 제한 | deny | `e56962a6-4747-49cd-b67b-bf8b01975c4c` |
| RG 필수 태그(`project`) | deny | `871b6d14-10aa-478d-b590-94f262ecfa99` |
| KV purge protection 확인 | audit | `0b60c0b2-2dc2-4e1c-b5c9-abbed971de53` |
| Storage 공용 접근 비활성 확인 | audit | `b2982f36-99f2-4db5-8eff-283140c09693` |

---

## 3. 주요 설계 결정

- **하이브리드**: 허브만 AVM(`avm-ptn-hubnetworking` 0.13.2), LA·KV·스포크는 `azurerm` 직접
- **Provider**: `azurerm ~>4`, `azapi ~>2`, `modtm ~>0.3`, `random ~>3.6`. 모듈 `enable_telemetry=false`
- **Backend**: Phase 1 Storage 재사용(`stalztfstatehbxh4l`/`tfstate`/key `envs/dev.terraform.tfstate`, `use_azuread_auth=true`)
- **정책 효과**: DINE/Modify 미사용(관리 ID·역할할당 불필요) → audit/deny만. RG 태그 강제는 resource가 아닌 **RG** 범위로 두어 리소스 생성 광범위 차단 회피
- **비용**: Firewall/Bastion/게이트웨이 미생성. LA 수집·KV는 소액. 예산 알림은 별도 후속(또는 본 Phase에 `azurerm_consumption_budget_subscription` 옵션 포함 검토)

---

## 4. 실행 절차

```bash
cd src/envs/dev
export PATH="/c/Terraform:$PATH"
terraform init          # 원격 backend + 모듈/프로바이더
terraform validate
terraform plan
terraform apply         # 사용자 확인 후
```

---

## 5. 검증

1. `terraform validate`/`plan` 통과
2. apply 후: `rg-alz-mgmt/security/hub/spoke-dev` 및 LA·KV·VNet 2개 생성 확인
3. 피어링 상태 `Connected` (양방향) — `az network vnet peering list`
4. 정책: 비허용 리전 리소스 생성 시 deny, 태그 없는 RG 생성 시 deny 동작
5. KV: RBAC 모델·purge protection 활성 확인

---

## 5-1. 실제 배포 결과 (2026-06-18) — ✅ 완료

- 17개 리소스 생성, 피어링 양방향 **Connected**
- Key Vault: `kv-alz-l3ss45` (`https://kv-alz-l3ss45.vault.azure.net/`)
- Log Analytics: `log-alz-dev`
- **주의(중요)**: `resource_provider_registrations=none` 설정으로 인해 RP 자동 등록이 안 됨 → 최초 apply 시 `MissingSubscriptionRegistration` 발생.
  배포 전 다음 RP를 **수동 등록** 필요:
  ```bash
  az provider register --namespace Microsoft.OperationalInsights
  az provider register --namespace Microsoft.KeyVault
  az provider register --namespace Microsoft.Insights
  az provider register --namespace Microsoft.PolicyInsights
  # (Microsoft.Network/Storage/ManagedIdentity/Authorization은 기등록됨)
  ```

## 6. 향후/후속

- Firewall·Bastion 토글 활성(주소: AzureFirewallSubnet `10.0.0.64/26`, AzureBastionSubnet `10.0.0.128/26`)
- LA 연동 진단설정(DINE 정책 또는 명시적 `azurerm_monitor_diagnostic_setting`)
- 예산 알림(`azurerm_consumption_budget_subscription`)
- GitHub Actions 파이프라인(Phase 3)
