# Developer Experience (DX) Analysis

**Date**: December 2, 2025  
**Focus**: Analyzing the developer workflow for terraform-provider-hypervapi-v2

---

## Current Developer Workflow

### Setup (First Time)

**Time**: ~5-10 minutes

```powershell
# 1. Clone repository
git clone <repo-url>
cd terraform-provider-hypervapi-v2

# 2. Install prerequisites
# - Go 1.21+ (check: go version)
# - Terraform 1.5+ (check: terraform version)
# - .NET 8 SDK (for API server)
# - Hyper-V enabled

# 3. Build provider
go mod tidy
go build -o bin/terraform-provider-hypervapiv2.exe

# 4. Start API server
cd ../hyperv-mgmt-api-v2
dotnet build
dotnet run --urls "http://localhost:5006"

# 5. Run first demo
cd ../terraform-provider-hypervapi-v2/demo/01-simple-vm-new-auto
pwsh Run.ps1
```

**Pain Points**:
- ❌ No single setup script
- ❌ Multiple directory changes required
- ❌ Manual API server management
- ⚠️ Prerequisites not clearly documented in one place

---

### Development Loop (Typical)

**Time**: ~2-5 minutes per iteration

```powershell
# 1. Make code changes in internal/
vim internal/resources/vm.go

# 2. Rebuild provider
go build -o bin/terraform-provider-hypervapiv2.exe

# 3. Test changes
cd demo/01-simple-vm-new-auto
pwsh Test.ps1 -VmName "user-dev-test" -BuildProvider

# 4. Debug if needed
pwsh Run.ps1 -VerboseHttp -TfLogPath "./debug.log"
cat debug.log | sls "ERROR"
```

**Pain Points**:
- ❌ Manual rebuild required
- ❌ No file watcher for auto-rebuild
- ⚠️ Test takes 2-3 minutes (slow feedback)
- ❌ No quick unit test option

---

### Debugging Failed Tests

**Time**: ~10-30 minutes

```powershell
# 1. Test fails with generic error
pwsh Test.ps1 -VmName "user-test"
# Output: [FAIL] Test failed

# 2. Re-run with verbose logging
pwsh Run.ps1 -VerboseHttp -TfLogPath "./terraform.log"

# 3. Analyze Terraform logs
cat terraform.log | sls "http.response"
cat terraform.log | sls "ERROR|WARN"

# 4. Check API logs
# (No centralized API log - must check terminal where API runs)

# 5. Inspect Terraform state
terraform show

# 6. Check API state
Invoke-RestMethod -Uri "http://localhost:5006/api/v2/vms/user-test"

# 7. Manual cleanup if test didn't destroy
terraform destroy -auto-approve
```

**Pain Points**:
- ❌ Poor error messages (generic failures)
- ❌ No unified logging view (TF logs + API logs separate)
- ❌ Manual correlation between TF state and API state
- ⚠️ Cleanup sometimes manual if test aborts

---

## DX Strengths

### ✅ Good Aspects

1. **Consistent Demo Pattern**
   - All demos follow same Run/Test/Destroy structure
   - Easy to understand what each script does
   - Predictable behavior

2. **Dev Override Pattern**
   - No need to publish provider to registry during dev
   - Changes take effect immediately after rebuild
   - Clear separation of dev vs. production workflows

3. **API Management Helper**
   - `scripts/Run-ApiForExample.ps1` centralizes API lifecycle
   - Health checks ensure API is ready before tests
   - Graceful shutdown with PID tracking

4. **Parameterized Scripts**
   - All scripts accept common parameters (Endpoint, VmName, BuildProvider)
   - Easy to customize for different scenarios
   - Supports verbose mode for debugging

5. **Self-Contained Demos**
   - Each demo is independent
   - Clear main.tf showing feature usage
   - README files explain purpose (where present)

---

## DX Pain Points

### 🔴 Critical Issues

#### 1. No Single-Command Setup
**Problem**: Developer must manually run 5-10 commands to get started.

**Impact**: High friction for new contributors, wasted time.

**Proposed Solution**: `setup.ps1` script
```powershell
#!/usr/bin/env pwsh
# setup.ps1 - One-command developer setup

param(
    [switch]$SkipPrereqCheck
)

Write-Host "=== Terraform Provider HyperV API v2 Setup ===" -ForegroundColor Cyan

# Check prerequisites
if (-not $SkipPrereqCheck) {
    Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
    
    # Go
    $goVersion = go version 2>$null
    if (-not $goVersion) {
        Write-Error "Go not found. Install from https://go.dev/dl/"
        exit 1
    }
    Write-Host "  ✓ Go: $goVersion" -ForegroundColor Green
    
    # Terraform
    $tfVersion = terraform version 2>$null
    if (-not $tfVersion) {
        Write-Error "Terraform not found. Install from https://terraform.io/downloads"
        exit 1
    }
    Write-Host "  ✓ Terraform: $tfVersion" -ForegroundColor Green
    
    # .NET
    $dotnetVersion = dotnet --version 2>$null
    if (-not $dotnetVersion) {
        Write-Error ".NET SDK not found. Install from https://dotnet.microsoft.com/download"
        exit 1
    }
    Write-Host "  ✓ .NET SDK: $dotnetVersion" -ForegroundColor Green
    
    # Hyper-V
    $hypervService = Get-Service vmms -ErrorAction SilentlyContinue
    if (-not $hypervService) {
        Write-Warning "Hyper-V service not found. Some tests may fail."
    } else {
        Write-Host "  ✓ Hyper-V: Running" -ForegroundColor Green
    }
}

# Build provider
Write-Host "`nBuilding provider..." -ForegroundColor Yellow
go mod download
go build -o bin/terraform-provider-hypervapiv2.exe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Provider build failed"
    exit 1
}
Write-Host "  ✓ Provider built: bin/terraform-provider-hypervapiv2.exe" -ForegroundColor Green

# Build API
Write-Host "`nBuilding API..." -ForegroundColor Yellow
Push-Location ../hyperv-mgmt-api-v2
dotnet build
if ($LASTEXITCODE -ne 0) {
    Write-Error "API build failed"
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "  ✓ API built" -ForegroundColor Green

# Create dev environment file
Write-Host "`nCreating dev environment..." -ForegroundColor Yellow
$devEnvContent = @"
# Development Environment Configuration
# Source this file: . ./dev-env.ps1

`$env:TF_LOG = "INFO"
`$env:PROVIDER_BIN = "`$PSScriptRoot/bin/terraform-provider-hypervapiv2.exe"
`$env:API_ENDPOINT = "http://localhost:5006"

Write-Host "Dev environment loaded:" -ForegroundColor Green
Write-Host "  Provider: `$env:PROVIDER_BIN"
Write-Host "  API: `$env:API_ENDPOINT"
"@
Set-Content -Path "dev-env.ps1" -Value $devEnvContent
Write-Host "  ✓ Created dev-env.ps1" -ForegroundColor Green

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Start API:  pwsh scripts/Run-ApiForExample.ps1 -Action start"
Write-Host "  2. Run demo:   cd demo/01-simple-vm-new-auto; pwsh Test.ps1"
Write-Host "  3. See docs:   cat agent/testing-execution-guide.instructions.md"
Write-Host ""
```

**Effort**: 2 hours

---

#### 2. Slow Feedback Loop
**Problem**: Rebuilding provider + running full test takes 2-3 minutes.

**Impact**: Developer productivity, frustration during debugging.

**Proposed Solution**: Faster unit tests + watch mode
```powershell
# Quick unit test (no API, no Terraform)
go test ./internal/... -v -short

# Watch mode for auto-rebuild
& ./watch-and-test.ps1 -Demo "01-simple-vm-new-auto"
```

**Effort**: 3 hours

---

#### 3. Poor Error Messages
**Problem**: Tests fail with generic messages like "[FAIL] Test failed".

**Impact**: Hard to debug, wastes time.

**Proposed Solution**: Enhanced error context (see `02-test-gaps-and-improvements.md`)

**Effort**: 3 hours

---

### 🟡 Medium Issues

#### 4. No Integrated Logging
**Problem**: Terraform logs and API logs are separate, hard to correlate.

**Impact**: Debugging is tedious, especially for timing issues.

**Proposed Solution**: Log aggregation script
```powershell
# tail-all-logs.ps1
# Tails both TF and API logs with timestamps

param(
    [string]$Demo = "01-simple-vm-new-auto"
)

$tfLogPath = "demo/$Demo/terraform.log"
$apiLogPath = "../hyperv-mgmt-api-v2/logs/api.log"

# Start tailing both logs with merge-sort by timestamp
Get-Content $tfLogPath, $apiLogPath -Wait | 
    Sort-Object @{Expression={$_.Substring(0,23)}} |
    ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "WARN") {
            Write-Host $_ -ForegroundColor Yellow
        } else {
            Write-Host $_
        }
    }
```

**Effort**: 2 hours

---

#### 5. Manual API Management
**Problem**: Developer must remember to start/stop API separately.

**Impact**: Forgotten API server = confusing test failures.

**Proposed Solution**: Automatic API management in test scripts
```powershell
# In Test.ps1, add auto-start/stop
param([switch]$AutoManageApi)

if ($AutoManageApi) {
    Write-Host "Starting API..." -ForegroundColor Cyan
    & ../scripts/Run-ApiForExample.ps1 -Action start
    
    try {
        # Run tests...
    } finally {
        Write-Host "Stopping API..." -ForegroundColor Cyan
        & ../scripts/Run-ApiForExample.ps1 -Action stop
    }
}
```

**Effort**: 1 hour

---

#### 6. No Quick Sanity Check
**Problem**: No fast way to verify basic functionality after code changes.

**Impact**: Developer runs full test suite unnecessarily.

**Proposed Solution**: `smoke-test.ps1`
```powershell
# smoke-test.ps1 - 30-second sanity check

# 1. Build provider (fast)
go build -o bin/terraform-provider-hypervapiv2.exe

# 2. Verify binary works
$version = & bin/terraform-provider-hypervapiv2.exe --version
if ($LASTEXITCODE -ne 0) {
    Write-Error "Provider binary not working"
    exit 1
}

# 3. Run minimal Go unit tests
go test ./internal/... -short -v

# 4. Optionally: quick API health check
$response = Invoke-RestMethod -Uri "http://localhost:5006/api/v2/vms" -ErrorAction SilentlyContinue
if ($response) {
    Write-Host "✓ API reachable" -ForegroundColor Green
}

Write-Host "`n✓ Smoke test passed" -ForegroundColor Green
```

**Effort**: 1 hour

---

### 🟢 Low Priority Issues

#### 7. No IDE Integration Hints
**Problem**: No `.vscode/` settings for optimal Go development.

**Impact**: Developers don't get auto-formatting, linting hints.

**Proposed Solution**: `.vscode/settings.json`
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
    "**/.terraform.lock.hcl": true
  }
}
```

**Effort**: 30 minutes

---

#### 8. No Contribution Guide
**Problem**: No CONTRIBUTING.md explaining workflow.

**Impact**: New contributors don't know how to start.

**Proposed Solution**: `CONTRIBUTING.md`
- Setup instructions
- Development workflow
- Testing guidelines
- PR checklist

**Effort**: 2 hours

---

## Comparison: Current vs. Ideal DX

### Current State

| Task | Steps | Time | Pain Points |
|------|-------|------|-------------|
| **First-time Setup** | 8-10 manual commands | 10 min | No automation |
| **Build + Test** | 3 commands, 2 dir changes | 3 min | Manual rebuild |
| **Debug Failure** | 7 steps, multiple tools | 20 min | Poor error messages |
| **API Management** | Manual start/stop | 1 min | Easy to forget |

---

### Ideal State (After Improvements)

| Task | Steps | Time | Improvements |
|------|-------|------|--------------|
| **First-time Setup** | `./setup.ps1` | 5 min | ✅ Automated |
| **Build + Test** | `./dev-test.ps1 <demo>` | 1.5 min | ✅ Auto-rebuild, faster tests |
| **Debug Failure** | Check unified log + structured error | 5 min | ✅ Clear errors, single log view |
| **API Management** | `./test.ps1 -AutoApi` | 0 min | ✅ Transparent |

---

## Recommended DX Improvements

### Phase 1: Foundation (Week 1) - 8 hours

| Task | Effort | Benefit |
|------|--------|---------|
| **Create setup.ps1** | 2h | One-command setup |
| **Add smoke-test.ps1** | 1h | Fast feedback |
| **Improve Test.ps1 errors** | 3h | Easier debugging |
| **Add .vscode/settings.json** | 30m | Better IDE experience |
| **Write CONTRIBUTING.md** | 2h | Onboard contributors |

**Expected Impact**: 50% reduction in setup time, 30% faster debug cycle.

---

### Phase 2: Automation (Week 2) - 7 hours

| Task | Effort | Benefit |
|------|--------|---------|
| **Add watch mode** | 3h | Auto-rebuild on changes |
| **Auto-manage API in tests** | 1h | One less thing to remember |
| **Add log aggregation** | 2h | Unified debugging view |
| **Create dev-test.ps1** | 1h | One-command dev cycle |

**Expected Impact**: 40% faster iteration cycle, less context switching.

---

### Phase 3: Polish (Week 3) - 5 hours

| Task | Effort | Benefit |
|------|--------|---------|
| **Add structured test output** | 3h | Better CI/CD integration |
| **Create DX dashboard** | 2h | Visual feedback on test status |

**Expected Impact**: Better visibility, easier CI/CD debugging.

---

## Developer Personas

### 1. New Contributor
**Goals**: Understand codebase, make first contribution

**Current Experience**: 😐
- Setup is unclear (no single guide)
- Multiple README files to read
- Unclear where to start

**After Improvements**: 😊
- Run `setup.ps1` → working environment in 5 min
- Read CONTRIBUTING.md for workflow
- Run smoke test to verify setup

---

### 2. Core Developer
**Goals**: Implement features quickly, debug efficiently

**Current Experience**: 😐
- Rebuild + test cycle is 2-3 minutes (too slow)
- Debugging requires manual log correlation
- Easy to forget to restart API after changes

**After Improvements**: 😊
- Watch mode auto-rebuilds on save
- Unified log view shows TF + API logs
- Auto-managed API (no manual start/stop)

---

### 3. QA/Tester
**Goals**: Run full test suite, track results

**Current Experience**: 😐
- Must manually run 19 demos
- No structured test results
- Hard to see trends over time

**After Improvements**: 😊
- `run-all-tests.ps1 -Tags critical` for filtered runs
- JSON test results for tracking
- Test dashboard shows pass/fail trends

---

## Metrics for Success

### Current State (Baseline)

- **First-time setup**: 10 minutes, 10 commands
- **Dev iteration cycle**: 3 minutes (rebuild + test)
- **Debug time**: 20+ minutes (poor error messages)
- **Test suite runtime**: 30-45 minutes (all demos)
- **Contributor onboarding**: ~1 hour to first test

---

### Target State (After Improvements)

- **First-time setup**: 5 minutes, 1 command (50% faster)
- **Dev iteration cycle**: 1.5 minutes (50% faster)
- **Debug time**: 5-10 minutes (70% faster)
- **Test suite runtime**: 30 minutes (no change, but better visibility)
- **Contributor onboarding**: ~15 minutes (75% faster)

---

## Summary

### Current DX Score: 6/10

**Strengths**:
- ✅ Consistent demo pattern
- ✅ Dev override workflow
- ✅ API management helper

**Weaknesses**:
- ❌ No automated setup
- ❌ Slow feedback loop
- ❌ Poor error messages
- ❌ Manual API management

---

### Recommended Priorities

**Must Have** (Phase 1):
1. ✅ `setup.ps1` (one-command setup)
2. ✅ `smoke-test.ps1` (fast sanity check)
3. ✅ Better error messages
4. ✅ `CONTRIBUTING.md`

**Should Have** (Phase 2):
1. ✅ Watch mode (auto-rebuild)
2. ✅ Auto-managed API
3. ✅ Log aggregation

**Nice to Have** (Phase 3):
1. Structured test output
2. DX dashboard

**Total Effort**: ~20 hours across 3 weeks

**Expected ROI**: Developer productivity increases by 40-50%, contributor onboarding time reduced by 75%.
