# Demo 03: VM with Switch

This demo creates a VM with network switch configuration, testing virtual network connectivity.

## Purpose

- Demonstrate VM network configuration
- Test virtual switch attachment
- Show network settings in VM creation

## Scripts

### Run.ps1

Creates a VM with network switch configuration.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-switch`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Run.ps1 -VmName "networked-vm" -BuildProvider
```

### Test.ps1

Tests VM creation with network switch validation.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-switch`)
- `-BuildProvider`: Build the provider binary before testing
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Test.ps1 -VmName "test-network-vm" -VerboseHttp
```

### Destroy.ps1

Destroys the VM and cleans up resources.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name of the VM to destroy (default: `user-tfv2-switch`)

**Example:**
```powershell
.\Destroy.ps1 -VmName "networked-vm"
```

## Configuration

- **CPU**: 2 cores
- **Memory**: 2GB
- **Network**: Connected to virtual switch
- **Switch**: Default Switch (configurable)
- **Policy Enforcement**: Enabled

## Features Tested

- Virtual switch attachment
- Network configuration
- VM connectivity setup

## Notes

- Requires existing virtual switch
- Tests network integration with VMs</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\03-vm-with-switch\README.md