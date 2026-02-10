# Differencing VHDX Support in Terraform Provider

## Changes Implemented

The Terraform provider now supports creating and managing differencing VHDXs through the HyperV Management API v2.

### Files Modified

1. **`internal/client/client.go`**
   - Added `VhdType` and `ParentPath` fields to `CreateVmRequest` struct
   - Updated `AttachDisk()` function to accept VHD parameters: `vhdSizeGB`, `vhdType`, `parentPath`

2. **`internal/resources/vm.go`**
   - Added `VhdType` and `ParentPath` fields to `vmModel`
   - Added `ParentPath` field to `diskModel`
   - Updated schema to include:
     - `vhd_type`: VHD type (Dynamic, Fixed, or Differencing)
     - `parent_path`: Parent VHD path for differencing disks
   - Updated `Create` function to read and pass VHD parameters to API

## Terraform Configuration Examples

### Example 1: Create VM with Differencing Disk

```hcl
resource "hypervapiv2_vm" "dev_vm" {
  name       = "dev-vm-001"
  generation = 2
  cpu        = 4
  memory     = "4GB"

  switch_name = "External"

  # Create differencing disk from template
  new_vhd_path   = "C:\\VMs\\Dev\\alice\\vm-001.vhdx"
  vhd_type       = "Differencing"
  parent_path    = "C:\\Templates\\win2022-base.vhdx"

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }
}
```

### Example 2: Create VM with Fixed Disk

```hcl
resource "hypervapiv2_vm" "prod_sql" {
  name       = "prod-sql-01"
  generation = 2
  cpu        = 8
  memory     = "16GB"

  # Create fixed-size disk for production
  new_vhd_path   = "C:\\VMs\\Prod\\sql-01.vhdx"
  new_vhd_size_gb = 200
  vhd_type       = "Fixed"

  vm_lifecycle {
    delete_disks = true
  }
}
```

### Example 3: Create VM with Dynamic Disk (Default)

```hcl
resource "hypervapiv2_vm" "test_vm" {
  name       = "test-vm"
  generation = 2

  # Creates dynamic disk (backward compatible)
  new_vhd_path   = "C:\\VMs\\test.vhdx"
  new_vhd_size_gb = 40
  # vhd_type defaults to "Dynamic" when not specified
}
```

### Example 4: Using disk{} Block with Differencing Disk

```hcl
resource "hypervapiv2_vm" "vdi_desktop" {
  name       = "vdi-user-123"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    path        = "C:\\VDI\\Users\\user123.vhdx"
    type        = "Differencing"
    parent_path = "C:\\VDI\\Templates\\win11-base.vhdx"

    placement {
      prefer_root   = "C:\\VDI\\Users"
      min_free_gb   = 50
    }
  }
}
```

### Example 5: Multiple Disks with Different Types

```hcl
resource "hypervapiv2_vm" "multi_disk_vm" {
  name       = "app-server-01"
  generation = 2
  cpu        = 4
  memory     = "8GB"

  # OS disk - differencing from template
  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    path        = "C:\\VMs\\AppServers\\os.vhdx"
    type        = "Differencing"
    parent_path = "C:\\Templates\\server-2022.vhdx"
  }

  # Data disk - fixed size for performance
  disk {
    name        = "data"
    purpose     = "data"
    path        = "C:\\VMs\\AppServers\\data.vhdx"
    size        = "100GB"
    type        = "Fixed"
    auto_attach = true
  }
}
```

## VHD Type Options

| Type | Description | Use Case |
|------|-------------|----------|
| **Dynamic** (default) | Grows as data is added | Development, testing, general use |
| **Fixed** | Preallocated to full size | Production workloads requiring consistent performance |
| **Differencing** | Child disk referencing parent | VDI, template-based deployments, storage optimization |

## Differencing Disk Requirements

When using `vhd_type = "Differencing"`:

1. **`parent_path` is required** - Must specify the parent VHD template path
2. **Parent must exist** - The parent VHDX file must already exist on the host
3. **Parent must be in allowed paths** - Parent path must pass policy validation
4. **Size is inherited** - Child automatically inherits parent size; `new_vhd_size_gb` is ignored

## Policy Configuration

Parent VHDXs are validated against policy. Configure separate template roots:

**`policy-packs/strict-multiuser/users/HG_HV_Dev.parent.json`:**
```json
{
  "priority": 110,
  "parentVhdxRootsByGroup": {
    "HG_HV_Dev": [
      "C:\\Templates",
      "C:\\BaseImages\\Dev"
    ]
  }
}
```

**`policy-packs/strict-multiuser/users/HG_HV_Dev.storage.json`:**
```json
{
  "priority": 110,
  "storage": {
    "allowedRoots": [
      "C:\\VMs\\Dev"
    ]
  }
}
```

This configuration:
- Restricts **child VHDs** to `C:\VMs\Dev\`
- Restricts **parent VHDs** to `C:\Templates\` and `C:\BaseImages\Dev\`
- Prevents users from using arbitrary parents

## Migration from Previous Version

### Before (Dynamic only):
```hcl
resource "hypervapiv2_vm" "vm" {
  name            = "my-vm"
  new_vhd_path    = "C:\\VMs\\my-vm.vhdx"
  new_vhd_size_gb = 40
}
```

### After (Explicit type, same behavior):
```hcl
resource "hypervapiv2_vm" "vm" {
  name            = "my-vm"
  new_vhd_path    = "C:\\VMs\\my-vm.vhdx"
  new_vhd_size_gb = 40
  vhd_type        = "Dynamic"  # Optional - same as default
}
```

### After (Using differencing):
```hcl
resource "hypervapiv2_vm" "vm" {
  name            = "my-vm"
  new_vhd_path    = "C:\\VMs\\my-vm.vhdx"
  vhd_type        = "Differencing"
  parent_path     = "C:\\Templates\\base.vhdx"
}
```

## Backward Compatibility

✅ **Fully backward compatible!**

- All new fields are optional
- Default behavior unchanged (Dynamic VHDs)
- Existing Terraform configurations work without modification
- `vhd_type` defaults to `"Dynamic"` when not specified

## Building the Provider

```bash
cd terraform-provider-hypervapi-v2
go build -o terraform-provider-hypervapiv2
```

## Testing

### Create Parent Template
```powershell
New-VHD -Path C:\Templates\base.vhdx -SizeBytes 40GB -Dynamic
```

### Apply Terraform Configuration
```bash
terraform init
terraform plan
terraform apply
```

### Verify Differencing Disk
```powershell
Get-VHD C:\VMs\child.vhdx | Select Path, VhdType, ParentPath
```

Expected output:
```
Path                      VhdType       ParentPath
----                      -------       ----------
C:\VMs\child.vhdx         Differencing  C:\Templates\base.vhdx
```

## Benefits

### Storage Optimization (VDI Example)
- **Before:** 100 VMs × 40GB = 4TB storage
- **After:** 1 parent (40GB) + 100 children (2GB each) = 240GB storage
- **Savings:** 94% reduction!

### Fast Provisioning
- Create new VMs instantly (differencing disk creation is near-instant)
- No need to copy entire disk images
- Consistent base configuration across all VMs

### Template Management
- Update base template, all children can benefit
- Centralized template storage
- Easy rollback by recreating child from known-good parent

## Error Messages

| Scenario | Error |
|----------|-------|
| Missing parent_path | "ParentPath required when VhdType is Differencing" |
| Parent doesn't exist | "Parent VHD does not exist: {path}" |
| Parent not in policy | "Parent VHD path '{path}' not allowed by policy" |
| Invalid vhd_type | "Unknown VHD type" |

## Troubleshooting

### Issue: "Parent VHD not found"
**Solution:** Ensure parent exists and path is correct
```powershell
Test-Path C:\Templates\base.vhdx
```

### Issue: "Parent path not allowed by policy"
**Solution:** Add parent path to `parentVhdxRootsByGroup` in policy configuration

### Issue: Child disk appears as 0 bytes
**Solution:** This is normal for differencing disks - they grow as data is written

## References

- [HyperV Management API Differencing VHDX Documentation](../hyperv-mgmt-api-v2/docs-md/differencing-vhdx-implementation-summary.md)
- [Parent VHDX Policy Guide](../hyperv-mgmt-api-v2/docs-md/parent-vhdx-policy-guide.md)
- [Microsoft Docs: Differencing Disks](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/use-differencing-disks)

## Summary

✅ **Implementation complete!**
- VHD type selection (Dynamic, Fixed, Differencing)
- Parent path support for differencing disks
- Policy validation for parent paths
- Backward compatible with existing configurations
- Supports both legacy fields and disk{} blocks

The Terraform provider is now ready to create and manage differencing VHDXs through the HyperV Management API v2.
