# Differencing VHDX Demo Example

This example demonstrates various ways to use differencing VHDXs with the HyperV API v2 Terraform provider.

## What This Demonstrates

This example shows **5 real-world scenarios** for differencing VHDXs:

1. **Simple Differencing Disk** - Basic VM with child disk from parent template
2. **VDI-Style Deployment** - 3 user VMs from same parent (storage savings demo)
3. **Advanced Multi-Disk** - OS disk (differencing) + separate data disk (dynamic)
4. **Mixed Disk Types** - Differencing + Fixed + Dynamic in one VM
5. **Development Environment** - Auto-start dev VM with tools pre-installed in parent

## Benefits Demonstrated

- **Storage Savings**: ~90% reduction for empty/template-based VMs
- **Fast Provisioning**: Differencing disks create in <1 second
- **Template Management**: Single parent template → multiple child VMs
- **Flexibility**: Mix disk types based on workload requirements

## Prerequisites

### Software Requirements
- Windows Server 2016+ or Windows 10/11 Pro with Hyper-V enabled
- Administrator privileges (run PowerShell as Administrator)
- Terraform 1.5 or later
- Go 1.22+ (to build the provider)
- .NET 8.0 SDK (for the API)

### Service Requirements
The HyperV Management API must be running:

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj
```

The API should be available at `http://localhost:5000`

## Setup Instructions

### Step 1: Create Parent Template

The parent VHDX serves as the base template for all differencing disks:

```powershell
# Create directory structure
New-Item -ItemType Directory -Path "C:\Temp\HyperV-Test\Templates" -Force
New-Item -ItemType Directory -Path "C:\Temp\HyperV-Test\Demo" -Force
New-Item -ItemType Directory -Path "C:\Temp\HyperV-Test\Demo\VDI" -Force

# Create parent template (10GB dynamic VHDX)
New-VHD -Path "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx" -SizeBytes 10GB -Dynamic

Write-Host "✓ Parent template created" -ForegroundColor Green
```

**Optional:** Install an OS on the parent template:
```powershell
# Mount the parent VHDX
$mountResult = Mount-VHD -Path "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx" -Passthru

# Get the disk number
$diskNumber = $mountResult.DiskNumber

# Initialize and format (CAUTION: This will erase the disk!)
Initialize-Disk -Number $diskNumber -PartitionStyle GPT
$partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter
Format-Volume -DriveLetter $partition.DriveLetter -FileSystem NTFS -NewFileSystemLabel "Template" -Confirm:$false

# Now you can copy OS files, install software, etc.
# Copy-Item "D:\sources\install.wim" -Destination "$($partition.DriveLetter):\install.wim"

# Dismount when done
Dismount-VHD -Path "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"
```

### Step 2: Build Terraform Provider

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2

# Build the provider
go build -o terraform-provider-hypervapiv2.exe

# Create Terraform dev override
$tfDir = "$env:APPDATA\terraform.d"
New-Item -ItemType Directory -Path $tfDir -Force

$devOverride = @"
provider_installation {
  dev_overrides {
    "local/vinitsiriya/hypervapiv2" = "$(Get-Location | Select-Object -ExpandProperty Path)"
  }
  direct {}
}
"@

$devOverride | Set-Content "$tfDir\terraformrc"

Write-Host "✓ Provider built and configured" -ForegroundColor Green
```

### Step 3: Configure Variables (Optional)

Create `terraform.tfvars` to customize the deployment:

```hcl
# terraform.tfvars
endpoint            = "http://localhost:5000"
parent_vhdx_path    = "C:/Temp/HyperV-Test/Templates/parent-dynamic.vhdx"
vm_name_prefix      = "demo-diff"
```

## Running the Example

### Step 1: Initialize Terraform

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2\examples\differencing-vhdx-demo

terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding local/vinitsiriya/hypervapiv2 versions matching "0.0.1"...
- Installing local/vinitsiriya/hypervapiv2 v0.0.1...

Terraform has been successfully initialized!
```

### Step 2: Review Execution Plan

```powershell
terraform plan
```

This will show the 7 VMs that will be created:
- `demo-diff-simple` - Simple differencing disk
- `demo-diff-vdi-user-1`, `demo-diff-vdi-user-2`, `demo-diff-vdi-user-3` - VDI users
- `demo-diff-advanced` - Advanced multi-disk VM
- `demo-diff-mixed` - Mixed disk types VM
- `demo-diff-dev` - Development environment (auto-start)

### Step 3: Apply Configuration

```powershell
terraform apply
```

Type `yes` when prompted.

**Expected Output:**
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

advanced_vm = {
  "id" = "..."
  "name" = "demo-diff-advanced"
}
dev_vm = {
  "id" = "..."
  "name" = "demo-diff-dev"
}
mixed_vm = {
  "id" = "..."
  "name" = "demo-diff-mixed"
}
simple_vm = {
  "id" = "..."
  "name" = "demo-diff-simple"
}
summary = {
  "expected_savings" = "~90% storage for empty disks"
  "parent_template" = "C:/Temp/HyperV-Test/Templates/parent-dynamic.vhdx"
  "total_vms" = 7
  "vdi_users" = 3
}
vdi_vms = [
  { "id" = "...", "name" = "demo-diff-vdi-user-1" },
  { "id" = "...", "name" = "demo-diff-vdi-user-2" },
  { "id" = "...", "name" = "demo-diff-vdi-user-3" }
]
```

## Verification

### Verify VMs Created

```powershell
Get-VM | Where-Object { $_.Name -like "demo-diff-*" } | Format-Table Name, State, CPUUsage, MemoryAssigned
```

**Expected Output:**
```
Name                 State MemoryAssigned
----                 ----- --------------
demo-diff-advanced   Off   8589934592
demo-diff-dev        Running 8589934592
demo-diff-mixed      Off   4294967296
demo-diff-simple     Off   2147483648
demo-diff-vdi-user-1 Off   4294967296
demo-diff-vdi-user-2 Off   4294967296
demo-diff-vdi-user-3 Off   4294967296
```

### Verify Differencing Disks

```powershell
# Check simple differencing disk
Get-VHD "C:\Temp\HyperV-Test\Demo\simple-child.vhdx" | Format-List Path, VhdType, ParentPath, FileSize, Size
```

**Expected Output:**
```
Path       : C:\Temp\HyperV-Test\Demo\simple-child.vhdx
VhdType    : Differencing
ParentPath : C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx
FileSize   : 20971520       # ~20MB (small!)
Size       : 10737418240    # 10GB (inherited from parent)
```

### Check Storage Savings

```powershell
# Calculate actual storage used
$parentSize = (Get-Item "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx").Length
$allChildren = Get-ChildItem "C:\Temp\HyperV-Test\Demo" -Recurse -Filter "*.vhdx" | Measure-Object -Property Length -Sum
$totalUsed = $parentSize + $allChildren.Sum

# Calculate traditional size (7 VMs × 10GB each)
$traditionalSize = 7 * 10GB

Write-Host "Parent template: $([math]::Round($parentSize/1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "All child disks: $([math]::Round($allChildren.Sum/1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "Total used: $([math]::Round($totalUsed/1GB, 2)) GB" -ForegroundColor Green
Write-Host "Traditional: $([math]::Round($traditionalSize/1GB, 2)) GB" -ForegroundColor Yellow
Write-Host "Savings: $([math]::Round((1 - $totalUsed/$traditionalSize) * 100, 1))%" -ForegroundColor Green
```

**Expected Output:**
```
Parent template: 20.50 MB
All child disks: 143.75 MB
Total used: 0.16 GB
Traditional: 70.00 GB
Savings: 99.8%
```

### Inspect Individual VMs

**Example 1: Simple Differencing**
```powershell
$vm = Get-VM "demo-diff-simple"
$vm | Get-VMHardDiskDrive | ForEach-Object {
    Get-VHD $_.Path | Select Path, VhdType, ParentPath
}
```

**Example 2: Advanced Multi-Disk**
```powershell
$vm = Get-VM "demo-diff-advanced"
$vm | Get-VMHardDiskDrive | ForEach-Object {
    $vhd = Get-VHD $_.Path
    Write-Host "$($vhd.Path) - Type: $($vhd.VhdType), Size: $([math]::Round($vhd.FileSize/1GB, 2))GB"
}
```

**Example 3: Mixed Disk Types**
```powershell
$vm = Get-VM "demo-diff-mixed"
$vm | Get-VMHardDiskDrive | ForEach-Object {
    $vhd = Get-VHD $_.Path
    [PSCustomObject]@{
        Path = Split-Path $vhd.Path -Leaf
        Type = $vhd.VhdType
        FileSize = "$([math]::Round($vhd.FileSize/1GB, 2)) GB"
        ParentPath = if ($vhd.VhdType -eq "Differencing") { $vhd.ParentPath } else { "N/A" }
    }
}
```

**Expected Output:**
```
Path               Type         FileSize    ParentPath
----               ----         --------    ----------
mixed-os.vhdx      Differencing 0.02 GB     C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx
mixed-db.vhdx      Fixed        50.00 GB    N/A
mixed-logs.vhdx    Dynamic      0.02 GB     N/A
```

## Starting VMs

```powershell
# Start all VMs
Get-VM | Where-Object { $_.Name -like "demo-diff-*" } | Start-VM

# Or start specific VM
Start-VM -Name "demo-diff-simple"

# Check status
Get-VM | Where-Object { $_.Name -like "demo-diff-*" } | Format-Table Name, State, Uptime
```

## Cleanup

### Option 1: Terraform Destroy

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2\examples\differencing-vhdx-demo

terraform destroy
```

Type `yes` when prompted. This will:
- Stop all running VMs
- Delete all VMs
- Delete all child VHDXs (because `vm_lifecycle { delete_disks = true }`)
- **Preserve** the parent template

### Option 2: Manual Cleanup

```powershell
# Stop and remove VMs
Get-VM | Where-Object { $_.Name -like "demo-diff-*" } | ForEach-Object {
    Stop-VM -Name $_.Name -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $_.Name -Force
}

# Remove child VHDXs
Remove-Item "C:\Temp\HyperV-Test\Demo\*.vhdx" -Force
Remove-Item "C:\Temp\HyperV-Test\Demo\VDI\*.vhdx" -Force

# Optionally remove parent template
# Remove-Item "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx" -Force
```

### Option 3: Complete Cleanup (Remove Everything)

```powershell
terraform destroy  # First destroy Terraform resources

# Then remove all test data
Remove-Item "C:\Temp\HyperV-Test" -Recurse -Force
```

## Configuration Details

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `endpoint` | `http://localhost:5000` | HyperV API endpoint URL |
| `parent_vhdx_path` | `C:/Temp/HyperV-Test/Templates/parent-dynamic.vhdx` | Path to parent template VHDX |
| `vm_name_prefix` | `demo-diff` | Prefix for VM names |

### Resources Created

| Resource | Count | Description |
|----------|-------|-------------|
| `hypervapiv2_vm.simple_differencing` | 1 | Simple differencing disk example |
| `hypervapiv2_vm.vdi_users` | 3 | VDI users from same parent |
| `hypervapiv2_vm.advanced_differencing` | 1 | Multi-disk VM (differencing OS + dynamic data) |
| `hypervapiv2_vm.mixed_types` | 1 | Mixed disk types (differencing + fixed + dynamic) |
| `hypervapiv2_vm.dev_environment` | 1 | Auto-start development environment |

## Use Cases

### Use Case 1: VDI Environment
The `vdi_users` example demonstrates how to deploy multiple user desktops from a single golden image:
- One parent template with OS and applications installed
- Each user gets their own differencing disk
- Storage savings: ~90-95% for freshly provisioned desktops
- Fast provisioning: New user desktop in seconds

### Use Case 2: Development Environments
The `dev_environment` example shows how to maintain developer workstations:
- Parent template has development tools pre-installed
- Each developer gets a differencing disk
- Updates to tools → update parent, re-create child disks
- Developers can reset to clean state easily

### Use Case 3: Test Environments
Use differencing disks for testing scenarios:
- Create parent with baseline configuration
- Spin up test VMs as differencing disks
- Run tests, capture results
- Delete child disks, repeat with fresh state

### Use Case 4: Production Workloads
The `mixed_types` example demonstrates production-appropriate disk configuration:
- **OS Disk (Differencing)**: Fast provisioning from standard image
- **Database Disk (Fixed)**: Predictable performance, no fragmentation
- **Logs Disk (Dynamic)**: Grows as needed, saves space

## Troubleshooting

### Error: "Parent VHD not found"
**Cause:** Parent template doesn't exist
**Solution:**
```powershell
New-VHD -Path "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx" -SizeBytes 10GB -Dynamic
```

### Error: "Access denied"
**Cause:** Not running as Administrator
**Solution:** Run PowerShell as Administrator

### Error: "API connection refused"
**Cause:** HyperV Management API not running
**Solution:**
```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj
```

### Error: "Parent VHD path not allowed by policy"
**Cause:** Policy restrictions on parent template location
**Solution:** Either:
1. Move parent to allowed directory (check `ParentVhdxRootsByGroup` in policy)
2. Update policy configuration to allow the template directory

### VMs created but not in Hyper-V Manager
**Cause:** Hyper-V Manager not refreshed
**Solution:** Press F5 in Hyper-V Manager or use PowerShell:
```powershell
Get-VM | Where-Object { $_.Name -like "demo-diff-*" }
```

## Next Steps

After running this example:

1. **Customize the parent template**:
   - Install your OS and applications
   - Sysprep Windows for cloning
   - Create different templates for different workloads

2. **Test performance**:
   - Compare differencing vs dynamic vs fixed disk performance
   - Monitor storage growth over time
   - Test parent template updates

3. **Implement in production**:
   - Review policy settings (`ParentVhdxRootsByGroup`)
   - Set up parent template versioning
   - Create backup strategy for parent templates
   - Document parent template update procedures

4. **Explore advanced scenarios**:
   - Checkpoint/snapshot management with differencing disks
   - Parent template update workflows
   - Disaster recovery procedures

## Related Documentation

- [Differencing VHDX Support Guide](../../DIFFERENCING-VHDX-SUPPORT.md)
- [Testing Guide](../../../TESTING-GUIDE.md)
- [Parent VHDX Policy Guide](../../../hyperv-mgmt-api-v2/docs-md/parent-vhdx-policy-guide.md)
- [API Implementation Summary](../../../hyperv-mgmt-api-v2/docs-md/differencing-vhdx-implementation-summary.md)
- [Automated Test Demo](../../demo/20-differencing-vhdx-test/README.md)

## Summary

This example demonstrates the power and flexibility of differencing VHDXs:

✅ **Storage Efficiency**: ~90-99% savings for template-based VMs
✅ **Fast Provisioning**: Sub-second disk creation
✅ **Template Management**: Single source of truth for base images
✅ **Flexibility**: Mix and match disk types based on workload needs
✅ **Production Ready**: Includes security policies and lifecycle management

The differencing VHDX feature brings enterprise VDI capabilities to your HyperV infrastructure!
