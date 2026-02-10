# Implementation Roadmap — DX and Testing Improvements

**Date**: December 2, 2025  
**Scope**: Prioritized plan for improving developer experience and test infrastructure  
**Duration**: 4 weeks (20 hours total effort)

---

## Roadmap Overview

```
Week 1: Foundation           Week 2: Automation        Week 3: Integration       Week 4: Polish
┌─────────────────┐         ┌─────────────────┐       ┌─────────────────┐      ┌─────────────────┐
│ Setup Scripts   │         │ Watch Mode      │       │ CI/CD Pipeline  │      │ Test Dashboard  │
│ Error Messages  │    →    │ Auto API Mgmt   │   →   │ Test Artifacts  │  →   │ Documentation   │
│ Smoke Tests     │         │ Log Aggregation │       │ Test Tagging    │      │ Final Polish    │
│ Contributing    │         │ Dev Cycle       │       │ Multi-Policy    │      │                 │
└─────────────────┘         └─────────────────┘       └─────────────────┘      └─────────────────┘
   8 hours                      7 hours                  10 hours                 5 hours
```

---

## Week 1: Foundation (8 hours)

**Goal**: Make setup easier and debugging faster

### Tasks

#### 1.1 Create setup.ps1 (2 hours)
**Priority**: 🔴 Critical  
**File**: `terraform-provider-hypervapi-v2/setup.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# One-command developer environment setup

param([switch]$SkipPrereqCheck)

# Check prerequisites (Go, Terraform, .NET, Hyper-V)
# Build provider
# Build API
# Create dev-env.ps1
# Print next steps
```

**Acceptance Criteria**:
- ✅ Checks all prerequisites with clear error messages
- ✅ Builds both provider and API
- ✅ Creates dev environment file
- ✅ Exits with code 0 on success, 1 on failure
- ✅ Takes < 5 minutes to complete

**Testing**:
```powershell
# Fresh checkout
git clone <repo>
cd terraform-provider-hypervapi-v2
./setup.ps1

# Verify
Test-Path bin/terraform-provider-hypervapiv2.exe  # Should be true
Test-Path dev-env.ps1  # Should be true
```

---

#### 1.2 Add smoke-test.ps1 (1 hour)
**Priority**: 🔴 Critical  
**File**: `terraform-provider-hypervapi-v2/smoke-test.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# Quick sanity check (< 30 seconds)

# Build provider
# Verify binary works
# Run Go unit tests (short)
# Optional: API health check
```

**Acceptance Criteria**:
- ✅ Completes in < 30 seconds
- ✅ Exits with code 0 on success, 1 on failure
- ✅ Clear output showing what passed/failed

**Testing**:
```powershell
./smoke-test.ps1
# Expected output:
# ✓ Provider builds
# ✓ Binary works
# ✓ Unit tests pass (5 passed)
# ✓ API reachable
# ✓ Smoke test passed
```

---

#### 1.3 Improve Test.ps1 Error Messages (3 hours)
**Priority**: 🔴 Critical  
**Files**: All `demo/*/Test.ps1` scripts

**Implementation**:
```powershell
# Replace generic errors with structured output
# Old:
Write-Error "Test failed"

# New:
Write-Error @"
[FAIL] API VM existence check
  Expected: VM 'user-test-vm' to exist
  Actual: API returned 404 Not Found
  Endpoint: GET http://localhost:5006/api/v2/vms/user-test-vm
  Timestamp: $(Get-Date -Format "o")
  
  Troubleshooting:
    1. Verify VM was created: terraform show
    2. Check API logs: cat ../hyperv-mgmt-api-v2/logs/api.log
    3. Manual API check: Invoke-RestMethod -Uri <endpoint>
"@
```

**Affected Files**: 19 Test.ps1 scripts

**Acceptance Criteria**:
- ✅ All error messages include:
  - What failed
  - Expected vs. actual
  - Context (endpoint, timestamp)
  - Troubleshooting steps
- ✅ Errors are copy-pasteable for debugging

**Testing**:
```powershell
# Force a failure and verify error message quality
cd demo/01-simple-vm-new-auto
# Modify main.tf to cause failure
pwsh Test.ps1
# Verify error is detailed and actionable
```

---

#### 1.4 Add .vscode/settings.json (30 minutes)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/.vscode/settings.json`

**Implementation**:
```json
{
  "go.useLanguageServer": true,
  "go.lintTool": "golangci-lint",
  "go.lintOnSave": "workspace",
  "go.formatTool": "goimports",
  "editor.formatOnSave": true,
  "go.testTimeout": "60s",
  "[go]": {
    "editor.codeActionsOnSave": {
      "source.organizeImports": true
    }
  },
  "files.exclude": {
    "**/.terraform": true,
    "**/.terraform.lock.hcl": true,
    "**/terraform.tfstate": true,
    "**/terraform.tfstate.backup": true
  }
}
```

**Acceptance Criteria**:
- ✅ Go files auto-format on save
- ✅ Imports auto-organize
- ✅ Linting runs on save
- ✅ Terraform files hidden from file explorer

---

#### 1.5 Write CONTRIBUTING.md (2 hours)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/CONTRIBUTING.md`

**Sections**:
1. **Getting Started**
   - Prerequisites
   - Setup (`./setup.ps1`)
   - First smoke test
2. **Development Workflow**
   - Make changes
   - Run tests
   - Commit guidelines
3. **Testing Guidelines**
   - Unit tests
   - Integration tests (demos)
   - Debug tips
4. **Pull Request Checklist**
   - Code formatted
   - Tests pass
   - Docs updated

**Acceptance Criteria**:
- ✅ Clear step-by-step instructions
- ✅ Links to relevant documentation
- ✅ Examples of good commits/PRs

---

### Week 1 Deliverables

- ✅ `setup.ps1` - One-command setup
- ✅ `smoke-test.ps1` - Fast sanity check
- ✅ Improved error messages (all Test.ps1)
- ✅ `.vscode/settings.json` - IDE configuration
- ✅ `CONTRIBUTING.md` - Contributor guide

**Impact**: 50% faster setup, 70% faster debugging

---

## Week 2: Automation (7 hours)

**Goal**: Reduce manual work and enable continuous development

### Tasks

#### 2.1 Add Watch Mode (3 hours)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/watch-and-test.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# Watch Go files and auto-rebuild + test

param(
    [string]$Demo = "01-simple-vm-new-auto",
    [string]$Pattern = "*.go"
)

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "internal/"
$watcher.Filter = $Pattern
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$action = {
    Write-Host "`nChange detected at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Yellow
    
    # Rebuild
    go build -o bin/terraform-provider-hypervapiv2.exe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed" -ForegroundColor Red
        return
    }
    
    # Run test
    & "demo/$($args[0])/Test.ps1" -VmName "user-watch-test"
}

Register-ObjectEvent $watcher "Changed" -Action $action -MessageData $Demo

Write-Host "Watching $($watcher.Path) for changes..." -ForegroundColor Cyan
Write-Host "Demo: $Demo" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray

try {
    while ($true) { Start-Sleep 1 }
} finally {
    $watcher.Dispose()
}
```

**Acceptance Criteria**:
- ✅ Detects Go file changes
- ✅ Auto-rebuilds provider
- ✅ Runs specified demo test
- ✅ Debounces rapid changes (< 1 second apart)
- ✅ Graceful shutdown on Ctrl+C

**Testing**:
```powershell
./watch-and-test.ps1 -Demo "01-simple-vm-new-auto"
# Make change to internal/resources/vm.go
# Verify auto-rebuild + test runs
```

---

#### 2.2 Auto-Manage API in Tests (1 hour)
**Priority**: 🟡 Medium  
**Files**: Common test helpers

**Implementation**:
```powershell
# Create scripts/test-helpers.ps1
function Start-ApiIfNeeded {
    param([string]$Endpoint = "http://localhost:5006")
    
    try {
        Invoke-RestMethod -Uri "$Endpoint/api/v2/vms" -Method Get -TimeoutSec 2 | Out-Null
        Write-Host "API already running" -ForegroundColor Green
        return $false  # Didn't start (was already running)
    } catch {
        Write-Host "Starting API..." -ForegroundColor Cyan
        & scripts/Run-ApiForExample.ps1 -Action start
        return $true  # Started API
    }
}

function Stop-ApiIfStarted {
    param([bool]$Started)
    
    if ($Started) {
        Write-Host "Stopping API..." -ForegroundColor Cyan
        & scripts/Run-ApiForExample.ps1 -Action stop
    }
}
```

**Update Test.ps1**:
```powershell
param([switch]$AutoApi)

if ($AutoApi) {
    . ../scripts/test-helpers.ps1
    $apiStarted = Start-ApiIfNeeded
    try {
        # Run tests...
    } finally {
        Stop-ApiIfStarted $apiStarted
    }
}
```

**Acceptance Criteria**:
- ✅ Detects if API already running
- ✅ Only starts/stops if needed
- ✅ Cleanup in finally block
- ✅ Backward compatible (optional flag)

---

#### 2.3 Log Aggregation (2 hours)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/tail-logs.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# Aggregate Terraform + API logs

param(
    [string]$Demo,
    [string]$TfLog = "demo/$Demo/terraform.log",
    [string]$ApiLog = "../hyperv-mgmt-api-v2/logs/api.log"
)

# Tail both logs, merge by timestamp
Get-Content $TfLog, $ApiLog -Wait | 
    Sort-Object @{Expression={
        # Extract timestamp from log line
        if ($_ -match '^\[?(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})') {
            [DateTime]$matches[1]
        } else {
            Get-Date
        }
    }} |
    ForEach-Object {
        # Color-code by severity
        if ($_ -match 'ERROR|FAIL') {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match 'WARN|WARNING') {
            Write-Host $_ -ForegroundColor Yellow
        } elseif ($_ -match 'http\.request|http\.response') {
            Write-Host $_ -ForegroundColor Cyan
        } else {
            Write-Host $_
        }
    }
```

**Acceptance Criteria**:
- ✅ Tails both TF and API logs
- ✅ Sorts by timestamp
- ✅ Color-codes by severity
- ✅ Follows logs in real-time

---

#### 2.4 Create dev-test.ps1 (1 hour)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/dev-test.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# One-command development cycle

param(
    [Parameter(Mandatory)]
    [string]$Demo,
    
    [switch]$Watch,
    [switch]$AutoApi
)

if ($Watch) {
    & ./watch-and-test.ps1 -Demo $Demo
} else {
    # Single run
    go build -o bin/terraform-provider-hypervapiv2.exe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
        exit 1
    }
    
    $testArgs = @{
        VmName = "user-dev-test"
    }
    if ($AutoApi) { $testArgs.AutoApi = $true }
    
    & "demo/$Demo/Test.ps1" @testArgs
}
```

**Acceptance Criteria**:
- ✅ Single command for dev cycle
- ✅ Supports watch mode
- ✅ Supports auto API management
- ✅ Clear error messages

---

### Week 2 Deliverables

- ✅ `watch-and-test.ps1` - Auto-rebuild on changes
- ✅ Auto API management in tests
- ✅ `tail-logs.ps1` - Unified log view
- ✅ `dev-test.ps1` - One-command dev cycle

**Impact**: 40% faster iteration cycle, less context switching

---

## Week 3: Integration (10 hours)

**Goal**: Automate testing in CI/CD and improve test quality

### Tasks

#### 3.1 GitHub Actions Workflow (3 hours)
**Priority**: 🔴 Critical  
**File**: `.github/workflows/provider-tests.yml`

**Implementation**:
```yaml
name: Provider Integration Tests

on:
  pull_request:
  push:
    branches: [master]

jobs:
  smoke-test:
    runs-on: windows-latest
    timeout-minutes: 5
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Run smoke tests
        run: pwsh smoke-test.ps1
  
  integration-tests:
    runs-on: windows-latest
    timeout-minutes: 30
    needs: smoke-test
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0'
      
      - name: Build provider
        run: go build -o bin/terraform-provider-hypervapiv2.exe
      
      - name: Start API
        run: |
          cd terraform-provider-hypervapi-v2
          pwsh scripts/Run-ApiForExample.ps1 -Action start
      
      - name: Run critical demos
        run: |
          $demos = @(
            "01-simple-vm-new-auto",
            "02-vm-windows-perfect",
            "13-disk-unified-new-auto"
          )
          foreach ($demo in $demos) {
            Write-Host "Testing: $demo" -ForegroundColor Cyan
            cd "demo/$demo"
            pwsh Test.ps1 -VmName "ci-$demo" -Strict
            if ($LASTEXITCODE -ne 0) {
              Write-Error "Test failed: $demo"
              exit 1
            }
            cd ../..
          }
      
      - name: Stop API
        if: always()
        run: pwsh scripts/Run-ApiForExample.ps1 -Action stop
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: demo/**/test-results.json
```

**Acceptance Criteria**:
- ✅ Runs on PR and push to master
- ✅ Smoke test runs first (fast fail)
- ✅ Integration tests run critical demos
- ✅ Uploads test artifacts
- ✅ Cleans up API even on failure

---

#### 3.2 Structured Test Output (3 hours)
**Priority**: 🔴 Critical  
**Files**: All `demo/*/Test.ps1` scripts

**Implementation**:
```powershell
# Add to Test.ps1
$testResults = @{
    demo = "01-simple-vm-new-auto"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    duration_seconds = 0
    status = "passed"  # or "failed"
    checks = @()
    errors = @()
    warnings = @()
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Each check adds to $testResults.checks
    $check = @{
        name = "api_reachable"
        passed = $true
        duration_ms = 150
        message = "API responded in 150ms"
    }
    $testResults.checks += $check
    
    # ... more checks
    
    $testResults.status = "passed"
} catch {
    $testResults.status = "failed"
    $testResults.errors += $_.Exception.Message
} finally {
    $testResults.duration_seconds = $stopwatch.Elapsed.TotalSeconds
    $testResults | ConvertTo-Json -Depth 10 | Out-File "test-results.json"
}
```

**Acceptance Criteria**:
- ✅ JSON output for every test run
- ✅ Includes all check results
- ✅ Includes timing information
- ✅ Includes errors and warnings
- ✅ Compatible with CI/CD parsers

---

#### 3.3 Test Tagging (2 hours)
**Priority**: 🟡 Medium  
**Files**: `demo/*/test-metadata.json` + `run-tests.ps1`

**Implementation**:
```json
// demo/01-simple-vm-new-auto/test-metadata.json
{
  "tags": ["smoke", "critical", "vm", "disk"],
  "estimated_duration_seconds": 120,
  "requires": ["api", "hyperv"],
  "priority": "high"
}
```

```powershell
# run-tests.ps1 - Run tests by tag
param(
    [string[]]$Tags,
    [switch]$All
)

$demos = Get-ChildItem -Directory demo/
foreach ($demo in $demos) {
    $metadataPath = "$($demo.FullName)/test-metadata.json"
    if (Test-Path $metadataPath) {
        $metadata = Get-Content $metadataPath | ConvertFrom-Json
        
        if ($All -or ($metadata.tags | Where-Object { $Tags -contains $_ })) {
            Write-Host "Running: $($demo.Name)" -ForegroundColor Cyan
            & "$($demo.FullName)/Test.ps1"
        }
    }
}
```

**Acceptance Criteria**:
- ✅ Every demo has test-metadata.json
- ✅ `run-tests.ps1 -Tags smoke` runs only smoke tests
- ✅ `run-tests.ps1 -Tags critical` runs critical tests
- ✅ `run-tests.ps1 -All` runs everything

---

#### 3.4 Multi-Policy Testing (2 hours)
**Priority**: 🟡 Medium  
**File**: `terraform-provider-hypervapi-v2/test-all-policies.ps1`

**Implementation**:
```powershell
#!/usr/bin/env pwsh
# Run tests against multiple policy modes

param([string[]]$Demos = @("01-simple-vm-new-auto"))

$policies = @(
    @{ Mode = "allow-all"; Dir = "C:\hyperv-mgmt\policy-packs\allow-all" },
    @{ Mode = "strict"; Dir = "C:\hyperv-mgmt\policy-packs\strict-multiuser" }
)

foreach ($policy in $policies) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Testing with policy: $($policy.Mode)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Start API with policy
    $env:POLICY_MODE = $policy.Mode
    $env:POLICY_DIR = $policy.Dir
    & scripts/Run-ApiForExample.ps1 -Action start
    
    foreach ($demo in $Demos) {
        Write-Host "Demo: $demo" -ForegroundColor Yellow
        & "demo/$demo/Test.ps1" -VmName "user-test-$($policy.Mode)"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Test failed with $($policy.Mode) policy"
        }
    }
    
    & scripts/Run-ApiForExample.ps1 -Action stop
}
```

**Acceptance Criteria**:
- ✅ Tests run against both allow-all and strict policies
- ✅ Cleans up API between policy changes
- ✅ Reports which policy mode each result corresponds to

---

### Week 3 Deliverables

- ✅ GitHub Actions workflow
- ✅ Structured test output (JSON)
- ✅ Test tagging and filtered runs
- ✅ Multi-policy test runner

**Impact**: Automated CI/CD, better test tracking

---

## Week 4: Polish (5 hours)

**Goal**: Final improvements and documentation

### Tasks

#### 4.1 Test Coverage Dashboard (3 hours)
**Priority**: 🟢 Low  
**File**: `terraform-provider-hypervapi-v2/generate-dashboard.ps1`

**Implementation**:
```powershell
# Generate HTML dashboard from test-results.json files

$results = Get-ChildItem -Recurse -Filter "test-results.json" |
    ForEach-Object { Get-Content $_ | ConvertFrom-Json }

$html = @"
<!DOCTYPE html>
<html>
<head><title>Test Dashboard</title></head>
<body>
<h1>Terraform Provider Test Results</h1>
<p>Last updated: $(Get-Date)</p>

<h2>Summary</h2>
<table>
  <tr>
    <td>Total Tests:</td>
    <td>$($results.Count)</td>
  </tr>
  <tr>
    <td>Passed:</td>
    <td style="color:green">$($results | Where-Object status -eq 'passed' | Measure-Object | Select-Object -ExpandProperty Count)</td>
  </tr>
  <tr>
    <td>Failed:</td>
    <td style="color:red">$($results | Where-Object status -eq 'failed' | Measure-Object | Select-Object -ExpandProperty Count)</td>
  </tr>
</table>

<h2>Details</h2>
<!-- Table of all test results -->
</body>
</html>
"@

Set-Content -Path "test-dashboard.html" -Value $html
```

**Acceptance Criteria**:
- ✅ HTML dashboard generated from JSON results
- ✅ Shows pass/fail summary
- ✅ Shows individual test details
- ✅ Sortable by demo, status, duration

---

#### 4.2 Update Documentation (2 hours)
**Priority**: 🟡 Medium  
**Files**: `README.md`, `DEVELOPER.md`, agent docs

**Tasks**:
1. Update main README with new setup instructions
2. Update DEVELOPER.md with new workflows
3. Update agent docs with DX improvements
4. Add troubleshooting section

**Acceptance Criteria**:
- ✅ All docs reference new scripts
- ✅ Clear examples of new workflows
- ✅ Troubleshooting guides updated

---

### Week 4 Deliverables

- ✅ Test coverage dashboard
- ✅ Updated documentation
- ✅ Final polish and cleanup

**Impact**: Better visibility, clearer documentation

---

## Implementation Checklist

### Week 1: Foundation
- [ ] `setup.ps1` created and tested
- [ ] `smoke-test.ps1` created and tested
- [ ] All Test.ps1 scripts have improved errors
- [ ] `.vscode/settings.json` added
- [ ] `CONTRIBUTING.md` written

### Week 2: Automation
- [ ] `watch-and-test.ps1` working
- [ ] Auto API management implemented
- [ ] `tail-logs.ps1` aggregating logs
- [ ] `dev-test.ps1` one-command cycle

### Week 3: Integration
- [ ] GitHub Actions workflow created
- [ ] All Test.ps1 generate JSON output
- [ ] Test metadata files created
- [ ] `run-tests.ps1` filters by tags
- [ ] Multi-policy test runner works

### Week 4: Polish
- [ ] Test dashboard generates HTML
- [ ] All docs updated
- [ ] Final testing complete

---

## Success Metrics

### Before Improvements
- **Setup time**: 10 minutes, 10 commands
- **Iteration cycle**: 3 minutes
- **Debug time**: 20+ minutes
- **Onboarding time**: 60 minutes

### After Improvements (Target)
- **Setup time**: 5 minutes, 1 command (50% improvement)
- **Iteration cycle**: 1.5 minutes (50% improvement)
- **Debug time**: 5-10 minutes (70% improvement)
- **Onboarding time**: 15 minutes (75% improvement)

---

## Risk Mitigation

### Risk 1: Breaking Existing Workflows
**Mitigation**: All new features are opt-in (flags, separate scripts)

### Risk 2: CI/CD Failures in GitHub Actions
**Mitigation**: Test locally first with similar environment

### Risk 3: Watch Mode Performance Issues
**Mitigation**: Debounce rapid changes, add file filters

---

## Summary

**Total Effort**: 30 hours over 4 weeks  
**Expected ROI**: 40-50% developer productivity increase  
**Key Deliverables**:
- ✅ One-command setup
- ✅ Auto-rebuild watch mode
- ✅ Automated CI/CD pipeline
- ✅ Structured test output
- ✅ Test coverage dashboard

**Recommendation**: Execute phases sequentially, validate after each week.
