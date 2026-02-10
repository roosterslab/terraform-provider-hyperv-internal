# Windows OS Demo Impersonate Example

This example demonstrates creating and managing a Windows VM under **impersonation** using the Hyper-V Management API v2. It runs the entire Terraform workflow as a specified Windows user, testing authentication and authorization for different accounts.

## Prerequisites

- Hyper-V Management API v2 running in Production mode
- Windows user account with appropriate permissions
- User must be a member of the `HG_HV_Users` group (or equivalent policy group)
- Windows base VHDX template at `C:/HyperV/VHDX/Users/templates/windows-base.vhdx` (or custom path)
- Sufficient disk space for VM creation

## Scripts

### Run.ps1

Creates and starts a Windows VM using Terraform running under the specified user credentials.

**Required Parameters:**
- `-VmName <string>`: Name for the virtual machine
- `-Username <string>`: Windows username (DOMAIN\user or user@domain format)
- `-Password <string>`: Password for the specified user

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BaseVhdxPath <string>`: Path to Windows base VHDX template (default: `C:/HyperV/VHDX/Users/templates/windows-base.vhdx`)
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging

**Example:**
```powershell
.\Run.ps1 -VmName "impersonated-vm" -Username "DOMAIN\testuser" -Password "MyPassword123!" -BuildProvider
```

### Destroy.ps1

Destroys the specified Windows VM running under impersonation.

**Required Parameters:**
- `-VmName <string>`: Name of the virtual machine to destroy
- `-Username <string>`: Windows username (DOMAIN\user or user@domain format)
- `-Password <string>`: Password for the specified user

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)

**Example:**
```powershell
.\Destroy.ps1 -VmName "impersonated-vm" -Username "DOMAIN\testuser" -Password "MyPassword123!"
```

## What It Tests

1. **Impersonation Setup**: Verifies that Terraform can run under different Windows user accounts
2. **User Permissions**: Tests that the specified user has appropriate Hyper-V permissions
3. **Policy Compliance**: Ensures VM creation follows security policies for the impersonated user
4. **Resource Access**: Validates that the user can access required files and directories

## How It Works

1. **Credential Setup**: Creates PowerShell credentials for the specified user
2. **Process Impersonation**: Uses `Start-Process -Credential` to run Terraform as the target user
3. **Directory Access**: Ensures the impersonated user can access the example directory
4. **Provider Configuration**: Sets up development overrides accessible to the impersonated user
5. **Terraform Execution**: Runs init, apply, and destroy operations under the user context

## Configuration

The VM is configured identically to the non-impersonated example:
- 2 vCPUs
- 4096 MB RAM
- Generation 2 (UEFI)
- Secure boot enabled
- Dynamic memory disabled
- Automatic start/stop actions

## Notes

- The specified user must have access to terraform binaries and configuration files
- VM names must comply with policy restrictions for the impersonated user
- The base VHDX template must be accessible to the impersonated user
- This example tests both authentication and authorization for different user contexts
- Use this to verify that your security policies work correctly for various user types</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\examples\windows_os_demo_impersonate\README.md