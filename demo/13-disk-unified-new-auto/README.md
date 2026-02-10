# Demo 13: Disk Unified New Auto

This demo tests the unified disk configuration syntax with automatic path placement for new VM disks.

## Purpose

Tests the following disk features:
- Unified disk block configuration syntax
- Automatic disk path planning and placement
- Dynamic disk type creation
- Simplified disk configuration without separate path planning

## Scripts

### Run.ps1
Creates a VM using the unified disk syntax with automatic path placement.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-unified-auto"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "unified-disk-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Tests VM creation with unified disk configuration and validates automatic path placement.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-unified-auto"

# Test with custom endpoint
.\Test.ps1 -VmName "unified-disk-vm" -Endpoint "http://localhost:5006"
```

### Destroy.ps1
Destroys the Terraform resources created by the demo.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-unified-auto"): Name of the VM to destroy

**Usage:**
```powershell
# Destroy with defaults
.\Destroy.ps1

# Destroy with specific parameters
.\Destroy.ps1 -VmName "unified-disk-vm" -Endpoint "http://localhost:5006"
```

## Configuration

The demo uses unified disk syntax:
```hcl
disk {
  name    = "os"
  purpose = "os"
  boot    = true
  size    = "20GB"
  type    = "dynamic"
}
```

This replaces the older separate `new_vhd_path` and `new_vhd_size_gb` parameters with a more intuitive block syntax.

## What It Tests

- Unified disk configuration syntax works correctly
- Automatic path planning for disk placement
- Dynamic VHDX creation with specified size
- Boot disk configuration and OS purpose
- State persistence of unified disk settings

## Notes

- Demonstrates the newer, more intuitive disk configuration syntax
- Tests automatic disk path resolution by the provider
- Validates that the unified approach produces the same results as separate parameters

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Policy allowing automatic disk path planning
- Support for unified disk syntax in the provider