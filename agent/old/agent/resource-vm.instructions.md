---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Implement unified hypervapiv2_vm: disks (new/clone/attach), NICs, firmware, security, lifecycle, and idempotency."
---

# Resource — hypervapiv2_vm

## Top-level attributes

- `name` (string), `cpu` (int), `memory` (human size), `power` (running|stopped)
- `stop_method` (graceful|force|turnoff), `wait_timeout_seconds` (int)
- Optional `tags` (map), `metadata` (map)

## Disks — scenarios by fields

- New (auto): `size`
- New (custom): `size` + `path` (validate at plan if enforced)
- Clone (auto): `clone_from`
- Clone (custom): `clone_from` + `path`
- Attach existing: `source_path`

Common:
- `name`, `purpose` (os|data|ephemeral), `type` (dynamic|fixed), `boot` (bool), `controller`, `lun`, `read_only`, `auto_attach` (default true), `protect`
- Placement hints (optional): `prefer_root`, `min_free_gb`, `co_locate_with`

Determinism:
- If `controller/lun` omitted, assign via stable function of disk name; reject collisions and report clearly.

## Network

- `network_interface { name?, switch, mac_address?, is_connected?, vlan_id? }`

## Firmware

- `firmware { secure_boot, secure_boot_template?, boot_device?, boot_order?, first_boot_application? }`

## Security

- `security { tpm, encrypt }` — if server returns 400 on Encryption Support, emit warning; proceed with TPM as requested; reflect readback in state.

## Lifecycle

- `lifecycle { delete_disks }` — only provider-owned VHDX may be deleted when true; `disk.protect=true` overrides.

## Apply sequencing

1) Ensure switch/nics created/connected as needed.
2) Disk actions (create/clone/attach) per scenario; attach as needed; boot disk flagged.
3) Firmware/security; then power changes.
4) Re-read state; normalize sizes; finalize.

## Idempotency and state

- Apply twice → no diff; use plan modifiers and normalized sizes to suppress noise.
- Record assigned `controller/lun` into state.

## Tests

- Unit: disk scenario reducer; layout assignment; state normalization.
- Demo: `01-simple-vm-new-auto` should pass Run/Test/Destroy; plan shows no diff after second apply.
