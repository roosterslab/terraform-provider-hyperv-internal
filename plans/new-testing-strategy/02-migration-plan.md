# Migration Plan — Phased Rollout

**Date**: December 3, 2025  
**Duration**: 4 weeks (~20-25 hours total)  
**Goal**: Migrate from duplicated demo scripts to DRY harness architecture

---

## Migration Phases

```
Week 1: Build Harness        Week 2: Pilot Migration     Week 3: Complete         Week 4: Polish
┌──────────────────┐         ┌──────────────────┐        ┌──────────────────┐     ┌──────────────────┐
│ HvTestHarness    │         │ Migrate 3 demos  │        │ Migrate 16 more  │     │ Contract tests   │
│ HvAssertions     │    →    │ Test & validate  │   →    │ Update CI/CD     │  →  │ Documentation    │
│ scenarios.json   │         │ Refine harness   │        │ Delete old       │     │ Final polish     │
│ run-all.ps1      │         │ (01, 04, 06)     │        │ Test.ps1 files   │     │                  │
└──────────────────┘         └──────────────────┘        └──────────────────┘     └──────────────────┘
   6 hours                      6 hours                     8 hours                  5 hours
```

---

## Phase 1: Build Harness Foundation (Week 1)

**Goal**: Create reusable test infrastructure  
**Duration**: 6 hours  
**Deliverables**: Working harness for 1 simple scenario

### Tasks

#### 1.1 Create Harness Module Structure (1 hour)

```powershell
# Create directory structure
New-Item -ItemType Directory -Path tests/harness
New-Item -ItemType Directory -Path tests/scenarios
New-Item -ItemType Directory -Path tests/scenarios/custom-validations

# Create module files
New-Item tests/harness/HvTestHarness.psm1
New-Item tests/harness/HvAssertions.psm1
New-Item tests/harness/HvApiManagement.psm1
New-Item tests/harness/HvHelpers.psm1
```

#### 1.2 Implement Core Harness (3 hours)

**File**: `tests/harness/HvTestHarness.psm1`

Key functions:
- `Invoke-HvScenario` - Main orchestrator
- `Invoke-HvStepInit` - terraform init
- `Invoke-HvStepApply` - terraform apply
- `Invoke-HvStepValidate` - Run assertions
- `Invoke-HvStepDestroy` - terraform destroy
- `Invoke-HvStepReapplyNoop` - Idempotency check

**Implementation priority**:
1. Basic lifecycle (Init, Apply, Destroy)
2. Standard validation (VM exists, disk created)
3. Result tracking (JSON output)
4. Error handling

#### 1.3 Implement Shared Assertions (1 hour)

**File**: `tests/harness/HvAssertions.psm1`

Core assertions:
```powershell
function Assert-HvVmExists {
    param([string]$Name, [string]$Endpoint)
    # GET /api/v2/vms/{name}
}

function Assert-HvVmDestroyed {
    param([string]$Name, [string]$Endpoint)
    # Expect 404
}

function Assert-HvDiskExists {
    param([string]$Path)
    # Test-Path
}

function Assert-HvPolicyAllows {
    param([string]$Path, [string]$Endpoint)
    # POST /policy/validate-path
}
```

#### 1.4 Create Test Runner (1 hour)

**File**: `tests/run-all.ps1`

```powershell
#!/usr/bin/env pwsh
param(
    [string[]]$Tags = @("critical"),
    [string]$Id,
    [switch]$AutoStartApi,
    [switch]$VerboseHttp
)

Import-Module "$PSScriptRoot/harness/HvTestHarness.psm1"

$scenariosPath = "$PSScriptRoot/scenarios/scenarios.json"
$scenarios = Get-Content $scenariosPath | ConvertFrom-Json

# Filter by tags or ID
if ($Id) {
    $filtered = $scenarios | Where-Object { $_.id -eq $Id }
} else {
    $filtered = $scenarios | Where-Object {
        $_.tags | Where-Object { $Tags -contains $_ }
    }
}

$results = @()
foreach ($scenario in $filtered) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running: $($scenario.id)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $result = Invoke-HvScenario -Scenario $scenario -AutoStartApi:$AutoStartApi
    $results += $result
    
    if ($result.status -eq "failed") {
        Write-Host "FAILED: $($scenario.id)" -ForegroundColor Red
    } else {
        Write-Host "PASSED: $($scenario.id)" -ForegroundColor Green
    }
}

# Output summary
$passed = ($results | Where-Object status -eq "passed").Count
$failed = ($results | Where-Object status -eq "failed").Count
Write-Host "`nResults: $passed passed, $failed failed" -ForegroundColor Cyan

# Save JSON report
$results | ConvertTo-Json -Depth 10 | Out-File "test-results.json"

exit $failed
```

---

## Phase 2: Pilot Migration (Week 2)

**Goal**: Migrate 3 representative demos to validate approach  
**Duration**: 6 hours  
**Demos**: 01-simple-vm-new-auto, 04-path-validate-negative, 06-vm-idempotency

### Why These 3?

1. **01-simple-vm-new-auto**: Standard happy path (baseline)
2. **04-path-validate-negative**: Negative test (expect failure)
3. **06-vm-idempotency**: Custom logic (reapply check)

### Tasks

#### 2.1 Create Scenarios Registry (1 hour)

**File**: `tests/scenarios/scenarios.json`

```json
[
  {
    "id": "01-simple-vm-new-auto",
    "path": "demos/01-simple-vm-new-auto",
    "tags": ["smoke", "critical", "vm", "disk"],
    "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
    "expectations": {
      "vmName": "user-tfv2-demo",
      "vmCount": 1,
      "diskScenario": "new-auto",
      "diskCount": 1
    }
  },
  {
    "id": "04-path-validate-negative",
    "path": "demos/04-path-validate-negative",
    "tags": ["critical", "policy", "negative"],
    "steps": ["Init", "ApplyExpectFail", "ValidateErrorMessage"],
    "expectations": {
      "expectFailure": true,
      "errorPattern": "path not allowed",
      "customValidation": "Validate-PathNegative.ps1"
    }
  },
  {
    "id": "06-vm-idempotency",
    "path": "demos/06-vm-idempotency",
    "tags": ["critical", "idempotency"],
    "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
    "expectations": {
      "vmName": "user-idem-test",
      "vmCount": 1,
      "customValidation": "Validate-Idempotency.ps1"
    }
  }
]
```

#### 2.2 Implement Custom Validations (2 hours)

**File**: `tests/scenarios/custom-validations/Validate-PathNegative.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir
)

# This scenario expects terraform apply to FAIL
# Validate error message contains policy violation

$tfOutput = Get-Content "$WorkingDir/terraform.log" -Raw
if ($tfOutput -notmatch "path not allowed") {
    throw "Expected error message 'path not allowed' not found"
}

Write-Host "✓ Error message validated" -ForegroundColor Green
```

**File**: `tests/scenarios/custom-validations/Validate-Idempotency.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir
)

# After first apply, run terraform plan and expect no changes
Push-Location $WorkingDir
try {
    terraform plan -detailed-exitcode
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "✓ Idempotency verified (no changes)" -ForegroundColor Green
    } elseif ($exitCode -eq 2) {
        throw "Idempotency FAILED: terraform plan detected changes"
    } else {
        throw "terraform plan failed with exit code $exitCode"
    }
} finally {
    Pop-Location
}
```

#### 2.3 Test and Refine (2 hours)

```powershell
# Test each pilot scenario individually
tests/run-all.ps1 -Id "01-simple-vm-new-auto" -AutoStartApi
tests/run-all.ps1 -Id "04-path-validate-negative" -AutoStartApi
tests/run-all.ps1 -Id "06-vm-idempotency" -AutoStartApi

# Test smoke tag (should run 01)
tests/run-all.ps1 -Tags smoke -AutoStartApi

# Test critical tag (should run all 3)
tests/run-all.ps1 -Tags critical -AutoStartApi
```

**Refine based on failures**:
- Adjust harness error handling
- Fix assertion logic
- Improve logging
- Handle edge cases

#### 2.4 Delete Old Scripts (1 hour)

Once validated, remove duplicated scripts:

```powershell
Remove-Item demos/01-simple-vm-new-auto/Test.ps1
Remove-Item demos/01-simple-vm-new-auto/Run.ps1
Remove-Item demos/01-simple-vm-new-auto/Destroy.ps1

# Repeat for 04, 06
```

**Keep**: `main.tf` (HCL definitions)  
**Remove**: All PowerShell scripts

---

## Phase 3: Complete Migration (Week 3)

**Goal**: Migrate remaining 16 demos  
**Duration**: 8 hours

### Tasks

#### 3.1 Add Remaining Scenarios to Registry (2 hours)

Add JSON entries for:
- 00-whoami-and-policy
- 02-vm-windows-perfect
- 03-vm-with-switch
- 05-vm-gen1
- 07-disk-scenarios
- 08-firmware-security
- 09-delete-semantics
- 10-power-stop-timeouts
- 11-vm-plan-preflight
- 12-negative-name-policy
- 13-disk-unified-new-auto
- 14-delete-semantics
- 15-protect-vs-delete
- 16_windows_perfect_with_copy_vhdx
- 17-who-am-i-current-user-sspi
- 18-who-am-i-impersonation
- 19-who-am-i-raw-ntlm

**Strategy**: Start with simple ones (00, 02, 05), then complex (16 with cloning)

#### 3.2 Create Additional Custom Validations (3 hours)

**Estimate**: ~5 demos need custom validations

Examples:
- `Validate-WindowsPerfect.ps1` - Check firmware, TPM, security settings
- `Validate-CloneVhd.ps1` - Verify clone operation completed
- `Validate-WhoAmI.ps1` - Check authentication data sources

#### 3.3 Test All Scenarios (2 hours)

```powershell
# Run full suite
tests/run-all.ps1 -Tags full -AutoStartApi

# Verify results
cat test-results.json | jq '.[] | select(.status == "failed")'
```

Fix any failures, refine harness as needed.

#### 3.4 Delete Old Scripts and Update Docs (1 hour)

```powershell
# Remove all old Test.ps1/Run.ps1/Destroy.ps1 from demos
Get-ChildItem demos -Recurse -Include Test.ps1,Run.ps1,Destroy.ps1 | Remove-Item

# Update demo READMEs to reference harness
```

Update `agent/testing-execution-guide.instructions.md`:
- Replace per-demo instructions with harness usage
- Add examples of tag-based filtering
- Document custom validation pattern

---

## Phase 4: Polish and Integration (Week 4)

**Goal**: Add contract tests, integrate CI/CD, finalize docs  
**Duration**: 5 hours

### Tasks

#### 4.1 Add Go Contract Tests (2 hours)

**File**: `tests/contract/client_test.go`

```go
package contract

import (
    "context"
    "testing"
    "github.com/stretchr/testify/assert"
    "terraform-provider-hypervapiv2/internal/client"
)

func TestClientCreateVm(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping contract test")
    }
    
    cl, err := client.New(client.Config{
        Endpoint: "http://localhost:5006",
        Auth: client.AuthConfig{Method: "none"},
    })
    assert.NoError(t, err)
    
    req := client.CreateVmRequest{
        Name: "contract-test-vm",
        Generation: 2,
        CpuCount: ptr(2),
        MemoryMB: ptr(2048),
    }
    
    resp, err := cl.CreateVm(context.Background(), req)
    assert.NoError(t, err)
    assert.NotEmpty(t, resp.VmId)
    
    // Cleanup
    defer cl.DeleteVm(context.Background(), req.Name, client.DeleteVmRequest{})
}
```

Run with: `go test ./tests/contract/... -v`

#### 4.2 Update CI/CD Pipeline (1 hour)

**File**: `.github/workflows/provider-tests.yml`

```yaml
name: Provider Tests

on:
  pull_request:
  push:
    branches: [master]

jobs:
  unit-tests:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - run: go test ./internal/... -short -v

  contract-tests:
    runs-on: windows-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
      - uses: actions/setup-dotnet@v3
      - run: go test ./tests/contract/... -v

  smoke-tests:
    runs-on: windows-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
      - name: Run smoke tests
        run: pwsh tests/run-all.ps1 -Tags smoke -AutoStartApi

  critical-tests:
    runs-on: windows-latest
    needs: smoke-tests
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
      - name: Run critical tests
        run: pwsh tests/run-all.ps1 -Tags critical -AutoStartApi
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results.json

  full-tests:
    runs-on: windows-latest
    needs: critical-tests
    if: github.event_name == 'push'  # Only on merge
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
      - name: Run full test suite
        run: pwsh tests/run-all.ps1 -Tags full -AutoStartApi
```

#### 4.3 Update Documentation (2 hours)

**Update files**:
1. `tests/README.md` - Complete testing guide
2. `agent/testing-execution-guide.instructions.md` - Reference harness
3. `CONTRIBUTING.md` - Testing section
4. `plans/new-testing-strategy/06-usage-guide.md` - Examples

**Key sections**:
- How to run tests (smoke, critical, full)
- How to add new scenarios
- How to write custom validations
- Troubleshooting guide

---

## Rollback Plan

If migration fails at any phase:

1. **Phase 1 failure**: Delete `tests/` directory, no impact
2. **Phase 2 failure**: Restore 3 demo scripts from git, continue with old approach
3. **Phase 3 failure**: Keep pilot demos in harness, old scripts for rest
4. **Phase 4 failure**: Harness works, skip contract tests and CI integration

**Key**: Migrate incrementally, keep old scripts until validated.

---

## Success Metrics

### After Phase 2 (Pilot)
- [ ] 3 demos run through harness without errors
- [ ] Tag filtering works (smoke, critical)
- [ ] Custom validations execute correctly
- [ ] JSON results generated

### After Phase 3 (Complete)
- [ ] All 19 demos in harness
- [ ] Zero Test.ps1 files in demos/
- [ ] Full suite runs in <30 minutes
- [ ] scenarios.json is complete

### After Phase 4 (Polish)
- [ ] Contract tests passing
- [ ] CI/CD uses harness
- [ ] Documentation updated
- [ ] Developer feedback incorporated

---

## Timeline Summary

| Week | Phase | Hours | Key Milestone |
|------|-------|-------|---------------|
| 1 | Build Harness | 6 | Working harness for 1 scenario |
| 2 | Pilot Migration | 6 | 3 demos validated |
| 3 | Complete Migration | 8 | All 19 demos in harness |
| 4 | Polish | 5 | CI/CD integrated, docs complete |
| **Total** | | **25** | **Production-ready test system** |

---

## Risk Mitigation

| Risk | Probability | Mitigation |
|------|-------------|------------|
| Harness too complex | Medium | Keep it simple, add features incrementally |
| Custom validations proliferate | Low | Most scenarios use standard logic |
| Performance regression | Low | Tag-based filtering prevents this |
| Migration takes longer | Medium | Pilot phase validates approach early |
| Team pushback | Low | Clear benefits (DRY, faster CI) |

---

## Next Steps

1. ✅ Review and approve migration plan
2. 🔄 Start Phase 1 (build harness)
3. ⏳ Execute Phase 2 (pilot with 3 demos)
4. ⏳ Validate approach, then continue
5. ⏳ Complete Phases 3 & 4

**Recommendation**: Start Phase 1 this week, pilot next week.
