# Differencing VHDX Test Demo

This demo tests the differencing VHDX implementation in the Terraform provider.

## What This Tests

1. **Differencing disk** using top-level `vhd_type` and `parent_path` attributes
2. **Fixed disk** for comparison
3. **Dynamic disk** (default behavior - backward compatibility)
4. **Differencing disk** using `disk{}` block with `type` and `parent_path`

## Prerequisites

- Windows with Hyper-V enabled
- Administrator privileges
- Go 1.22+ installed
- Terraform installed
- HyperV Management API running on `http://localhost:5000`

### Start the API

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj
```

## Test Steps

### 1. Setup (Create Parent Templates)

```powershell
cd demo\20-differencing-vhdx-test
.\Setup.ps1
```

This creates:
- `C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx` (10GB Dynamic VHDX)
- Test directories for child VHDXs

### 2. Build and Apply

```powershell
.\Run.ps1 -BuildProvider
```

This:
- Builds the Terraform provider
- Configures Terraform dev override
- Initializes Terraform
- Applies the configuration (creates 4 test VMs)

### 3. Verify Results

```powershell
.\Test.ps1
```

This verifies:
- All 4 VMs were created
- VHDXs have correct types (Differencing, Fixed, Dynamic)
- Differencing disks have correct parent references
- Parent VHDXs exist

Expected output:
```
=== Differencing VHDX Test Verification ===

Testing VM: tf-diff-test-01
  ✓ VM exists
  ✓ VHDX exists: C:\Temp\HyperV-Test\Diff\child-dynamic.vhdx
  VHD Type: Differencing
  ✓ VHD Type correct: Differencing
  ✓ Parent Path: C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx
  ✓ Parent VHDX exists
  File Size: 0.02 GB
  ✅ PASS: All checks passed

[... similar for other VMs ...]

========================================
Test Summary:
========================================

✅ PASS - Test 1: Differencing (top-level)
✅ PASS - Test 2: Fixed disk
✅ PASS - Test 3: Dynamic (default)
✅ PASS - Test 4: Differencing (disk block)

Total: 4 tests
Passed: 4
Failed: 0

🎉 All tests passed!
```

### 4. Manual Verification

You can also manually inspect the VHDXs:

```powershell
# Check differencing disk details
Get-VHD C:\Temp\HyperV-Test\Diff\child-dynamic.vhdx | Format-List Path, VhdType, ParentPath, FileSize, Size

# Expected output:
Path       : C:\Temp\HyperV-Test\Diff\child-dynamic.vhdx
VhdType    : Differencing
ParentPath : C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx
FileSize   : ~20MB (small!)
Size       : 10GB (inherited from parent)

# Check fixed disk
Get-VHD C:\Temp\HyperV-Test\Fixed\disk-fixed.vhdx | Format-List VhdType, FileSize

# Expected output:
VhdType  : Fixed
FileSize : ~10GB (preallocated)

# Check dynamic disk
Get-VHD C:\Temp\HyperV-Test\Dynamic\disk-dynamic.vhdx | Format-List VhdType, FileSize

# Expected output:
VhdType  : Dynamic
FileSize : ~20MB (grows as needed)

# List all test VMs
Get-VM | Where-Object { $_.Name -like "tf-*-test-*" }
```

### 5. Cleanup

```powershell
.\Destroy.ps1
```

To also remove test directories:
```powershell
.\Destroy.ps1 -CleanupAll
```

## Test Configuration Details

### Test 1: Differencing Disk (Top-Level)

```hcl
resource "hypervapiv2_vm" "test_differencing_dynamic" {
  name       = "tf-diff-test-01"

  new_vhd_path   = "C:\\Temp\\HyperV-Test\\Diff\\child-dynamic.vhdx"
  vhd_type       = "Differencing"
  parent_path    = "C:\\Temp\\HyperV-Test\\Templates\\parent-dynamic.vhdx"
}
```

**Verifies:** Top-level `vhd_type` and `parent_path` attributes work

### Test 2: Fixed Disk

```hcl
resource "hypervapiv2_vm" "test_fixed" {
  name            = "tf-fixed-test-01"

  new_vhd_path    = "C:\\Temp\\HyperV-Test\\Fixed\\disk-fixed.vhdx"
  new_vhd_size_gb = 10
  vhd_type        = "Fixed"
}
```

**Verifies:** Fixed disk type works correctly

### Test 3: Dynamic Disk (Default)

```hcl
resource "hypervapiv2_vm" "test_dynamic" {
  name            = "tf-dynamic-test-01"

  new_vhd_path    = "C:\\Temp\\HyperV-Test\\Dynamic\\disk-dynamic.vhdx"
  new_vhd_size_gb = 10
  # vhd_type omitted - defaults to Dynamic
}
```

**Verifies:** Backward compatibility - `vhd_type` defaults to Dynamic

### Test 4: Differencing Disk (disk{} Block)

```hcl
resource "hypervapiv2_vm" "test_disk_block_differencing" {
  name = "tf-diff-test-02"

  disk {
    name        = "os"
    boot        = true
    path        = "C:\\Temp\\HyperV-Test\\Diff\\child-block.vhdx"
    type        = "Differencing"
    parent_path = "C:\\Temp\\HyperV-Test\\Templates\\parent-dynamic.vhdx"
  }
}
```

**Verifies:** Differencing disks work with `disk{}` block syntax

## Expected Storage Savings

Differencing disks provide significant storage savings:

- **Parent template:** ~20MB (empty 10GB dynamic disk)
- **Each child:** ~20MB (minimal initial size)
- **Traditional approach:** 4 VMs × 10GB = 40GB
- **With differencing:** 1 parent (20MB) + 4 children (80MB) = ~100MB
- **Savings:** ~99.75%!

## Troubleshooting

### Issue: "Parent VHD not found"
**Solution:** Run `.\Setup.ps1` first to create parent templates

### Issue: "go: command not found"
**Solution:** Install Go 1.22+ and ensure it's in PATH

### Issue: API connection refused
**Solution:** Start the HyperV Management API:
```powershell
cd ..\..\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api
```

### Issue: "Access denied" or JEA errors
**Solution:** Ensure you're running PowerShell as Administrator

### Issue: Terraform provider not found
**Solution:** Run with `-BuildProvider` flag:
```powershell
.\Run.ps1 -BuildProvider
```

## Success Criteria

✅ All 4 VMs created successfully
✅ Differencing disks have correct `VhdType` = Differencing
✅ Differencing disks reference correct parent
✅ Fixed disk has `VhdType` = Fixed and is preallocated
✅ Dynamic disk has `VhdType` = Dynamic (default)
✅ File sizes are appropriate for each type
✅ Test.ps1 reports all tests passed

## Next Steps

After successful testing:
1. Document any issues or improvements needed
2. Test with real workloads (install OS, test performance)
3. Test policy restrictions with `ParentVhdxRootsByGroup`
4. Test error cases (missing parent, invalid paths, etc.)

## Related Documentation

- [Differencing VHDX Support](../../DIFFERENCING-VHDX-SUPPORT.md)
- [API Implementation Summary](../../../hyperv-mgmt-api-v2/docs-md/differencing-vhdx-implementation-summary.md)
- [Parent VHDX Policy Guide](../../../hyperv-mgmt-api-v2/docs-md/parent-vhdx-policy-guide.md)
