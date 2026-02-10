# Demo 10: Power Stop Timeouts

This demo tests VM power management settings including stop methods and timeout configurations for graceful shutdowns.

## Purpose

Tests the following power management features:
- Graceful stop method configuration
- Wait timeout settings for VM shutdown
- Power state management during VM lifecycle
- Timeout handling for long-running shutdown operations

## Scripts

### Run.ps1
Creates a VM with power management settings using Terraform.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, default: "user-tfv2-power"): Name of the VM to create
- `BuildProvider` (switch): Build the Terraform provider before running
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Basic run with defaults
.\Run.ps1

# Custom VM name and endpoint
.\Run.ps1 -VmName "power-test-vm" -Endpoint "http://localhost:5006"

# Build provider and enable verbose logging
.\Run.ps1 -BuildProvider -VerboseHttp
```

### Test.ps1
Tests VM creation with power management settings and verifies basic lifecycle operations.

**Parameters:**
- `Endpoint` (string, default: 'http://localhost:5006'): API server endpoint URL
- `VmName` (string, mandatory): Name of the VM to test
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output
- `BuildProvider` (switch): Build the Terraform provider before testing

**Usage:**
```powershell
# Test with specific VM
.\Test.ps1 -VmName "user-tfv2-power"

# Test with custom endpoint and verbose logging
.\Test.ps1 -VmName "power-test-vm" -Endpoint "http://localhost:5006" -VerboseHttp
```

### Destroy.ps1
Destroys the Terraform resources created by the demo.

**Parameters:**
- `Endpoint` (string): API server endpoint URL
- `VmName` (string): Name of the VM to destroy
- `VerboseHttp` (switch): Enable verbose HTTP logging
- `TfLogPath` (string): Path for Terraform log output

**Usage:**
```powershell
# Destroy with specific parameters
.\Destroy.ps1 -VmName "user-tfv2-power" -Endpoint "http://localhost:5006"

# Destroy with verbose logging
.\Destroy.ps1 -VerboseHttp
```

## Configuration

The demo configures the following power settings:
- `stop_method`: "graceful" (attempts clean shutdown first)
- `wait_timeout_seconds`: 120 (2 minutes timeout for shutdown operations)
- VM starts in "stopped" power state

## What It Tests

- Power management configuration acceptance
- Basic VM lifecycle with power settings
- State persistence of power configuration
- Proper resource cleanup on destroy

## Notes

- **Provider v2 Status**: Stop method and timeout settings are configured in Terraform but may not be fully implemented in the current provider version
- The demo validates that the configuration is accepted and basic VM operations work
- Useful for testing future power management enhancements

## Prerequisites

- Hyper-V Management API v2 server running in Production mode
- Windows Integrated Authentication configured
- Policy allowing VM creation with power management settings