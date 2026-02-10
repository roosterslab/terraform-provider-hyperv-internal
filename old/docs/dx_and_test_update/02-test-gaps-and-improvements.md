# Test Gaps and Improvement Opportunities

**Date**: December 2, 2025  
**Context**: Analysis of 19 existing demos to identify gaps and enhancement opportunities

---

## Gap Analysis

### 1. Missing Features (Not Tested)

#### 1.1 Attach Existing Disk
**Status**: ⚠️ **Not Implemented**  
**Planned In**: `05-testing-strategy.md` as demo #5  
**Priority**: Medium

**Description**: No demo tests attaching a pre-existing VHDX file to a VM.

**Expected Behavior**:
```hcl
resource "hypervapiv2_vm" "test" {
  name = "user-test-vm"
  
  disk {
    name        = "shared-data"
    source_path = "D:/HyperV/Shared/data.vhdx"
    read_only   = false
  }
  
  lifecycle {
    # Should NOT delete disk on destroy
    delete_disks = false
  }
}
```

**Test Requirements**:
1. Pre-create VHDX file before test
2. Attach to VM
3. Verify disk attached via API
4. Destroy VM
5. **Verify disk NOT deleted** (critical)

**Effort**: 2-3 hours

---

#### 1.2 Multiple Network Adapters
**Status**: ⚠️ **Partially Tested**  
**Current**: Demo 03 tests single adapter  
**Priority**: Low

**Description**: No demo tests VM with multiple network adapters.

**Expected Behavior**:
```hcl
resource "hypervapiv2_network" "lan" {
  name = "user-internal-lan"
  type = "Internal"
}

resource "hypervapiv2_network" "wan" {
  name = "user-external-wan"
  type = "External"
}

resource "hypervapiv2_vm" "test" {
  name = "user-multi-nic-vm"
  
  network_interface {
    name   = "nic-lan"
    switch = hypervapiv2_network.lan.name
  }
  
  network_interface {
    name   = "nic-wan"
    switch = hypervapiv2_network.wan.name
  }
  
  disk { name = "os"; size = "20GB" }
}
```

**Test Requirements**:
1. Create two switches
2. Create VM with two adapters
3. Verify both adapters exist via API
4. Verify each connected to correct switch
5. Test adapter ordering/priority

**Effort**: 2-3 hours

---

#### 1.3 VLAN Configuration
**Status**: ❌ **Not Tested**  
**Priority**: Low

**Description**: No demo tests VLAN tagging on network adapters.

**Expected Behavior**:
```hcl
resource "hypervapiv2_vm" "test" {
  name = "user-vlan-vm"
  
  network_interface {
    switch   = "ExternalSwitch"
    vlan_id  = 100
    vlan_mode = "Access"
  }
  
  disk { name = "os"; size = "20GB" }
}
```

**Test Requirements**:
1. Create VM with VLAN config
2. Verify VLAN settings via API
3. Test different VLAN modes (Access, Trunk)

**Effort**: 1-2 hours  
**Blocker**: API may need VLAN endpoint support

---

#### 1.4 VM Planning (Preflight)
**Status**: ⚠️ **API Endpoint Missing**  
**Demo Exists**: Demo 11 (`11-vm-plan-preflight`)  
**Priority**: Medium

**Description**: Demo 11 exists but API endpoint `/api/v2/vm-plan` not implemented.

**Expected Behavior**:
```hcl
data "hypervapiv2_vm_plan" "preflight" {
  name       = "user-planned-vm"
  generation = 2
  cpu_count  = 4
  memory_mb  = 8192
  
  disk {
    purpose = "os"
    size_gb = 50
  }
}

output "warnings" {
  value = data.hypervapiv2_vm_plan.preflight.warnings
}

output "errors" {
  value = data.hypervapiv2_vm_plan.preflight.errors
}
```

**API Requirement**: Implement `POST /api/v2/vm-plan` endpoint

**Test Requirements**:
1. Call vm_plan data source
2. Verify warnings/errors returned
3. Test with policy violations
4. Test with resource conflicts

**Effort**: 3-4 hours (2 hours API, 1-2 hours demo)

---

### 2. Duplicate/Overlapping Demos

#### 2.1 Delete Semantics (09 vs 14)
**Status**: 🔍 **Needs Review**  
**Priority**: Low

**Observation**: Two demos with same/similar names:
- `09-delete-semantics`
- `14-delete-semantics`

**Questions**:
1. Are they testing different aspects?
2. Is one an updated version of the other?
3. Should they be consolidated?

**Action Required**:
1. Read both demo `main.tf` files
2. Compare Test.ps1 validation steps
3. Consolidate if duplicate, or rename if testing different scenarios

**Effort**: 30 minutes

---

### 3. Test Quality Issues

#### 3.1 No Structured Test Output
**Status**: ❌ **Not Implemented**  
**Priority**: Medium

**Issue**: Test.ps1 scripts write to console but don't generate structured output for CI/CD parsing.

**Impact**:
- Hard to track test results over time
- No automated pass/fail metrics
- CI/CD systems can't parse results

**Proposed Solution**:
```powershell
# In Test.ps1, generate JSON report
$testResults = @{
    demo = "01-simple-vm-new-auto"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    duration_seconds = $duration
    status = "passed"  # or "failed"
    checks = @(
        @{ name = "api_reachable"; passed = $true }
        @{ name = "vm_exists"; passed = $true }
        @{ name = "disk_created"; passed = $true }
        @{ name = "policy_valid"; passed = $true }
        @{ name = "cleanup_complete"; passed = $true }
    )
    errors = @()
    warnings = @()
}

$testResults | ConvertTo-Json -Depth 10 | Out-File "test-results.json"
```

**Effort**: 2-3 hours (update all Test.ps1 scripts)

---

#### 3.2 No Performance Tracking
**Status**: ❌ **Not Implemented**  
**Priority**: Low

**Issue**: No tracking of test execution times or API response latencies.

**Impact**:
- Can't identify slow tests
- No baseline for performance regression
- Hard to optimize CI/CD pipeline

**Proposed Solution**:
```powershell
# Track timings
$timings = @{
    provider_build = Measure-Command { go build ... }
    terraform_init = Measure-Command { terraform init }
    terraform_apply = Measure-Command { terraform apply }
    api_vm_get = Measure-Command { Invoke-RestMethod ... }
    terraform_destroy = Measure-Command { terraform destroy }
    total = $stopwatch.Elapsed.TotalSeconds
}

# Include in test results JSON
```

**Effort**: 1-2 hours

---

#### 3.3 Limited Error Context
**Status**: ⚠️ **Could Be Better**  
**Priority**: Low

**Issue**: When tests fail, error messages sometimes lack context (which step, what was expected vs. actual).

**Example of Poor Error**:
```powershell
Write-Error "Test failed"
exit 1
```

**Example of Good Error**:
```powershell
Write-Error @"
[FAIL] API VM existence check
  Expected: VM 'user-test-vm' to exist
  Actual: API returned 404 Not Found
  Endpoint: GET http://localhost:5006/api/v2/vms/user-test-vm
  Timestamp: 2025-12-02T10:30:45Z
"@
exit 1
```

**Effort**: 2-3 hours (improve error messages across all tests)

---

### 4. CI/CD Integration Gaps

#### 4.1 No GitHub Actions Workflow
**Status**: ❌ **Not Implemented**  
**Priority**: High

**Issue**: Tests are not automated in CI/CD pipeline.

**Impact**:
- Manual testing required before merge
- Risk of breaking changes
- Slower development cycle

**Proposed Workflow** (see `01-current-testing-state.md` for full example):
```yaml
name: Provider Integration Tests
on: [pull_request, push]
jobs:
  test-provider:
    runs-on: windows-latest
    steps:
      - Checkout
      - Setup Go
      - Build provider
      - Start API
      - Run critical demos
      - Stop API
      - Upload test results
```

**Effort**: 2-3 hours

---

#### 4.2 No Test Artifacts
**Status**: ❌ **Not Implemented**  
**Priority**: Medium

**Issue**: Test results, logs, and failure screenshots not saved as artifacts.

**Proposed Artifacts**:
- `test-results.json` (structured results)
- `terraform.log` (TF_LOG output)
- `api.log` (API server logs)
- `failed-states/*.tfstate` (state files from failed tests)

**GitHub Actions Example**:
```yaml
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: |
      demo/**/test-results.json
      demo/**/terraform.log
```

**Effort**: 1 hour

---

#### 4.3 No Test Tagging/Suites
**Status**: ❌ **Not Implemented**  
**Priority**: Medium

**Issue**: All tests run together; no way to run subsets (smoke, critical, full).

**Proposed Tagging**:
```powershell
# In each demo, add metadata file
# demo/01-simple-vm-new-auto/test-metadata.json
{
    "tags": ["smoke", "critical", "vm", "disk"],
    "estimated_duration_seconds": 120,
    "requires_api": true,
    "requires_hyperv": true,
    "priority": "high"
}
```

**Test Runner with Filtering**:
```powershell
# Run only smoke tests
.\run-tests.ps1 -Tags "smoke"

# Run only critical tests
.\run-tests.ps1 -Tags "critical"

# Run full suite
.\run-tests.ps1 -Tags "full"
```

**Effort**: 2-3 hours

---

### 5. Developer Experience Gaps

#### 5.1 No "Watch Mode" for Development
**Status**: ❌ **Not Implemented**  
**Priority**: Low

**Issue**: Developers must manually re-run tests after code changes.

**Proposed Solution**:
```powershell
# watch-test.ps1
# Watches for Go file changes and re-runs specific demo

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "internal/"
$watcher.Filter = "*.go"
$watcher.IncludeSubdirectories = $true

Register-ObjectEvent $watcher "Changed" -Action {
    Write-Host "Change detected, rebuilding and testing..." -ForegroundColor Yellow
    & ./build-and-test.ps1 -Demo "01-simple-vm-new-auto"
}

Write-Host "Watching for changes (Ctrl+C to exit)..."
while ($true) { Start-Sleep 1 }
```

**Effort**: 2 hours

---

#### 5.2 No Test Coverage Dashboard
**Status**: ❌ **Not Implemented**  
**Priority**: Low

**Issue**: No visual representation of test coverage or pass/fail trends.

**Proposed Solution**:
- Generate HTML report from test-results.json
- Show: Pass rate, duration trends, flaky tests
- Commit to repo or publish to GitHub Pages

**Effort**: 4-6 hours

---

### 6. Missing Negative Tests

#### 6.1 Resource Conflicts
**Status**: ⚠️ **Partially Tested**  
**Priority**: Low

**Issue**: Limited testing of error scenarios (e.g., VM name already exists).

**Proposed Tests**:
1. Create VM twice (expect second to fail)
2. Attach disk already in use (expect fail)
3. Connect to non-existent switch (expect fail)
4. Invalid generation (e.g., gen1 with secure boot)

**Effort**: 3-4 hours (add to existing demos or create new)

---

#### 6.2 API Timeout Handling
**Status**: ❌ **Not Tested**  
**Priority**: Low

**Issue**: No tests for API timeout scenarios.

**Proposed Tests**:
1. Simulate slow API responses
2. Test provider timeout settings
3. Verify graceful failures

**Effort**: 2-3 hours

---

### 7. Environment Variations

#### 7.1 Multi-Policy Testing
**Status**: ⚠️ **Manual Only**  
**Priority**: Medium

**Issue**: Tests run against single policy mode (Testing or Production).

**Proposed Solution**:
```powershell
# Run demos against multiple policy modes
$policyModes = @("allow-all", "strict-multiuser")

foreach ($mode in $policyModes) {
    Write-Host "Testing with policy: $mode"
    
    # Start API with policy
    $env:POLICY_MODE = $mode
    & Start-Api.ps1
    
    # Run critical demos
    & Run-Demos.ps1 -Tags "critical"
    
    # Stop API
    & Stop-Api.ps1
}
```

**Effort**: 1-2 hours

---

#### 7.2 Cross-Platform Testing
**Status**: ❌ **Not Applicable**  
**Priority**: N/A

**Note**: Provider and API are Windows-only (Hyper-V dependency), so cross-platform testing not relevant.

---

## Prioritized Improvement Roadmap

### Phase 1: Critical Gaps (Week 1)
**Goal**: Address blockers and high-priority gaps

| Task | Priority | Effort | Impact |
|------|----------|--------|--------|
| Implement vm_plan API endpoint | High | 2h | Unblocks demo 11 |
| Add "attach existing disk" demo | Medium | 3h | Completes feature coverage |
| Review duplicate delete demos (09/14) | Low | 30m | Reduces confusion |

**Total**: ~5.5 hours

---

### Phase 2: CI/CD Integration (Week 2)
**Goal**: Automate testing in GitHub Actions

| Task | Priority | Effort | Impact |
|------|----------|--------|--------|
| Create GitHub Actions workflow | High | 3h | Enables automated testing |
| Add structured test output (JSON) | Medium | 3h | Enables result tracking |
| Add test artifacts upload | Medium | 1h | Aids debugging failures |
| Add test tagging/suites | Medium | 3h | Enables filtered test runs |

**Total**: ~10 hours

---

### Phase 3: Test Quality (Week 3)
**Goal**: Improve test reliability and debugging

| Task | Priority | Effort | Impact |
|------|----------|--------|--------|
| Improve error messages | Low | 3h | Easier debugging |
| Add performance tracking | Low | 2h | Identifies slow tests |
| Add negative test scenarios | Low | 4h | Better error handling validation |

**Total**: ~9 hours

---

### Phase 4: Developer Experience (Week 4)
**Goal**: Make testing easier for developers

| Task | Priority | Effort | Impact |
|------|----------|--------|--------|
| Add watch mode for development | Low | 2h | Faster dev cycle |
| Create test coverage dashboard | Low | 6h | Visual feedback |
| Add multi-policy test runner | Medium | 2h | Better policy coverage |

**Total**: ~10 hours

---

## Summary

### Current State
- ✅ 19 comprehensive demos
- ✅ Consistent test pattern
- ⚠️ ~5% feature gap (attach disk, vm_plan)
- ❌ No CI/CD integration
- ❌ No structured test output

### Recommended Priorities

**Must Have** (Phase 1):
1. ✅ Implement vm_plan API endpoint
2. ✅ Add "attach existing disk" demo
3. ✅ Review duplicate demos

**Should Have** (Phase 2):
1. ✅ CI/CD integration (GitHub Actions)
2. ✅ Structured test output (JSON)
3. ✅ Test artifacts

**Nice to Have** (Phases 3-4):
1. Better error messages
2. Performance tracking
3. Watch mode for development
4. Test coverage dashboard

**Total Effort**: ~35 hours across 4 weeks

**Expected Outcome**: Complete test coverage + automated CI/CD pipeline + improved developer experience.
