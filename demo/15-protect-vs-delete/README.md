# Demo 15: Protect vs Delete

This demo tests disk protection behavior versus deletion semantics, specifically how protected disks affect the overall deletion policy.

## Purpose

Tests the following protection features:
- Disk protection with `protect = true` flag
- Interaction between protected disks and `delete_disks` lifecycle setting
- How protected disks override global deletion policies
- Preservation of disks when protection is enabled

## Scripts

### Run.ps1
Creates a VM with both regular and protected disks.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-protect"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "protect-test-vm" -Endpoint "http://localhost:5006"

# Build provider before running
.\Run.ps1 -BuildProvider
```

### Test.ps1
Tests VM creation and destruction with protected disk behavior.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-protect"

# Test with custom endpoint
.\Test.ps1 -VmName "protect-test-vm" -Endpoint "http://localhost:5006"
```

### Destroy.ps1
Destroys the Terraform resources with protection-aware lifecycle handling.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-protect"): Name of the VM to destroy

**Usage:**
```powershell
# Destroy with defaults
.\Destroy.ps1

# Destroy with specific parameters
.\Destroy.ps1 -VmName "protect-test-vm" -Endpoint "http://localhost:5006"
```

## Configuration

The demo configures two disks:
- **OS Disk**: Regular disk with `delete_disks = true` in lifecycle
- **Data Disk**: Protected disk with `protect = true`

The presence of any protected disk should override the global `delete_disks = true` setting and preserve all disks.

## What It Tests

- Protected disk configuration is accepted
- Protection flag overrides deletion policies
- All disks are preserved when protection is enabled
- Current provider behavior: protected disks force `deleteDisks=false` globally
- State consistency with protection settings

## Notes

- **Provider Behavior**: Currently, any protected disk prevents deletion of ALL disks
- Tests the interaction between `protect` flag and `vm_lifecycle.delete_disks`
- Useful for scenarios requiring disk preservation despite global deletion settings

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Support for `protect` flag in disk configuration
- Provider that honors protection settings during destroy operations