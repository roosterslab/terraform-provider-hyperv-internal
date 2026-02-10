# Resource: hypervapiv2_vm

High-level
- Manages a Hyper-V VM via the v2 API. Focuses on an intuitive HCL with natural units, unified disk block, and clear lifecycle semantics.
- Policy and auth are enforced by the server.

Arguments
- `name` (string, required): VM name.
- `cpu` (int, optional): vCPU count.
- `memory` (string, optional): Memory (e.g., `"2GB"`, `"2048MB"`).
- `power` (string, optional): `running` | `stopped`.
- `stop_method` (string, optional): `graceful` | `force` | `turnoff`.
- `wait_timeout_seconds` (int, optional): Power transition wait time (default 240).
- `disk` (block, repeatable): Unified disk (see below).
- `firmware` (block, optional): Secure boot options.
- `security` (block, optional): vTPM, encryption (future wiring).
- `vm_lifecycle` (block, optional): Delete semantics.

Disk block
- Fields: `name`, `purpose` (`os|data|ephemeral`), `boot` (bool), `size` (string `GB/MB`), `type` (`dynamic|fixed`), `path` (optional), `clone_from` (plan-only), `source_path` (plan-only), `read_only`, `auto_attach`, `protect`, `controller`, `lun`, `placement{ prefer_root, min_free_gb, co_locate_with }`.
- Apply support today: New disk (`size`, optional `path`). If `path` omitted, provider calls server to auto-place.
- Plan-only today: `clone_from`, `source_path` (attach) for future apply.

Firmware block
- `secure_boot` (bool)
- `secure_boot_template` (string, optional)

Security block
- `tpm` (bool)
- `encrypt` (bool)

Lifecycle block `vm_lifecycle`
- `delete_disks` (bool): Delete provider-created disks on destroy. Any disk with `protect = true` suppresses deletion.

Read/State
- The provider writes back requested fields and IDs; power state transitions are best-effort with polling.

Examples

Minimal new VM with auto-placed OS disk
```hcl
resource "hypervapiv2_vm" "vm" {
  name   = "app01"
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "20GB"
  }
}
```

Custom path + lifecycle delete
```hcl
resource "hypervapiv2_vm" "vm" {
  name   = "app02"
  cpu    = 4
  memory = "4GB"
  power  = "stopped"

  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "40GB"
    path    = "D:/HyperV/VMs/app02/os.vhdx"
    type    = "fixed"
  }

  vm_lifecycle { delete_disks = true }
}
```

Stop behavior
```hcl
resource "hypervapiv2_vm" "vm" {
  name                 = "app03"
  power                = "stopped"
  stop_method          = "graceful"
  wait_timeout_seconds = 120

  disk { name = "os" purpose = "os" boot = true size = "20GB" }
}
```

