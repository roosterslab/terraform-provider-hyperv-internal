# Data Sources

## hypervapiv2_disk_plan
Suggests a compliant VHDX path for a disk operation according to server policy. Use for plan-time guidance and to seed `disk.path` when desired.

```hcl
data "hypervapiv2_disk_plan" "os" {
  vm_name   = "app01"
  operation = "create"      # create | clone | attach
  purpose   = "os"
  size_gb   = 40             # required for create
  # clone_from   = "D:/HyperV/Templates/base.vhdx"  # required for clone
  # Optional hints:
  prefer_root    = "D:/HyperV/VMs"
  min_free_gb    = 20
  co_locate_with = "os"
  ext            = "vhdx"
}
```
Outputs: `path`, `reason`, `matched_root`, `normalized_path`, `writable`, `free_gb_after`, `host`, `warnings[]`.

## hypervapiv2_path_validate
Checks whether a path is allowed by policy for a given operation.

```hcl
data "hypervapiv2_path_validate" "custom" {
  path      = "D:/HyperV/VMs/app01/os.vhdx"
  operation = "create"
  ext       = "vhdx"
}
```
Outputs: `allowed`, `matched_root`, `normalized_path`, `message`, `violations[]`.

## hypervapiv2_policy
Returns effective policy snapshot for the caller.

```hcl
data "hypervapiv2_policy" "current" {}
```
Outputs: `roots`, `extensions`, `quotas`, `name_patterns`, `deny_reasons`.

## hypervapiv2_whoami
Returns identity information for the current caller.

```hcl
data "hypervapiv2_whoami" "me" {}
```
Outputs: `user`, `domain`, `sid`, `groups`.

Notes
- These data sources do not enforce policy locally; they expose server guidance to improve plan readability and safety.

