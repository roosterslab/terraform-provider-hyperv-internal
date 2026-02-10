# Windows OS Demo Full - With Differencing Disks

This example demonstrates creating a complete Windows VM using **differencing VHDXs** for maximum storage efficiency.

## What This Demonstrates

- **OS Disk**: Differencing VHDX from Windows template (fast provisioning, ~95% storage savings)
- **Data Disk**: Dynamic VHDX for user data (100GB, grows as needed)
- **SecureBoot**: Enabled with MicrosoftWindows template
- **TPM**: Enabled for Windows 11 support
- **Network**: Connected to Default Switch

## Architecture

```
Parent Template (C:/HyperV/VHDX/Users/Templates/windows-base.vhdx)
    └─> OS Disk (Differencing) - Only stores changes from parent

Data Disk (Dynamic) - Separate disk for user data
```

## Benefits

### Differencing OS Disk
- **Fast Provisioning**: New VM in seconds (no copying 20-40GB)
- **Storage Efficiency**: Only stores changes (~500MB-2GB vs 20-40GB)
- **Template Updates**: Update parent, recreate children
- **Instant Rollback**: Delete child, create new from clean parent

### Dynamic Data Disk
- **Grows On Demand**: Starts small, expands as data added
- **Separate Concerns**: OS and data on different disks
- **Easy Backup**: Backup data disk independently

## Prerequisites

### 1. Parent Windows Template

You need a Windows VHDX template with Windows pre-installed:

```powershell
# Option A: Use existing Windows ISO to create template
New-VHD -Path "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx" `
    -SizeBytes 40GB -Dynamic

# Create a temp VM, install Windows, sysprep, then save as template
# (Detailed instructions in docs)

# Option B: Copy from existing Windows VM
Copy-Item "C:\path\to\existing\windows.vhdx" `
    "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"
```

**Important**: The parent template should be:
- Windows 10/11 or Windows Server
- Sysprepped (generalized) for cloning
- Configured with your standard apps/settings
- Located in an allowed policy path

### 2. Running Services

- HyperV Management API running on localhost:5000
- Terraform 1.5+
- Go 1.22+ (to build provider)

### 3. Policy Configuration

Ensure your policy allows:
- Parent templates: `C:\HyperV\VHDX\Users\Templates\`
- VM disks: `C:\HyperV\VHDX\Users\Demo\`

## Quick Start

### 1. Create Parent Template (if needed)

```powershell
# Create a basic template (empty disk - you'll need to install Windows)
New-VHD -Path "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx" `
    -SizeBytes 40GB -Dynamic

# Or use the setup script
.\Setup-ParentTemplate.ps1
```

### 2. Build Provider

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2
go build -o terraform-provider-hypervapiv2.exe

# Setup dev override
$tfDir = "$env:APPDATA\terraform.d"
New-Item -ItemType Directory -Path $tfDir -Force

@"
provider_installation {
  dev_overrides {
    "local/vinitsiriya/hypervapiv2" = "$(Get-Location)"
  }
  direct {}
}
"@ | Set-Content "$tfDir\terraformrc"
```

### 3. Run Demo

```powershell
cd examples\windows_os_demo_full

# Using Run.ps1 (recommended)
.\Run.ps1

# Or manually
C:\terraform\terraform.exe init
C:\terraform\terraform.exe plan
C:\terraform\terraform.exe apply
```

## Configuration

Create `terraform.tfvars` to customize:

```hcl
vm_name           = "my-windows-vm"
cpu_count         = 8
memory_mb         = 16384
parent_vhdx_path  = "C:/HyperV/VHDX/Users/Templates/windows-base.vhdx"
switch_name       = "Default Switch"
```

## Verification

### Check VM Status
```powershell
Get-VM -Name "win-demo-full"
```

### Verify Differencing Disk
```powershell
$osVhd = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-os.vhdx"
Write-Host "Type: $($osVhd.VhdType)"
Write-Host "Parent: $($osVhd.ParentPath)"
Write-Host "Size: $([math]::Round($osVhd.FileSize/1MB,2))MB"
```

### Check Data Disk
```powershell
$dataVhd = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-data.vhdx"
Write-Host "Type: $($dataVhd.VhdType)"
Write-Host "Size: $([math]::Round($dataVhd.FileSize/1MB,2))MB"
```

### Start VM
```powershell
Start-VM -Name "win-demo-full"

# Connect via Hyper-V Manager or RDP
vmconnect.exe localhost "win-demo-full"
```

## Storage Analysis

```powershell
# Compare storage usage
$parent = Get-VHD "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"
$os = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-os.vhdx"
$data = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-data.vhdx"

Write-Host "Parent template: $([math]::Round($parent.FileSize/1GB,2))GB"
Write-Host "OS disk (diff):  $([math]::Round($os.FileSize/1GB,2))GB"
Write-Host "Data disk:       $([math]::Round($data.FileSize/1GB,2))GB"
Write-Host "Total:           $([math]::Round(($os.FileSize + $data.FileSize)/1GB,2))GB"
Write-Host ""
Write-Host "Traditional (cloned): ~$([math]::Round($parent.Size/1GB,2))GB + 100GB = $([math]::Round($parent.Size/1GB + 100,2))GB"
```

## Use Cases

### Development Workstations
- Quick provisioning of dev environments
- Each developer gets differencing disk from standard template
- Reset to clean state by recreating differencing disk

### Testing/QA
- Spin up test VMs in seconds
- Run tests, collect results
- Delete and recreate for next test run

### VDI/Desktop Pools
- Multiple users from same Windows template
- Massive storage savings (1 template + N small diffs)
- Centralized template management

### Training Labs
- Create 20 identical VMs for training
- Storage: 1 template + 20 small diffs (~1GB each)
- vs Traditional: 20 × 40GB = 800GB

## Maintenance

### Update Parent Template

```powershell
# 1. Shutdown all child VMs
Get-VM | Where-Object { $_.Name -like "win-demo-*" } | Stop-VM -Force

# 2. Update parent template
# Mount parent, install updates, sysprep, shutdown

# 3. Recreate child VMs with Terraform
terraform destroy
terraform apply
```

### Merge Changes to Parent

If a child VM has useful changes:
```powershell
# Export differencing disk changes
Export-VM -Name "win-demo-full" -Path "C:\Temp\Export"

# Create new parent from exported VM
# Then update terraform to use new parent
```

## Cleanup

```powershell
# Option 1: Use destroy script
.\Destroy.ps1

# Option 2: Terraform destroy
C:\terraform\terraform.exe destroy

# Option 3: Manual
Stop-VM -Name "win-demo-full" -Force
Remove-VM -Name "win-demo-full" -Force
Remove-Item "C:\HyperV\VHDX\Users\Demo\win-demo-full-*.vhdx" -Force
```

## Troubleshooting

### "Parent VHD not found"
- Verify parent exists: `Test-Path "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"`
- Check path in terraform.tfvars matches actual location

### "Parent VHD path not allowed by policy"
- Check policy allows parent template location
- Verify `ParentVhdxRootsByGroup` includes Templates directory

### VM Won't Boot
- Ensure parent template is bootable Windows installation
- Check SecureBoot/TPM settings match Windows version
- For Windows 11: TPM required
- For Windows 10: SecureBoot optional

### Poor Performance
- Check if parent template is on fast storage (SSD recommended)
- Both parent and child should be on same physical disk
- Consider using Fixed disk for data instead of Dynamic

## Advanced Scenarios

### Multiple Data Disks

```hcl
resource "hypervapiv2_vm_disk" "data_disk_2" {
  vm_name         = hypervapiv2_vm.windows_full.name
  attach_path     = "C:/HyperV/VHDX/Users/Demo/${var.vm_name}-data2.vhdx"
  new_vhd_size_gb = 200
  vhd_type        = "Fixed"  # Fixed for databases
  read_only       = false
}
```

### Read-Only Data Disk (Shared)

```hcl
resource "hypervapiv2_vm_disk" "shared_apps" {
  vm_name     = hypervapiv2_vm.windows_full.name
  attach_path = "C:/HyperV/VHDX/Users/Shared/apps.vhdx"
  read_only   = true
}
```

### Custom Network Switch

```hcl
variable "switch_name" {
  default = "Corp-Network"
}
```

## Related Documentation

- [Differencing VHDX Guide](../../DIFFERENCING-VHDX-SUPPORT.md)
- [Policy Configuration](../../../hyperv-mgmt-api-v2/docs-md/parent-vhdx-policy-guide.md)
- [API Implementation](../../../hyperv-mgmt-api-v2/docs-md/differencing-vhdx-implementation-summary.md)

## Summary

This example showcases **production-ready Windows VM provisioning** with:

✅ **Fast**: VMs created in seconds (differencing disks)
✅ **Efficient**: ~95% storage savings vs traditional cloning
✅ **Flexible**: Separate OS and data disks
✅ **Secure**: SecureBoot + TPM enabled
✅ **Maintainable**: Centralized template management

Perfect for development, testing, VDI, and training environments!
