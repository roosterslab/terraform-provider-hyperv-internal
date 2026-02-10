# Demo 16: Windows Perfect with Copy VHDX

This demo creates a comprehensive "perfect" Windows VM configuration with cloning from base VHDX, policy validation, security features, and complete lifecycle management.

## Purpose

Tests the following comprehensive features:
- Complete Windows VM configuration with Generation 2
- VHDX cloning from base template
- Policy validation and path validation
- Secure boot with Windows template
- TPM (Trusted Platform Module) enablement
- Network switch attachment
- Unified disk syntax with custom controller/LUN
- Explicit lifecycle management with disk deletion
- Comprehensive state and API validation

## Scripts

### Run.ps1
Creates a complete Windows VM with all advanced features.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-win-copy"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BaseVhdxPath` (string, default: "C:/HyperV/VHDX/Users/templates/windows-base.vhdx"): Path to base VHDX for cloning
- `SetupApi` (switch): Setup API environment (JEA + policy pack + restart)
- `Username` (string): Username for authentication
- `Password` (string): Password for authentication

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and base VHDX
.\Run.ps1 -VmName "perfect-windows-vm" -BaseVhdxPath "C:/Templates/win11-base.vhdx"

# Setup API environment and build provider
.\Run.ps1 -SetupApi -BuildProvider -VerboseHttp

# With explicit credentials
.\Run.ps1 -Username "domain\user" -Password "secret"
```

### Test.ps1
Runs comprehensive validation of the perfect Windows VM configuration.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `Strict` (switch): Enable strict validation (warnings become failures)
- `BuildProvider` (switch): Build the Terraform provider before testing
- `BaseVhdxPath` (string, default: "C:/HyperV/Templates/windows-base.vhdx"): Path to base VHDX
- `Username` (string): Username for authentication
- `Password` (string): Password for authentication

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-win-copy"

# Strict testing with custom base VHDX
.\Test.ps1 -VmName "perfect-windows-vm" -BaseVhdxPath "C:/Templates/win11-base.vhdx" -Strict

# Test with verbose logging
.\Test.ps1 -VmName "test-vm" -VerboseHttp -TfLogPath "C:\Logs\terraform.log"
```

### Destroy.ps1
Destroys the comprehensive Windows VM and cleans up resources.

**Parameters:**
- `Endpoint` (string): API server endpoint URL
- `VmName` (string): Name of the VM to destroy
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Destroy with specific parameters
.\Destroy.ps1 -VmName "user-tfv2-win-copy" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo creates a complete Windows VM with:
- **Hardware**: 4 CPUs, 4GB RAM, Generation 2
- **Disk**: Cloned from base VHDX, SCSI controller LUN 0, boot disk
- **Network**: Attached to "Default Switch"
- **Security**: Secure boot (Microsoft Windows), TPM enabled, encryption disabled
- **Lifecycle**: Graceful stop with 120s timeout, delete_disks = true
- **Policy**: Path validation and policy compliance checking

## Data Sources Used

- `hypervapiv2_policy`: Retrieves current policy configuration
- `hypervapiv2_disk_plan`: Plans disk path for cloning operation
- `hypervapiv2_path_validate`: Validates planned path compliance

## What It Tests

- Complete VM lifecycle from planning to destruction
- Policy compliance and path validation
- Security feature configuration (secure boot, TPM)
- Disk cloning and lifecycle management
- Network configuration and switch attachment
- State consistency and API validation
- Comprehensive output validation

## Notes

- **Most Comprehensive Demo**: This demo exercises all major features
- **API Setup**: Use `-SetupApi` to automatically configure JEA and policy packs
- **Base VHDX**: Auto-created if missing, or provide custom path
- **Credentials**: Supports both negotiate (SSPI) and explicit username/password auth

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication or explicit credentials
- Base VHDX template (auto-created if missing)
- "Default Switch" virtual switch configured
- Policy configuration allowing VHDX operations
- TPM-capable host system for TPM functionality