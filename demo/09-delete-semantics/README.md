# Demo 09: Delete Semantics

This demo tests VM deletion semantics, specifically verifying that associated VHDX disks are properly removed when a VM is destroyed.

## Purpose

Tests the following deletion behaviors:
- VM removal from Hyper-V
- Automatic cleanup of associated VHDX files
- Verification that disk files no longer exist after destroy
- Proper resource cleanup on Terraform destroy

## Scripts

### Run.ps1
Creates a simple VM with an OS disk using Terraform.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-delete"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "delete-test-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Tests VM creation and deletion semantics, verifying that VHDX files are removed after destroy.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-delete"

# Test with custom endpoint and verbose logging
.\Test.ps1 -VmName "delete-test-vm" -Endpoint "http://localhost:5006" -VerboseHttp
```

### Destroy.ps1
Destroys the Terraform resources created by the demo.

**Parameters:**
- `Endpoint` (string): API server endpoint URL
- `VmName` (string): Name of the VM to destroy
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Destroy with specific parameters
.\Destroy.ps1 -VmName "user-tfv2-delete" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo creates a minimal VM configuration:
- 1 CPU core
- 2GB RAM
- 10GB OS disk (automatically planned path)
- VM starts in stopped state

## What It Tests

- VM creation with automatic disk path planning
- Successful VM destruction via Terraform
- Verification that VHDX disk files are removed from filesystem
- Proper cleanup of all associated resources
- API correctly reports VM removal

## Notes

- This demo specifically tests that the provider removes VHDX files during destroy
- The test verifies filesystem cleanup after Terraform destroy completes
- Useful for validating resource lifecycle management

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Write permissions to VHDX storage locations
- Policy allowing automatic disk path planning