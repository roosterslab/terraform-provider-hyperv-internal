# HCL Reference

This reference documents the provider, resources, and data sources currently implemented in hypervapiv2.

Provider
```hcl
provider "hypervapiv2" {
  endpoint = "http://localhost:5006"  # required
  auth {
    method   = "negotiate"            # none | bearer | negotiate
    # username = "DOMAIN\\user"
    # password = "secret"
  }
  # Optional (observability)
  proxy           = null
  timeout_seconds = 300
  log_http        = false
}
```
Notes
- Policy and identity enforcement happen on the API server. The provider does not locally enforce path policy.

Resource: hypervapiv2_vm
```hcl
resource "hypervapiv2_vm" "vm" {
  name   = "app01"
  cpu    = 4
  memory = "8GB"
  power  = "running"                 # running | stopped
  stop_method          = "graceful"  # graceful | force | turnoff
  wait_timeout_seconds = 240

  # Unified disks (apply supports create, clone, and attach)
  disk {
    name       = "os"
    purpose    = "os"                # os | data | ephemeral
    boot       = true
    size       = "40GB"              # new disk size (GB or MB strings)
    type       = "dynamic"           # dynamic | fixed
    # path     = "D:/HyperV/VMs/app01/os.vhdx"  # optional; auto-placed if omitted (create)
    # clone_from = "D:/HyperV/Templates/base.vhdx" # clone: provider will clone then create VM with the cloned VHDX
    # source_path = "D:/HyperV/Existing/os.vhdx"   # attach: provider will create VM (no disk) then attach this VHDX
    controller = "SCSI"              # optional
    lun        = 0                    # optional
    placement {                       # optional hints used for auto-placement
      prefer_root    = "D:/HyperV/VMs"
      min_free_gb    = 20
      co_locate_with = "os"
    }
    protect = false                   # if true, overrides delete_disks on destroy
  }

  firmware {                          # optional
    secure_boot = true
    # secure_boot_template = "MicrosoftWindows"
  }

  security {                           # optional (future wiring)
    tpm     = true
    encrypt = false
  }

  vm_lifecycle { delete_disks = false } # delete provider-created disks on destroy
}
```
Behavior
- Auto-placement: If a disk has no `path`, the provider calls the server to suggest a compliant path.
- Power transitions: Start/Stop issued to satisfy `power`, honoring `stop_method` and `wait_timeout_seconds`.
- Delete semantics: `vm_lifecycle.delete_disks` controls whether provider-created VHDX are deleted. Any `disk.protect = true` suppresses deletion.

Resource: hypervapiv2_network (experimental)
```hcl
resource "hypervapiv2_network" "lan" {
  name = "lan-internal"
  type = "Internal"  # API mapping in progress
}
```

Data Source: hypervapiv2_disk_plan
```hcl
data "hypervapiv2_disk_plan" "os" {
  vm_name   = "app01"
  operation = "create"      # create | clone | attach (apply supports create today)
  purpose   = "os"
  size_gb   = 40             # required for create
  # clone_from   = "D:/HyperV/Templates/base.vhdx"  # for clone planning
  # Optional hints:
  prefer_root    = "D:/HyperV/VMs"
  min_free_gb    = 20
  co_locate_with = "os"
  ext            = "vhdx"
}
```
Outputs: `path`, `reason`, `matched_root`, `normalized_path`, `writable`, `free_gb_after`, `host`, `warnings[]`.

Data Source: hypervapiv2_path_validate
```hcl
data "hypervapiv2_path_validate" "custom" {
  path      = "D:/HyperV/VMs/app01/os.vhdx"
  operation = "create"
  ext       = "vhdx"
}
```
Outputs: `allowed`, `matched_root`, `normalized_path`, `message`, `violations[]`.

Data Source: hypervapiv2_policy
```hcl
data "hypervapiv2_policy" "current" {}
```
Outputs: roots, extensions, quotas, name_patterns, deny_reasons.

Data Source: hypervapiv2_whoami
```hcl
data "hypervapiv2_whoami" "me" {}
```
Outputs: user, domain, sid, groups.

Limitations (current)
- Disks: attach currently applies to the chosen disk block (boot/purpose=os or first disk). Attaching additional data disks will be added next.
- Network: resource is a stub pending API wiring.

See also
- Demos under `terraform-provider-hypervapi-v2/demo/*` for end-to-end examples.
- Design in `terraform-provider-hypervapi-v2/plan.md`.
