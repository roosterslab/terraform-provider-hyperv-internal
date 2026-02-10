# Testing Execution Guide — Terraform Provider HyperV API v2

**Purpose**: Complete guide for executing provider tests using demo scenarios as integration tests

---

## Test Execution System Overview

### Demo-as-Test Pattern

Each demo under `demo/<scenario>/` serves as both:
1. **Documentation**: Shows how to use features
2. **Integration Test**: Validates provider + API work together

### Demo Structure (Standard Pattern)

```
demo/<scenario>/
├── main.tf           # Terraform configuration
├── Run.ps1          # Build provider + init + apply
├── Test.ps1         # Validate outputs + API state + cleanup
├── Destroy.ps1      # Terraform destroy
└── README.md        # Scenario description (optional)
```

---

## Available Test Scenarios

### Core Functionality Tests

| Scenario | Directory | Tests |
|----------|-----------|-------|
| **Identity & Policy** | `00-whoami-and-policy/` | Data sources: whoami, policy effective |
| **Basic VM** | `01-simple-vm-new-auto/` | VM creation, auto disk path, basic lifecycle |
| **Windows Perfect** | `02-vm-windows-perfect/` | Full Windows VM config (firmware, security, TPM) |
| **Switch Integration** | `03-vm-with-switch/` | VM with network switch |
| **Path Validation** | `04-path-validate-negative/` | Policy enforcement (negative test) |
| **Generation 1 VM** | `05-vm-gen1/` | Gen 1 VM support |
| **Idempotency** | `06-vm-idempotency/` | No-op applies |
| **Disk Scenarios** | `07-disk-scenarios/` | Multiple disk types |
| **Firmware & Security** | `08-firmware-security/` | Secure boot, TPM, encryption |
| **Delete Semantics** | `09-delete-semantics/` | Delete behavior validation |
| **Power Management** | `10-power-stop-timeouts/` | Stop methods, timeouts |
| **VM Planning** | `11-vm-plan-preflight/` | vm_plan data source |
| **Name Policy** | `12-negative-name-policy/` | Name pattern enforcement |
| **Unified Disk (New)** | `13-disk-unified-new-auto/` | New disk with auto path |
| **Delete Semantics v2** | `14-delete-semantics/` | Updated delete tests |
| **Protect Flag** | `15-protect-vs-delete/` | Disk protect flag |
| **Windows + Copy VHD** | `16_windows_perfect_with_copy_vhdx/` | Clone VHD scenario |

### Authentication Tests

| Scenario | Directory | Tests |
|----------|-----------|-------|
| **Current User SSPI** | `17-who-am-i-current-user-sspi/` | Windows Integrated Auth (current user) |
| **Impersonation** | `18-who-am-i-impersonation/` | Auth with explicit credentials |
| **Raw NTLM** | `19-who-am-i-raw-ntlm/` | NTLM authentication |

---

## Quick Start: Run Single Demo

### Prerequisites

1. **API Server Running**
   ```powershell
   # Start API for demos (default: http://localhost:5006)
   pwsh -File terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1 -Action start
   
   # Or custom port/environment
   pwsh -File terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1 `
     -Action start `
     -ApiUrl "http://localhost:5000" `
     -Environment Testing
   ```

2. **Go Installed** (1.21+)
   ```powershell
   go version
   ```

3. **Terraform Installed** (1.5+)
   ```powershell
   terraform version
   ```

### Run Demo Pattern

```powershell
cd terraform-provider-hypervapi-v2/demo/01-simple-vm-new-auto

# Step 1: Build provider + apply
pwsh -File Run.ps1 -BuildProvider

# Step 2: Validate (runs full test cycle: apply → verify → destroy)
pwsh -File Test.ps1 -VmName "user-tfv2-demo"

# Or manual destroy only
pwsh -File Destroy.ps1
```

### Run.ps1 Parameters

```powershell
.\Run.ps1 [OPTIONS]

Options:
  -Endpoint <url>          # API endpoint (default: http://localhost:5006)
  -VmName <name>          # VM name for test (default: "user-tfv2-demo")
  -BuildProvider          # Build provider binary first
  -VerboseHttp            # Enable TF_LOG=DEBUG for HTTP tracing
  -TfLogPath <path>       # Write logs to file
```

**Example**:
```powershell
.\Run.ps1 -Endpoint "http://localhost:5000" `
          -VmName "user-test-vm-001" `
          -BuildProvider `
          -VerboseHttp
```

### Test.ps1 Parameters

```powershell
.\Test.ps1 [OPTIONS]

Options:
  -Endpoint <url>          # API endpoint
  -VmName <name>          # VM name (REQUIRED)
  -Strict                 # Fail on warnings (default: warnings only)
  -BuildProvider          # Build provider before testing
  -VerboseHttp            # Enable debug logging
  -TfLogPath <path>       # Log file path
```

**Example**:
```powershell
.\Test.ps1 -VmName "user-test-vm-001" `
           -Endpoint "http://localhost:5000" `
           -Strict `
           -BuildProvider
```

### What Test.ps1 Does

1. **Invokes Run.ps1** → Creates resources
2. **Validates Terraform Outputs** → Checks expected values
3. **Probes API** → `GET /api/v2/vms/{name}` to verify VM exists
4. **Filesystem Checks** → Verifies VHDX files created
5. **Policy Validation** → Calls `/policy/validate-path` for disk paths
6. **Invokes Destroy.ps1** → Cleans up resources
7. **Verifies Cleanup** → Confirms VM removed, disks deleted (if expected)

**Exit Codes**:
- `0` = All checks passed
- `1` = One or more failures

---

## Run All Demos (Full Test Suite)

### Sequential Execution

```powershell
cd terraform-provider-hypervapi-v2/demo

# Simple loop through all demos
$demos = Get-ChildItem -Directory | Sort-Object Name
foreach ($demo in $demos) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running: $($demo.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Push-Location $demo.FullName
    
    # Build once on first demo
    if ($demo.Name -eq '00-whoami-and-policy') {
        & ./Run.ps1 -BuildProvider
    } else {
        & ./Run.ps1
    }
    
    # Run full test cycle for select demos
    if ($demo.Name -match '^(01|02|13|14|15)-') {
        & ./Test.ps1 -VmName "user-test-$($demo.Name)"
    } else {
        & ./Destroy.ps1
    }
    
    Pop-Location
}
```

### Parallel Execution (Advanced)

```powershell
# NOT RECOMMENDED: Requires isolated VM names + API concurrency handling
# Better to run sequentially to avoid resource conflicts
```

---

## API Server Management

### Start API for Testing

**Option 1: Helper Script (Recommended)**
```powershell
cd terraform-provider-hypervapi-v2

# Default (Testing env, port 5006)
pwsh scripts/Run-ApiForExample.ps1 -Action start

# Custom settings
pwsh scripts/Run-ApiForExample.ps1 `
  -Action start `
  -ApiUrl "http://localhost:5000" `
  -Environment Production
```

**What it does**:
- Builds API solution (`dotnet build`)
- Checks if port is already in use
- Starts API in new PowerShell window
- Waits for health check (`GET /api/v2/vms`)
- Saves PID to `.api.pid` for cleanup

**Option 2: Manual**
```powershell
cd hyperv-mgmt-api-v2
$env:ASPNETCORE_ENVIRONMENT = "Testing"
$env:ASPNETCORE_URLS = "http://localhost:5006"
dotnet run --no-launch-profile --urls "http://localhost:5006"
```

### Stop API

```powershell
cd terraform-provider-hypervapi-v2
pwsh scripts/Run-ApiForExample.ps1 -Action stop
```

---

## Test Workflow Examples

### Example 1: Quick Single Demo Test

```powershell
# Start API
cd terraform-provider-hypervapi-v2
pwsh scripts/Run-ApiForExample.ps1 -Action start

# Run basic VM test
cd demo/01-simple-vm-new-auto
pwsh Test.ps1 -VmName "user-quick-test" -BuildProvider

# Stop API
cd ../..
pwsh scripts/Run-ApiForExample.ps1 -Action stop
```

**Expected Output**:
```
[INFO ] Running demo apply: endpoint=http://localhost:5006 vm=user-quick-test
[ OK  ] Demo apply completed
[INFO ] Reading terraform outputs
[ OK  ] terraform output os_disk_path: C:\HyperV\VHDX\Users\user-quick-test\os.vhdx
[INFO ] GET http://localhost:5006/api/v2/vms/user-quick-test
[ OK  ] API VM found: name=user-quick-test state=Off
[ OK  ] VHDX exists: C:\HyperV\VHDX\Users\user-quick-test\os.vhdx
[ OK  ] Policy allows path (root=C:\HyperV\VHDX\Users)
[INFO ] Running demo destroy: endpoint=http://localhost:5006 vm=user-quick-test
[ OK  ] Demo destroy completed
[ OK  ] API indicates VM not found (as expected)
[ OK  ] VHDX removed: C:\HyperV\VHDX\Users\user-quick-test\os.vhdx
[ OK  ] Test PASSED
```

---

### Example 2: Debug Failed Test

```powershell
cd demo/04-path-validate-negative

# Run with verbose HTTP logs
pwsh Run.ps1 -VmName "test-bad-path" `
             -BuildProvider `
             -VerboseHttp `
             -TfLogPath "./terraform.log"

# Check logs
Get-Content ./terraform.log | Select-String "http.response"

# Manual cleanup if needed
pwsh Destroy.ps1 -VmName "test-bad-path"
```

---

### Example 3: Test Specific Disk Scenario

```powershell
cd demo/13-disk-unified-new-auto

# Run with strict mode (fail on warnings)
pwsh Test.ps1 -VmName "user-disk-test" `
              -BuildProvider `
              -Strict
```

---

### Example 4: Authentication Tests

```powershell
# Test current user Windows auth
cd demo/17-who-am-i-current-user-sspi
pwsh Run.ps1 -BuildProvider

# Check whoami output
terraform output -json

# Test with impersonation (requires credentials)
cd ../18-who-am-i-impersonation
# Edit main.tf to set username/password variables
pwsh Run.ps1 -BuildProvider
```

---

## Test Validation Checklist

Each test validates:

### ✅ Terraform State
- [ ] Outputs contain expected values
- [ ] State file has correct resource IDs
- [ ] No drift on refresh

### ✅ API State
- [ ] `GET /api/v2/vms/{name}` returns VM
- [ ] VM name matches
- [ ] VM state is expected (Off/Running)

### ✅ Filesystem
- [ ] VHDX files created at expected paths
- [ ] Paths comply with policy
- [ ] Files removed after destroy (if `delete_disks=true`)

### ✅ Policy Enforcement
- [ ] `/policy/validate-path` confirms allowed paths
- [ ] Policy violations fail plan (if `enforce_policy_paths=true`)
- [ ] Warnings escalate in strict mode

### ✅ Cleanup
- [ ] VM removed after destroy
- [ ] Disks deleted appropriately
- [ ] No orphaned resources

---

## Troubleshooting

### Test Fails: "API probe failed"

**Cause**: API not running or wrong endpoint

**Fix**:
```powershell
# Verify API is running
Invoke-RestMethod http://localhost:5006/api/v2/vms

# Restart API
pwsh scripts/Run-ApiForExample.ps1 -Action stop
pwsh scripts/Run-ApiForExample.ps1 -Action start
```

---

### Test Fails: "VM still present after destroy"

**Cause**: Delete failed or VM recreated

**Fix**:
```powershell
# Manual cleanup via API
$vmName = "user-test-vm"
Invoke-RestMethod -Method Post `
  -Uri "http://localhost:5006/api/v2/vms/$vmName`:delete-prepare"

# Then delete with token (check API response for token)
```

---

### Test Fails: "VHDX still exists after destroy"

**Cause**: `delete_disks=false` in lifecycle or disk is protected

**Fix**:
- Check `main.tf` for `lifecycle { delete_disks = false }`
- Check disk block for `protect = true`
- Manual cleanup: `Remove-Item "path\to\disk.vhdx" -Force`

---

### Build Fails: "go build error"

**Cause**: Missing dependencies or Go version mismatch

**Fix**:
```powershell
cd terraform-provider-hypervapi-v2

# Update modules
go mod tidy

# Rebuild
go build -o bin/terraform-provider-hypervapiv2.exe
```

---

## Advanced: Idempotency Testing

Some demos include explicit idempotency checks:

```powershell
cd demo/06-vm-idempotency

# Apply once
pwsh Run.ps1 -BuildProvider -VmName "user-idem-test"

# Apply again (should be no-op)
terraform apply -auto-approve

# Check exit code
terraform plan -detailed-exitcode
# Exit code 0 = no changes (pass)
# Exit code 1 = errors
# Exit code 2 = changes required (fail - not idempotent)
```

---

## CI/CD Integration Pattern

```powershell
# .github/workflows/provider-tests.yml equivalent

# 1. Setup
go mod download
go build -o bin/terraform-provider-hypervapiv2.exe

# 2. Start API
pwsh scripts/Run-ApiForExample.ps1 -Action start -ApiUrl "http://localhost:5000"

# 3. Run critical demos
$criticalDemos = @(
    "01-simple-vm-new-auto",
    "02-vm-windows-perfect",
    "13-disk-unified-new-auto"
)

foreach ($demo in $criticalDemos) {
    cd "demo/$demo"
    pwsh Test.ps1 -VmName "ci-test-$demo" -Strict
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Demo $demo failed"
        exit 1
    }
}

# 4. Cleanup
pwsh scripts/Run-ApiForExample.ps1 -Action stop
```

---

## Test Coverage Matrix

| Feature | Tested By | Status |
|---------|-----------|--------|
| **VM Creation** | 01, 02, 13 | ✅ |
| **Disk Auto Path** | 01, 13 | ✅ |
| **Disk Custom Path** | 07 | ✅ |
| **Clone VHD** | 16 | ✅ |
| **Network Switch** | 03 | ✅ |
| **Firmware (Secure Boot)** | 02, 08 | ✅ |
| **Security (TPM)** | 02, 08 | ✅ |
| **Power Management** | 10 | ✅ |
| **Delete Semantics** | 09, 14 | ✅ |
| **Protect Flag** | 15 | ✅ |
| **Policy Enforcement** | 04, 12 | ✅ |
| **RBAC/Identity** | 00, 17, 18, 19 | ✅ |
| **Idempotency** | 06 | ✅ |
| **VM Planning** | 11 | ⚠️ Needs API endpoint |

---

## Summary: Core Commands

```powershell
# Start API
pwsh scripts/Run-ApiForExample.ps1 -Action start

# Run single test
cd demo/<scenario>
pwsh Test.ps1 -VmName "user-test" -BuildProvider

# Run with debugging
pwsh Test.ps1 -VmName "user-test" -VerboseHttp -Strict

# Stop API
pwsh scripts/Run-ApiForExample.ps1 -Action stop
```

**Key Points**:
- ✅ Always start API first
- ✅ Use `-BuildProvider` on first run or after code changes
- ✅ Use `-Strict` for production-quality validation
- ✅ Check `Test.ps1` exit code (0 = pass, 1 = fail)
- ✅ Each test is self-contained (creates + verifies + destroys)

