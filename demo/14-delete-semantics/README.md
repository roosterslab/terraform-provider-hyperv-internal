# Demo 14: Delete Semantics (Explicit)

This demo tests explicit VM lifecycle delete semantics, specifically controlling disk deletion behavior through the `vm_lifecycle` block.

## Purpose

Tests the following lifecycle features:
- Explicit control over disk deletion during VM destroy
- `vm_lifecycle.delete_disks` configuration
- Verification that disks are removed when `delete_disks = true`
- Unified disk syntax with lifecycle management

## Scripts

### Run.ps1
Creates a VM with explicit delete semantics configuration.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-del-semantics"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "lifecycle-test-vm" -Endpoint "http://localhost:5006"

# Build provider before running
.\Run.ps1 -BuildProvider
```

### Test.ps1
Tests VM creation and destruction with explicit disk deletion semantics.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-del-semantics"

# Test with custom endpoint
.\Test.ps1 -VmName "lifecycle-test-vm" -Endpoint "http://localhost:5006"
```

### Destroy.ps1
Destroys the Terraform resources with explicit lifecycle handling.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-del-semantics"): Name of the VM to destroy

**Usage:**
```powershell
# Destroy with defaults
.\Destroy.ps1

# Destroy with specific parameters
.\Destroy.ps1 -VmName "lifecycle-test-vm" -Endpoint "http://localhost:5006"
```

## Configuration

The demo uses explicit lifecycle configuration:
```hcl
vm_lifecycle {
  delete_disks = true
}
```

This ensures that associated VHDX files are deleted when the VM is destroyed, providing explicit control over resource cleanup.

## What It Tests

- Explicit lifecycle configuration is respected
- Disks are deleted when `delete_disks = true` is set
- Filesystem cleanup occurs during Terraform destroy
- Unified disk syntax works with lifecycle management
- State consistency with lifecycle settings

## Notes

- **Different from Demo 09**: This demo uses explicit `vm_lifecycle` configuration
- Demo 09 tests default provider behavior for disk deletion
- This demo provides user control over deletion semantics
- Useful for scenarios where disk preservation is required

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Support for `vm_lifecycle` block in the provider
- Policy allowing disk creation and deletion