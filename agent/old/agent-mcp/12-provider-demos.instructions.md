---
applyTo: "terraform-provider-hypervapi-v2/demo/**"
role: "component"
tags: ["demos","testing","powershell","terraform"]
description: "Run demos as tests: Run.ps1 → Test.ps1 → Destroy.ps1 with dev override."
version: "0.3"
---

# Demos — Runbook

Dev override
- Scripts write `dev.tfrc` pointing Terraform to the locally built provider binary under `terraform-provider-hypervapi-v2/bin`.

Run pattern
1) Start API: `pwsh -File terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1`.
2) Run: `pwsh -File demo/<scenario>/Run.ps1 -BuildProvider`.
3) Test: `pwsh -File demo/<scenario>/Test.ps1`.
4) Destroy: `pwsh -File demo/<scenario>/Destroy.ps1`.

Focus suites
- Disk: `13-disk-unified-new-auto`, `14-delete-semantics`, `15-protect-vs-delete`.
- Power: `10-power-stop-timeouts`.
- Plan preflight: `11-vm-plan-preflight`.
- Auth (Prod Negotiate): `examples/auth-prod-whoami` (set API to Production, uses current Windows user).
 - Auth (Prod Impersonate): `examples/auth-prod-impersonate` (runs Terraform under DOMAIN\\user via Start-Process -Credential).

Conventions
- Tests validate Terraform state and server responses; avoid raw API calls unless necessary.
- Prefer idempotency checks (`No changes`) on second apply where relevant.
