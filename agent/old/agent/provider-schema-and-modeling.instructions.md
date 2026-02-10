---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Define provider schema patterns: human sizes, plan modifiers, strict/enforce flags, and state evolution."
---

# Provider Schema and Modeling

## Objectives

- Keep schema intuitive (human sizes), stable (plan modifiers), and policy-first (validation at plan).

## Provider block

```
provider "hypervapiv2" {
  endpoint = "http://localhost:5006"
  auth { method = "negotiate" } # also: bearer | none
  proxy = null
  timeout_seconds = 60
  enforce_policy_paths = true   # plan-time failure for explicit disallowed paths
  strict               = false  # escalate warnings to errors at plan
  defaults { cpu = 2, memory = "2GB", disk = "20GB" }
}
```

## Modeling guidelines

- Human sizes: accept `"2GB" | "512MB"`; normalize to MB/GB for API requests; reject unknown units.
- Plan modifiers: suppress diffs for normalized units and server-populated defaults.
- Determinism: for disks, a missing `controller/lun` may be auto-assigned from a stable function of disk name; record in state.
- Protect semantics: `disk.protect=true` prevents deletion regardless of `delete_disks`.
- Delete scope: only provider-owned VHDX eligible when `lifecycle.delete_disks=true`.
- Diagnostics: include endpoint and auth method; never include secrets.

## State evolution

- Be additive: prefer new attributes over breaking changes.
- When behavior changes, add migration code (if required) and an instruction note.

## Validation and plan-time checks

- `enforce_policy_paths=true` must call `path_validate` for explicit paths; fail with clear message on denial.
- `strict=true` promotes `warnings[]` from plan-time DS to plan errors.

## Tests

- Unit: parse size strings; placement hints normalization; controller/lun assignment collisions.
- Integration: apply twice with no changes → 0 or 1 exit (idempotent); plan‑time path denial produces plan error when enforced.
