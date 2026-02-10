# Demo 04: Path Validate Negative

This demo tests path validation by attempting to use an invalid file extension, demonstrating policy enforcement.

## Purpose

- Test path validation with invalid extensions
- Demonstrate policy denial behavior
- Show error handling for non-compliant paths

## Scripts

### Run.ps1

Attempts to validate an invalid path (should fail).

**Optional Parameters:**
- `-Endpoint <string>`: API endpoint URL (default: `http://localhost:5006`)
- `-BuildProvider`: Build the provider binary before running

**Example:**
```powershell
.\Run.ps1 -BuildProvider
```

### Test.ps1

Tests path validation with expected failure.

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

## What It Tests

- Path validation with unsupported file extensions
- Policy enforcement for VHDX paths
- Error handling for invalid paths

## Expected Behavior

- Path validation should fail due to invalid extension
- Demonstrates policy compliance checking
- Shows proper error reporting

## Notes

- This demo is designed to fail as part of testing
- Tests the security boundary of path validation</content>
<parameter name="filePath">c:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\demo\04-path-validate-negative\README.md