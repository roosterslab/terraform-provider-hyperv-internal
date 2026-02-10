---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Run demos as sanity tests; verify idempotency and policy alignment; record PASS/FAIL."
---

# Testing and Sanity — Demos as tests

Use demos as executable tests. Each scenario lives under `demo/<name>/` and contains:
- `main.tf` — minimal HCL for the scenario
- `Run.ps1` — init+apply with dev override; prints endpoint/auth
- `Test.ps1` — validates outputs, idempotency, and one API probe
- `Destroy.ps1` — cleans up; tolerates missing resources; optionally verifies disk deletion when allowed

## Required scenarios (initial set)

1) `01-simple-vm-new-auto` — new OS disk with auto path; Internal switch; power=stopped
2) `04-plan-validate-apply` — use `disk_plan` + `path_validate` + preconditions; prove strict/enforce behavior

## Idempotency check (Test.ps1)

- Run `terraform apply -refresh-only -auto-approve`
- Run `terraform plan -detailed-exitcode`
- Exit code 0 or 1 is OK; 2 is non‑idempotent → fail the test

## Policy alignment checks

- If `enforce_policy_paths=true`, ensure explicit bad path fails at plan (precondition message includes `violations`)
- If `strict=true`, low free space in `disk_plan.warnings` must escalate to a plan error

## Diagnostics capture

- Provider logs: enable TF logs or internal switch as needed (redact secrets)
- API logs: check `hyperv-mgmt-api-v2/logs/` when running locally

## Reporting

- For each scenario, record Build/Lint/Tests: PASS/FAIL and attach relevant outputs
