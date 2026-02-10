# Demo 00: WhoAmI and Policy

This demo demonstrates the `hypervapiv2_whoami` and `hypervapiv2_policy` data sources, showing current user identity and effective policy configuration.

## Purpose

- Test authentication and identity retrieval
- Display effective policy roots and settings
- Verify API connectivity and authorization

## Scripts

### Run.ps1

Runs the Terraform configuration to retrieve identity and policy information.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BuildProvider`: Build the provider binary before running

**Example:**
```powershell
.\Run.ps1 -BuildProvider
```

### Test.ps1

Tests the identity and policy data sources with validation.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BuildProvider`: Build the provider binary before testing

**Example:**
```powershell
.\Test.ps1 -BuildProvider
```

### Destroy.ps1

Cleans up Terraform state.

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)

**Example:**
```powershell
.\Destroy.ps1
```

## Output

- `user`: Current authenticated username
- `domain`: User domain
- `roots`: Effective policy VHDX root paths

## Notes

- Requires API running in Production mode for authentication
- No resources are created - only data sources are queried</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\00-whoami-and-policy\README.md