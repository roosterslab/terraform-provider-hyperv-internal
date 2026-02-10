# Demo 05: VM Generation 1

This demo creates a Generation 1 (BIOS) Hyper-V VM, testing legacy VM configuration.

## Purpose

- Demonstrate Generation 1 VM creation
- Test BIOS-based virtual machines
- Show different VM generation options

## Scripts

### Run.ps1

Creates a Generation 1 VM.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-gen1`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Run.ps1 -VmName "gen1-vm" -BuildProvider
```

### Test.ps1

Tests Generation 1 VM creation and validation.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name for the VM (default: `user-tfv2-gen1`)
- `-BuildProvider`: Build the provider binary before testing
- `-VerboseHttp`: Enable verbose HTTP logging
- `-TfLogPath <string>`: Path for Terraform log output

**Example:**
```powershell
.\Test.ps1 -VmName "test-gen1-vm" -VerboseHttp
```

### Destroy.ps1

Destroys the Generation 1 VM.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-VmName <string>`: Name of the VM to destroy (default: `user-tfv2-gen1`)

**Example:**
```powershell
.\Destroy.ps1 -VmName "gen1-vm"
```

## Configuration

- **Generation**: 1 (BIOS)
- **CPU**: 2 cores
- **Memory**: 2GB
- **Secure Boot**: Not applicable (Gen 1)
- **Firmware**: BIOS

## Notes

- Generation 1 VMs use BIOS firmware
- No secure boot support
- Legacy VM configuration for compatibility testing</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\05-vm-gen1\README.md