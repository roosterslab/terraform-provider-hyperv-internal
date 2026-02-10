# Demo 08: Firmware Security

This demo tests VM firmware security features including secure boot and TPM (Trusted Platform Module) configuration.

## Purpose

Tests the following security features:
- Secure boot enablement with Microsoft Windows template
- TPM (Trusted Platform Module) activation
- Firmware security settings validation
- State verification of security configurations

## Scripts

### Run.ps1
Creates a VM with firmware security settings using Terraform.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-firmware"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "secure-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Runs comprehensive tests on firmware security settings including state validation and API verification.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-firmware"

# Test with custom endpoint and verbose logging
.\Test.ps1 -VmName "secure-vm" -Endpoint "http://localhost:5006" -VerboseHttp
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
.\Destroy.ps1 -VmName "user-tfv2-firmware" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo configures the following security settings:
- `firmware.secure_boot`: Enabled (true)
- `firmware.secure_boot_template`: "MicrosoftWindows"
- `security.tpm`: Enabled (true)
- `security.encrypt`: Disabled (false)

## What It Tests

- Firmware security settings are properly applied
- Secure boot configuration with Windows template
- TPM enablement for enhanced security
- State persistence of security configurations
- API correctly reports security settings

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- TPM-capable host system (for TPM functionality)
- Generation 2 VM support (required for secure boot)