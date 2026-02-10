# Windows OS Demo Example

This example demonstrates creating and managing a Windows VM using the Hyper-V Management API v2. It creates a VM with a Windows OS disk, configures it, and provides options for testing and cleanup.

## Prerequisites

- Hyper-V Management API v2 running in Production mode
- Windows base VHDX template at `C:/HyperV/VHDX/Users/templates/windows-base.vhdx` (or custom path)
- Current user must have Hyper-V permissions and be in appropriate policy groups
- Sufficient disk space for VM creation

## Scripts

### Run.ps1

Creates and starts a Windows VM using Terraform.

**Required Parameters:**
- `-VmName <string>`: Name for the virtual machine

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BaseVhdxPath <string>`: Path to Windows base VHDX template (default: `C:/HyperV/VHDX/Users/templates/windows-base.vhdx`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Run.ps1 -VmName "my-windows-vm" -BuildProvider -VerboseHttp
```

### Test.ps1

Runs comprehensive tests on the Windows VM including creation, validation, and cleanup.

**Required Parameters:**
- `-VmName <string>`: Name for the virtual machine

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BaseVhdxPath <string>`: Path to Windows base VHDX template (default: `C:/HyperV/VHDX/Users/templates/windows-base.vhdx`)
- `-BuildProvider`: Build the provider binary before testing
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output
- `-Strict`: Enable strict validation (fail on warnings)

**Example:**
```powershell
.\Test.ps1 -VmName "test-windows-vm" -Strict -VerboseHttp
```

### Destroy.ps1

Destroys the specified Windows VM and cleans up resources.

**Required Parameters:**
- `-VmName <string>`: Name of the virtual machine to destroy

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Destroy.ps1 -VmName "my-windows-vm"
```

## What It Does

1. **VM Creation**: Creates a new Hyper-V VM with the specified name
2. **Disk Setup**: Copies and attaches the Windows base VHDX template
3. **Configuration**: Sets up VM with appropriate CPU, memory, and network settings
4. **Validation**: Tests VM state, disk paths, and policy compliance
5. **Cleanup**: Provides options to destroy VM and remove associated disks

## Configuration

The VM is configured with:
- 2 vCPUs
- 4096 MB RAM
- Generation 2 (UEFI)
- Secure boot enabled
- Dynamic memory disabled
- Automatic start/stop actions

## Notes

- VM names must comply with policy restrictions (typically prefixed with allowed patterns)
- The base VHDX template must exist and be accessible
- VMs are created in "stopped" state by default
- Use `-Strict` in Test.ps1 for comprehensive validation
- Destroy operations will remove both the VM and its virtual disks</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\examples\windows_os_demo\README.md