# Auth Prod Impersonate Example

This example demonstrates **impersonation authentication** for the Hyper-V Management API v2. It tests running Terraform under different Windows user accounts to verify that authentication works correctly for various users.

## Prerequisites

- Hyper-V Management API v2 running in Production mode
- Windows user account with appropriate permissions
- User must be a member of the `HG_HV_Users` group (or equivalent policy group)

## Scripts

### Run.ps1

Runs Terraform under impersonation using the specified Windows credentials.

**Required Parameters:**
- `-Username <string>`: Windows username (DOMAIN\user or user@domain format)
- `-Password <string>`: Password for the specified user

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-Environment <string>`: API environment - 'Testing' or 'Production' (default: 'Production')
- `-StartApi`: Start the API server before running
- `-BuildProvider`: Build the provider binary before running
- `-VerboseHttp`: Enable verbose HTTP logging

**Example:**
```powershell
.\Run.ps1 -Username "DOMAIN\testuser" -Password "MyPassword123!" -StartApi -BuildProvider
```

### Test.ps1

Tests both PowerShell API access and Terraform provider functionality under impersonation.

**Required Parameters:**
- `-Username <string>`: Windows username (DOMAIN\user or user@domain format)
- `-Password <string>`: Password for the specified user

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-StartApi`: Start the API server before testing
- `-BuildProvider`: Build the provider binary before testing
- `-RequireProvider`: Run full Terraform provider test (may require additional setup)

**Example:**
```powershell
.\Test.ps1 -Username "testuser" -Password "MyPassword123!" -StartApi -RequireProvider
```

## What It Tests

1. **PowerShell Impersonation**: Verifies that `Invoke-RestMethod -UseDefaultCredentials` works under different user accounts
2. **API Authentication**: Confirms the API correctly identifies and authorizes different users
3. **Terraform Provider**: Tests that the provider can authenticate when running as different users

## Notes

- The full Terraform provider test under impersonation requires the specified user to have access to terraform binaries and configuration files
- For basic testing, the PowerShell probe is sufficient to verify authentication works
- User accounts must be members of appropriate Hyper-V policy groups to access VM management functions</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\examples\auth-prod-impersonate\README.md