---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Phased roadmap aligned to plan.md and SCAN-REPORT; reiterate non-negotiable rules."
---

# Roadmap and Rules

## Phased delivery (from SCAN-REPORT)

Phase 1 — Foundations
- Implement plan-time DS: `disk_plan`, `path_validate`, `policy`, `whoami`.
- Scaffold demos: `01-simple-vm-new-auto`, `04-plan-validate-apply`.

Phase 2 — Unified VM
- Implement `hypervapiv2_vm` with new/attach flows, human sizes, deterministic layout, limited delete scope.
- Add troubleshooting doc; run both demos in CI.

Phase 3 — Expansion
- Add `vm_plan`, `host_info`, `name_check`, `images`, clone flows; network resource in scope.
- Document proposed endpoints; sync with API repo.

## Rules (do not break)

- No policy bypass; provider surfaces denials.
- Destructive actions need explicit intent; delete scope limited; `protect` respected.
- Idempotency required; apply twice → no diff.
- Thin mapping; server is source of truth; diagnostics include endpoint+auth method, no secrets.
