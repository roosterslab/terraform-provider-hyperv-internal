# Windows OS VM Demo

Creates a Windows VM from a base VHDX using the Hyper-V Management API v2 Terraform provider.

## Prerequisites
- Hyper-V enabled, base VHDX exists at `C:/HyperV/VHDX/Users/templates/windows-base.vhdx` (or override via variable)
- API running locally at `http://localhost:5006`
- Provider built locally. See `docs/LOCAL-DEV.md` for the standard dev setup.

## Quick Start
```powershell
# 1) Start the API for the example
cd "..\..\scripts"
./Run-ApiForExample.ps1 -Action start

# 2) From this folder, clean and plan/apply
cd "..\examples\windows_os_demo"
if (Test-Path .terraform) { Remove-Item .terraform -Recurse -Force }
if (Test-Path .terraform.lock.hcl) { Remove-Item .terraform.lock.hcl -Force }

terraform plan -var="endpoint=http://localhost:5006" -var="vm_name=test-vm"
terraform apply -auto-approve -var="endpoint=http://localhost:5006" -var="vm_name=test-vm"
```

## Variables
- `endpoint`: API base URL (default: none)
- `vm_name`: Name of the VM to create
- `base_vhdx_path`: Path to base VHDX (default: `C:/HyperV/VHDX/Users/templates/windows-base.vhdx`)

## Notes
- Provider version is pinned to `0.0.0` in `main.tf`; dev override or local plugin cache must provide that version locally.
- 32-bit Terraform is supported if you install the `windows_386` provider build in the Terraform plugin cache (see `docs/LOCAL-DEV.md`).
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\examples\auth-prod-whoami\README.md