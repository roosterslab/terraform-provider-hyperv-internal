---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Step-by-step developer workflow to add features safely: decide provider vs API, implement, demo, and validate." 
---

# Developer Perspective and Feature Workflow

Use this workflow to add or evolve provider features with minimal rework. It assumes the API server is the source of truth for behavior and policy.

## 1) Read before you start

- `terraform-provider-hypervapi-v2/plan.md` — UX and schema intent
- `terraform-provider-hypervapi-v2/SCAN-REPORT.md` — gaps vs. plan and proposed API endpoints
- API ownership (do not duplicate): `hyperv-mgmt-api-v2/agent/overview.instructions.md` and linked docs

## 2) Decide scope: provider vs API

- If the API already exposes the capability → implement in provider.
- If missing or partial on server → draft contract in `agent/api-alignment-and-proposed-contracts.instructions.md` and open a task/PR in API repo. Keep provider guarded (feature-flag or return clear "not supported").

## 3) Choose type of change

- Plan-time data source (preferred first): `disk_plan`, `path_validate`, `vm_plan`, `policy`, `whoami`, `host_info`, `vm_shape`, `images`, `name_check`.
- Resource: `hypervapiv2_vm` (create/update/delete; disks, NICs, firmware, security, lifecycle). `hypervapiv2_network` in later phase.
- Config-only: provider-level fields (`strict`, `enforce_policy_paths`, `defaults{}`) — keep thin.

## 4) Implement

- Define schema with human sizes and validation; prefer plan modifiers to stabilize diffs.
- Map 1:1 to API endpoints; pass through server errors; include endpoint + auth method in diagnostics (no secrets).
- Idempotency: re-read state after apply; ensure apply twice → no diff.
- Delete semantics: only provider-owned VHDX when `delete_disks=true`; `disk.protect=true` overrides.

## 5) Demos as tests

Create `demo/<scenario>/{main.tf,Run.ps1,Test.ps1,Destroy.ps1}`:
- Run.ps1: prints dev override/provider path, endpoint/auth; runs `terraform init` + `apply`.
- Test.ps1: validates outputs; runs `apply -refresh-only` and `plan -detailed-exitcode` to assert idempotency (exit code 0 or 1 allowed; 2 is a failure).
- Destroy.ps1: handles missing resources; if `delete_disks=true`, externally verify disk removal where safe.

## 6) Quality gates (green-before-done)

- Lint → Build → Unit tests → Demos Test.ps1. Record PASS/FAIL.
- For API deltas: link to server PR; ensure API sanity tests green.

## 7) PR checklist (evidence)

- Updated/added instruction node(s) if behavior changed.
- Demo updated or added; Test.ps1 proves idempotency.
- Clear error mapping and messages; no secrets; endpoint/auth method included.
- If server change: link to API docs/PR; provider guarded until server lands.
