# Demo 07: Disk Scenarios

This demo showcases various disk management scenarios including automatic disk planning, cloning from base VHDX files, and attaching existing VHDX files to VMs.

## Purpose

Tests the following disk operations:
- Automatic disk path planning for new VMs
- Cloning from a base VHDX template
- Attaching existing VHDX files as OS disks
- Disk policy validation and enforcement

## Scripts

### Run.ps1
Creates a VM with disk scenarios using Terraform.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-disk-scen"): Name of the VM to create
- `BaseVhdxPath` (string, default: 'C:/HyperV/VHDX/Users/templates/windows-base.vhdx'): Path to base VHDX for cloning
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "my-test-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Runs comprehensive tests on the disk scenarios including API validation and state verification.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-disk-scen"

# Test with custom endpoint and verbose logging
.\Test.ps1 -VmName "my-test-vm" -Endpoint "http://localhost:5006" -VerboseHttp
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
.\Destroy.ps1 -VmName "user-tfv2-disk-scen" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo uses the following Terraform variables:
- `endpoint`: API server URL
- `vm_name`: VM name for the primary scenario
- `base_vhdx_path`: Path to base VHDX for cloning (auto-created if doesn't exist)
- `attach_vm_name`: Optional VM name for attach scenario
- `attach_source_path`: Optional path to existing VHDX for attach scenario

## Scenarios Tested

1. **Clone Auto**: Automatic path planning for cloning from base VHDX
2. **Attach Existing** (optional): Attaching existing VHDX as OS disk to a separate VM

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Policy configuration allowing VHDX paths
- Base VHDX template (auto-created if missing)
- Windows Integrated Authentication configured</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\06-vm-idempotency\README.md