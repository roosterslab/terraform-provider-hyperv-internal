# Demo 02: VM Windows Perfect

This demo creates a fully configured Windows VM with comprehensive settings, policy enforcement, and validation.

## Purpose

- Demonstrate complete Windows VM configuration
- Test policy path enforcement
- Show advanced VM settings and validation

## Scripts

### Run.ps1

Creates a fully configured Windows VM.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-win-perfect`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Run.ps1 -VmName "perfect-windows-vm" -BuildProvider
```

### Test.ps1

Tests the Windows VM with comprehensive validation.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-win-perfect`)
- `-BuildProvider`: Build the provider binary before testing
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Test.ps1 -VmName "test-perfect-vm" -VerboseHttp
```

### Destroy.ps1

Destroys the Windows VM and cleans up resources.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name of the VM to destroy (default: `user-tfv2-win-perfect`)

**Example:**
```powershell
.\Destroy.ps1 -VmName "perfect-windows-vm"
```

## Configuration

- **CPU**: 2 cores
- **Memory**: 4GB
- **Generation**: 2 (UEFI)
- **Secure Boot**: Enabled
- **Power State**: Stopped
- **Disk**: 50GB OS disk with policy-compliant path
- **Policy Enforcement**: Strict path validation enabled

## Features Tested

- Policy-aware disk path planning
- VM generation 2 configuration
- Secure boot settings
- Memory and CPU allocation
- Path validation enforcement

## Notes

- Requires Windows base VHDX template
- Policy paths are strictly enforced
- Comprehensive validation of VM configuration</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\02-vm-windows-perfect\README.md