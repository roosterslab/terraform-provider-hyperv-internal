# hypervapiv2 Provider — End-to-End Test Plan

This plan aligns test coverage with the v2 design in `plan.md` and the unified VM schema (disks, NICs, firmware, security, lifecycle). It defines a hierarchical set of demo scenarios, each with Terraform `main.tf` plus `Run.ps1` / `Destroy.ps1` / `Test.ps1`, and explicit validations. Items marked Pending require provider features that are not yet implemented.

## Objectives

- Validate policy-first behavior: plan-time suggestions and validation, explicit-path enforcement, strict mode.
- Exercise every disk scenario per design (new/clone/attach), plus deterministic controller/LUN and protection semantics.
- Verify unified VM resource: power, timeouts, NICs, firmware, security, and lifecycle flags.
- Ensure idempotency and convergence (re-apply has no changes, in-place updates behave as designed).
- Cover negative paths with clear, actionable diagnostics.

## Prerequisites

- API running in Testing env (Negotiate test identity): `scripts/Run-ApiForExample.ps1 -Action start -ApiUrl http://localhost:5011 -Environment Testing`.
- Policy pack installed (strict-multiuser defaults) so roots/extensions are in effect.
- Local Terraform dev override to use the provider binary from `bin/` (all demos already set this via `dev.tfrc`).

## Coverage Matrix (Scenarios and Status)

- Provider setup
  - Auth (negotiate), defaults, enforce_policy_paths, strict mode. Status: Partial (strict-mode UX pending dedicated demo).
- Data Sources
  - `disk_plan` (create/clone/attach with hints). Status: Ready (create); clone/attach covered when DS accepts these per design.
  - `path_validate` allowed/denied. Status: Ready.
  - `vm_plan` whole-VM preflight. Status: Pending (DS not implemented yet).
  - `policy`, `whoami`, `host_info`, `vm_shape`. Status: Partial (policy/whoami ready; host_info/vm_shape pending).
- Resources
  - `hypervapiv2_network`. Status: Stub (create exists, not fully exercised).
  - `hypervapiv2_vm` unified resource:
    - Power, stop_method, wait_timeout_seconds. Status: Pending (stop methods/timeouts not in current stub).
    - Disks: new (auto/custom), clone (auto/custom), attach; placement, controller/LUN, protect. Status: Pending (disk block not implemented yet; current new_vhd_path/size only).
    - NICs: name/switch/mac/is_connected/vlan. Status: Partial (switch_name string supported; NIC block pending).
    - Firmware/security: secure boot/template, TPM/encrypt, boot device/order. Status: Pending (API exists; provider resources missing).
    - Lifecycle: delete_disks flag. Status: Pending (provider hardcodes deleteDisks=true on delete).
- Cross-cutting
  - Idempotency (No changes on second apply). Status: Ready.
  - Negative policy (outside roots/ext). Status: Ready.
  - Invalid name policy. Status: Planned.

## Demo Hierarchy and Validations

Stage 1 — Valid Today

1) 01-simple-vm-new-auto (basic lifecycle)
   - Purpose: new OS disk via `disk_plan`, create -> read -> destroy.
   - Validations: TF outputs `os_disk_path`; API GET `/api/v2/vms/{name}`; VHDX exists; `path_validate` allowed; destroy removes VM + VHDX.

2) 02-vm-windows-perfect (policy-first, explicit checks)
   - Purpose: snapshot effective policy, plan OS path, validate path, create, verify, destroy.
   - Validations: `policy.roots` and `.extensions` non-empty; `path_validate.allowed=true`; API GET; VHDX exists; cleanup.

3) 03-vm-with-switch (switch_name passthrough)
   - Purpose: set `switch_name` and verify VM lifecycle.
   - Validations: output contains `switch_name`; API GET; VHDX exists; cleanup.

4) 04-path-validate-negative (denied path)
   - Purpose: demonstrate policy-denied path/extensions at plan time.
   - Validations: `allowed=false`; violations include `outside_allowed_roots` and/or `extension_not_allowed`.

5) 05-vm-gen1 (form factor + memory units)
   - Purpose: `generation=1`, memory as `2048MB`.
   - Validations: API GET; VHDX exists; cleanup. Note: current stub may time out intermittently; ensure eventual consistency and teardown.

6) 06-vm-idempotency (convergent apply)
   - Purpose: verify second apply returns “No changes”.
   - Validations: capture apply output; assert phrase “No changes”.

Stage 2 — Pending Provider Features (Plan Now; Implement when ready)

7) 07-disk-all-scenarios (unified `disk {}`)
   - HCL per `plan.md` 4.2: define five disk blocks:
     - New (auto): `size`, optional `placement{min_free_gb}`.
     - New (custom): `size+path`, `type`, `protect`, `placement{prefer_root,co_locate_with}`.
     - Clone (auto): `clone_from`.
     - Clone (custom): `clone_from+path`.
     - Attach existing: `source_path`, `read_only`.
   - Deterministic layout: specify `controller`/`lun` for at least one disk; omit for another and assert stable auto-assign based on disk name.
   - Validations:
     - `disk_plan` outputs `matched_root`, `normalized_path` as expected; free space `free_gb_after` decreases when creating.
     - VHDX existence for new/clone paths; no deletion of `source_path` on destroy.
     - `protect=true` disk remains after `delete_disks=true` destroy.
     - Readback layout (via API or DS) shows expected `controller/lun`.

8) 08-firmware-security (enable/disable)
   - HCL: `firmware { secure_boot=true template=... }`, `security { tpm=true, encrypt=false }`.
   - Validations: API GET firmware/security reflect requested state; toggling works; errors for unsupported host capabilities map to 400 with guidance.

9) 09-delete-semantics (resource + disk-level)
   - HCL: `lifecycle { delete_disks = true|false }`, and a mix of `disk.protect=true/false`.
   - Validations: only provider-owned VHDX deleted when `true`; `source_path` attachments never deleted; `protect=true` always preserved.

10) 10-power-stop-timeouts
   - HCL: `power="running|stopped"`, `stop_method=graceful|force|turnoff`, `wait_timeout_seconds`.
   - Validations: behavior matches server; busy/conflict surfaces as 409; timeouts respected; force turns off regardless.

11) 11-vm-plan-preflight (`data.hypervapiv2_vm_plan`)
   - HCL: use `vm_plan` to resolve `disks[]` and `network[]`, feed resolved paths/controller/lun into `hypervapiv2_vm`.
   - Validations: resolved fields populated; apply uses them deterministically; “No changes” on re-apply.

12) 12-negative-name-policy
   - HCL: set `name` without approved prefix.
   - Validations: plan fails with policy name pattern error; message points to configured prefixes.

## Demo Folder Conventions

- Each demo folder contains: `main.tf`, `Run.ps1`, `Destroy.ps1`, `Test.ps1`.
- `Run.ps1` writes a `dev.tfrc` and optionally builds provider.
- `Test.ps1` orchestrates end-to-end: run, assert outputs/API/filesystem, destroy, verify cleanup.
- Tests must be idempotent and self-cleaning; names prefixed with the user (e.g., `user-...`) per policy.

## Success Criteria per Scenario

- PASS when all listed validations are satisfied; FAIL with concise reason otherwise.
- For Pending scenarios, Test.ps1 should SKIP with a clear note that the feature is not yet implemented in the provider, and reference the design in `plan.md`.

## Implementation Notes (Provider Work Items)

- Add unified `disk {}` block per `plan.md` 4.2, including `placement{}` and fields `controller/lun/protect`.
- Add NIC block `network_interface {}` with name/switch/mac/is_connected/vlan.
- Map firmware/security to API endpoints; expose readbacks.
- Add `delete_disks` to VM lifecycle; honor `disk.protect` on delete.
- Implement `data.hypervapiv2_vm_plan`, `data.hypervapiv2_host_info`, `data.hypervapiv2_vm_shape`.
- Add stop behaviors and timeouts to VM resource.

## Run Order Recommendation

1) Stage 1 demos: 01 → 02 → 06 (quick smoke + idempotency), then 03/05/04.
2) After implementing disk/NIC/firmware/security/lifecycle features, enable Stage 2 demos in order: 07 → 09 → 10 → 08 → 11 → 12.

---

This file is the source of truth for test coverage. After each feature lands, update this plan to flip scenarios from Pending to Ready and define precise validations wired to the new schema.

