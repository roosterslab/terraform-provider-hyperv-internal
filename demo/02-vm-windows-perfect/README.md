# Demo 01: Simple VM New Auto

This demo creates a basic Hyper-V VM with automatic disk path planning and allocation.

## Purpose

- Demonstrate automatic VHDX path generation based on policy
- Show VM creation with minimal configuration
- Test disk planning data source integration

## Scripts

### Run.ps1

Creates a VM with automatic disk planning.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-demo`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Run.ps1 -VmName "my-test-vm" -BuildProvider
```

### Test.ps1

Tests VM creation with validation of disk paths and policy compliance.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-demo`)
- `-BuildProvider`: Build the provider binary before testing
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Test.ps1 -VmName "test-vm-01" -VerboseHttp
```

### Destroy.ps1

Destroys the VM and cleans up resources.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name of the VM to destroy (default: `user-tfv2-demo`)

**Example:**
```powershell
.\Destroy.ps1 -VmName "my-test-vm"
```

## Configuration

- **CPU**: 2 cores
- **Memory**: 2GB
- **Power State**: Stopped
- **Disk**: 40GB OS disk with policy-compliant path

## Output

- `os_disk_path`: Automatically planned VHDX path based on policy

## Notes

- VM name must comply with policy naming rules
- Disk path is automatically determined by policy configuration
- VM is created in stopped state for safety</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\01-simple-vm-new-auto\README.md