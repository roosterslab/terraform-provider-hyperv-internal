# Demo 11: VM Plan Preflight

This demo tests VM planning and preflight checks, specifically validating disk path planning before VM creation.

## Purpose

Tests the following planning features:
- Disk path planning resolution before VM creation
- Preflight validation of VM configuration
- Automatic disk path assignment based on policies
- Verification that planned paths are correctly used

## Scripts

### Run.ps1
Creates a VM with pre-planned disk paths using Terraform.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-vmplan"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "plan-test-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Tests VM creation with preflight planning and validates that planned disk paths are correctly used.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-vmplan"

# Test with custom endpoint and verbose logging
.\Test.ps1 -VmName "plan-test-vm" -Endpoint "http://localhost:5006" -VerboseHttp
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
.\Destroy.ps1 -VmName "user-tfv2-vmplan" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo uses disk planning for preflight validation:
- `disk_plan` data source resolves OS disk path before VM creation
- 25GB OS disk with automatic path planning
- VM configuration uses the pre-planned disk path
- Validates that planning and execution are consistent

## What It Tests

- Disk path planning works correctly
- Planned paths are properly used in VM creation
- State consistency between planning and execution
- Preflight validation prevents invalid configurations
- API correctly reports VM with planned disk paths

## Notes

- Demonstrates the importance of planning phase in Terraform
- Tests that `disk_plan` data source provides valid paths
- Useful for validating policy compliance before resource creation

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Policy configuration allowing automatic disk path planning
- Sufficient disk space for 25GB VHDX creation