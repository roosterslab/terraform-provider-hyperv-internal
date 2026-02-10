# Demo 12: Negative Name Policy

This demo tests negative scenarios for VM name policy validation, ensuring that invalid VM names are properly rejected.

## Purpose

Tests the following policy enforcement:
- VM name policy validation during creation
- Rejection of non-compliant VM names
- Proper error handling for policy violations
- Prevention of invalid resource creation

## Scripts

### Run.ps1
Attempts to create a VM with an invalid name that violates naming policy.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "badname"): Invalid VM name that should be rejected
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults (expects failure)
.\Run.ps1

# Custom invalid VM name and endpoint
.\Run.ps1 -VmName "invalid-vm-name" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Tests that VM creation with invalid names is properly blocked by policy.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: 'badname'): Invalid VM name to test
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with default invalid name
.\Test.ps1

# Test with custom invalid name
.\Test.ps1 -VmName "test-bad-name" -Endpoint "http://localhost:5006"
```

### Destroy.ps1
Attempts to clean up any resources (though creation should have failed).

**Parameters:**
- `Endpoint` (string): API server endpoint URL
- `VmName` (string): Name of the VM to destroy
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Destroy with specific parameters
.\Destroy.ps1 -VmName "badname" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo intentionally uses:
- Invalid VM name: "badname" (violates typical naming policies)
- Policy enforcement enabled: `enforce_policy_paths = true`
- Disk planning that may succeed even with invalid names

## What It Tests

- Name policy validation prevents invalid VM creation
- Terraform apply fails with appropriate error codes
- Policy enforcement works at the API level
- Error handling for policy violations

## Expected Behavior

- **Run.ps1**: Should fail with exit code > 0 due to policy violation
- **Test.ps1**: Should pass if the policy correctly blocks creation
- The demo validates that security policies are enforced

## Notes

- This is a **negative test** - success means the operation correctly fails
- Useful for validating that policy enforcement prevents unauthorized actions
- Tests the security boundary of the API

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Name policy configuration that rejects names like "badname"
- Policy enforcement enabled in the provider