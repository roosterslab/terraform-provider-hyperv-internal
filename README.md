# hypervapiv2 Terraform Provider (v2)

This is a new provider targeting the Hyper-V Management API v2. It follows the v2 design in `plan.md` and starts with plan-time data sources and stub resources.

## Status

- Implemented data sources: `hypervapiv2_whoami`, `hypervapiv2_policy`, `hypervapiv2_disk_plan`, `hypervapiv2_path_validate`.
- Stub resources: `hypervapiv2_vm`, `hypervapiv2_network` (schema minimal; API calls pending).
- Demos: see `demo/00-whoami-and-policy` and `demo/01-simple-vm-new-auto`.

## Build

- Go 1.22 required.
- Build: `go build ./...`

## Run demos

Use Windows PowerShell 5.1 or PowerShell 7:

- `pwsh -File .\demo\00-whoami-and-policy\Run.ps1 -BuildProvider`
- `pwsh -File .\demo\00-whoami-and-policy\Test.ps1`
- `pwsh -File .\demo\00-whoami-and-policy\Destroy.ps1`

- `pwsh -File .\demo\01-simple-vm-new-auto\Run.ps1 -BuildProvider -VmName tfv2-demo`
- `pwsh -File .\demo\01-simple-vm-new-auto\Test.ps1`
- `pwsh -File .\demo\01-simple-vm-new-auto\Destroy.ps1`

These scripts configure a Terraform dev override to load the locally-built provider from `bin/terraform-provider-hypervapiv2.exe`.
