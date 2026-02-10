# Workspace Cleanup Plan — Prepare for New Testing Strategy

**Date**: December 3, 2025  
**Goal**: Reorganize workspace to transition from old demo scripts to new harness-based testing  
**Strategy**: Move old files to archive, prepare clean structure for new implementation

---

## Overview

Before implementing the new testing strategy, we need to:
1. **Archive old testing infrastructure** (don't delete yet - keep for reference)
2. **Clean up current workspace** (remove generated files, organize docs)
3. **Prepare new directory structure** (create placeholders for harness)
4. **Update references** (point to new locations)

**Philosophy**: Keep old code accessible but clearly separated from new implementation.

---

## Phase 1: Archive Current Testing Infrastructure (1 hour)

### What Gets Moved to `old/`

```
terraform-provider-hypervapi-v2/
├── old/                                    # NEW: Archive directory
│   ├── demo-scripts/                       # OLD: Per-demo Test.ps1/Run.ps1/Destroy.ps1
│   │   ├── 01-simple-vm-new-auto/
│   │   │   ├── Run.ps1
│   │   │   ├── Test.ps1
│   │   │   └── Destroy.ps1
│   │   ├── 02-vm-windows-perfect/
│   │   │   ├── Run.ps1
│   │   │   ├── Test.ps1
│   │   │   └── Destroy.ps1
│   │   └── ...                             # All 19 demos
│   ├── docs/                               # OLD: Previous testing docs
│   │   ├── testing-execution-guide.instructions.md
│   │   └── dx_and_test_update/             # Previous analysis
│   └── README.md                           # Explains what's in old/
```

### Step-by-Step Commands

```powershell
# 1. Create archive directory
New-Item -ItemType Directory -Path "old"
New-Item -ItemType Directory -Path "old/demo-scripts"
New-Item -ItemType Directory -Path "old/docs"

# 2. Copy (don't move yet) demo scripts to archive
$demos = Get-ChildItem -Path "demos" -Directory
foreach ($demo in $demos) {
    $demoName = $demo.Name
    $destDir = "old/demo-scripts/$demoName"
    
    New-Item -ItemType Directory -Path $destDir -Force
    
    # Copy PowerShell scripts only (keep main.tf in demos/)
    Get-ChildItem -Path "demos/$demoName" -Filter "*.ps1" | ForEach-Object {
        Copy-Item $_.FullName -Destination $destDir
    }
}

# 3. Move old testing docs to archive
Move-Item "agent/testing-execution-guide.instructions.md" -Destination "old/docs/"
Move-Item "plans/dx_and_test_update" -Destination "old/docs/"

# 4. Create README explaining archive
@"
# Old Testing Infrastructure Archive

**Date Archived**: December 3, 2025  
**Reason**: Transitioning to new DRY harness-based testing strategy

## Contents

### demo-scripts/
Original per-demo PowerShell scripts (Run.ps1, Test.ps1, Destroy.ps1) for all 19 demos.

**Status**: ARCHIVED - Do not modify  
**Use**: Reference only during migration  
**Delete**: After new harness is validated (Phase 3 complete)

### docs/
Previous testing documentation and analysis:
- testing-execution-guide.instructions.md (old execution guide)
- dx_and_test_update/ (previous DX and testing analysis)

**Status**: ARCHIVED - Superseded by plans/new-testing-strategy/  
**Use**: Historical reference only

## Migration Status

- [ ] Phase 1: Harness built (Week 1)
- [ ] Phase 2: Pilot demos migrated (Week 2)
- [ ] Phase 3: All demos migrated (Week 3)
- [ ] Phase 4: Archive can be deleted (Week 4)

## Restoring Old Files

If migration fails and rollback is needed:

```powershell
# Restore demo scripts
`$demos = Get-ChildItem -Path "old/demo-scripts" -Directory
foreach (`$demo in `$demos) {
    Copy-Item "old/demo-scripts/`$(`$demo.Name)/*.ps1" -Destination "demos/`$(`$demo.Name)/"
}
```

**Last Updated**: December 3, 2025  
**Safe to Delete After**: Phase 4 complete + 1 week validation
"@ | Out-File "old/README.md"

Write-Host "✓ Archive created: old/" -ForegroundColor Green
```

---

## Phase 2: Clean Current Workspace (30 minutes)

### What Gets Deleted (Generated/Temporary Files)

```powershell
# Clean Terraform state and generated files
Get-ChildItem -Path "demos" -Recurse -Include `
    ".terraform", 
    ".terraform.lock.hcl", 
    "terraform.tfstate*", 
    "dev.tfrc", 
    "terraform.log", 
    "*.auto.tfvars" | Remove-Item -Recurse -Force

Write-Host "✓ Terraform generated files removed" -ForegroundColor Green

# Clean test results (if any exist)
Get-ChildItem -Path "demos" -Recurse -Include `
    "test-results.json", 
    "idempotency-check.log" | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "✓ Test result files removed" -ForegroundColor Green

# Clean build artifacts
Remove-Item "bin/*.exe" -Force -ErrorAction SilentlyContinue
Remove-Item ".api.pid" -Force -ErrorAction SilentlyContinue

Write-Host "✓ Build artifacts cleaned" -ForegroundColor Green
```

### What Stays in `demos/`

After cleanup, each demo should have:
```
demos/01-simple-vm-new-auto/
├── main.tf              # ✅ KEEP: Terraform config
└── README.md            # ✅ KEEP: Demo description (if exists)
```

**Removed**:
- ❌ `Run.ps1` (copied to old/, removed here)
- ❌ `Test.ps1` (copied to old/, removed here)
- ❌ `Destroy.ps1` (copied to old/, removed here)
- ❌ `.terraform/` (generated, deleted)
- ❌ `terraform.tfstate*` (generated, deleted)
- ❌ `dev.tfrc` (generated, deleted)

---

## Phase 3: Create New Directory Structure (30 minutes)

### New Testing Structure

```powershell
# Create new test infrastructure directories
$newDirs = @(
    "tests",
    "tests/harness",
    "tests/scenarios",
    "tests/scenarios/custom-validations",
    "tests/contract"
)

foreach ($dir in $newDirs) {
    New-Item -ItemType Directory -Path $dir -Force
    Write-Host "Created: $dir" -ForegroundColor Green
}

# Create placeholder README files

# tests/README.md
@"
# Testing Infrastructure

**Status**: 🚧 Under Construction (Phase 1)  
**Strategy**: See ../plans/new-testing-strategy/

## Structure

- **harness/** - Core test harness (PowerShell modules)
- **scenarios/** - Scenario registry and custom validations
- **contract/** - Go contract tests
- **run-all.ps1** - Main test runner (coming in Phase 1)
- **run-single.ps1** - Single scenario runner (coming in Phase 1)

## Migration Progress

- [ ] Phase 1: Build harness (Week 1)
- [ ] Phase 2: Migrate 3 pilot demos (Week 2)
- [ ] Phase 3: Migrate all 19 demos (Week 3)
- [ ] Phase 4: Add contract tests + CI/CD (Week 4)

## Usage (After Phase 1)

```powershell
# Run smoke tests
.\tests\run-all.ps1 -Tags smoke -AutoStartApi

# Run single scenario
.\tests\run-single.ps1 -Id "01-simple-vm-new-auto"

# Run full suite
.\tests\run-all.ps1 -Tags full -AutoStartApi
```

See plans/new-testing-strategy/ for complete documentation.
"@ | Out-File "tests/README.md"

# tests/harness/README.md
@"
# Test Harness Modules

**Status**: 🚧 To be implemented in Phase 1

## Modules

### HvTestHarness.psm1
Main orchestrator - Invoke-HvScenario function

### HvSteps.psm1
Individual test step implementations (Init, Apply, Validate, etc.)

### HvAssertions.psm1
Shared assertion library (Assert-HvVmExists, Assert-HvDiskExists, etc.)

### HvApiManagement.psm1
API lifecycle management (Start-HvApiIfNeeded, Stop-HvApi)

### HvHelpers.psm1
Utility functions (Write-HvLog, Initialize-HvDevOverride)

## Implementation

See plans/new-testing-strategy/03-harness-implementation.md for detailed design.
"@ | Out-File "tests/harness/README.md"

# tests/scenarios/README.md
@"
# Test Scenarios

**Status**: 🚧 To be created in Phase 2

## Files

### scenarios.json
Central registry of all test scenarios (will contain all 19 demos)

### custom-validations/
Optional scenario-specific validation scripts

## Schema

See plans/new-testing-strategy/04-scenarios-registry.md for schema definition and examples.
"@ | Out-File "tests/scenarios/README.md"

# tests/contract/README.md
@"
# Contract Tests

**Status**: 🚧 To be implemented in Phase 4

## Purpose

Test API client ↔ REST API wire format and compatibility.

## Implementation

```go
// client_test.go
func TestClientCreateVm(t *testing.T) {
    // Wire-level contract test
}
```

See plans/new-testing-strategy/02-migration-plan.md Phase 4 for details.
"@ | Out-File "tests/contract/README.md"

Write-Host "✓ New directory structure created" -ForegroundColor Green
```

---

## Phase 4: Update Documentation References (30 minutes)

### Files to Update

#### 1. Main README.md

```powershell
# Update terraform-provider-hypervapi-v2/README.md
# Add section pointing to new testing docs
```

**Add to README.md**:
```markdown
## Testing

**New Testing Strategy**: See [plans/new-testing-strategy/](./plans/new-testing-strategy/)

The provider uses a DRY harness-based testing approach:
- **Unit tests**: `go test ./internal/...`
- **Contract tests**: `go test ./tests/contract/...` (Phase 4)
- **E2E scenarios**: `pwsh tests/run-all.ps1 -Tags <smoke|critical|full>`

For detailed testing guide, see [tests/README.md](./tests/README.md).

**Old demo scripts**: Archived in `old/demo-scripts/` during migration.
```

#### 2. DEVELOPER.md

**Update testing section** to reference new strategy:
```markdown
## Running Tests

### Quick Start

```powershell
# Run smoke tests (fast, ~2 min)
.\tests\run-all.ps1 -Tags smoke -AutoStartApi

# Run critical tests (PR gate, ~10 min)
.\tests\run-all.ps1 -Tags critical -AutoStartApi
```

For complete testing documentation, see [plans/new-testing-strategy/](./plans/new-testing-strategy/).

**Note**: Migration to new harness in progress. See `old/demo-scripts/` for legacy scripts.
```

#### 3. agent/README.md

**Create or update** to point to new docs:
```markdown
# Agent Instructions — Testing

**Status**: 🚧 Migrating to new testing strategy

## Current State

- **New strategy**: See plans/new-testing-strategy/
- **Old scripts**: Archived in old/demo-scripts/
- **Migration plan**: plans/new-testing-strategy/02-migration-plan.md

## For Agents

When working on testing:
1. Reference new-testing-strategy/ for current approach
2. Do NOT modify scripts in old/demo-scripts/
3. Implement harness modules in tests/harness/
4. Add scenarios to tests/scenarios/scenarios.json

See plans/new-testing-strategy/README.md for complete guide.
```

---

## Phase 5: Git Operations (15 minutes)

### Commit Strategy

**Important**: Commit in logical chunks, not all at once.

```powershell
# Commit 1: Archive old files
git add old/
git commit -m "Archive old testing infrastructure to old/

- Copied all demo scripts (Test.ps1, Run.ps1, Destroy.ps1) to old/demo-scripts/
- Moved old testing docs to old/docs/
- Added old/README.md explaining archive
- Files kept for reference during migration
- Will be deleted after Phase 4 validation"

# Commit 2: Clean workspace
git add demos/
git commit -m "Clean workspace: remove generated files

- Removed .terraform directories
- Removed terraform.tfstate files
- Removed dev.tfrc files
- Removed terraform.log files
- Kept only main.tf and README.md in each demo"

# Commit 3: Create new structure
git add tests/
git commit -m "Create new testing infrastructure structure

- Created tests/harness/ (modules, to be implemented)
- Created tests/scenarios/ (registry, to be implemented)
- Created tests/contract/ (Go tests, Phase 4)
- Added README.md files explaining each directory
- Structure ready for Phase 1 implementation"

# Commit 4: Update documentation
git add README.md DEVELOPER.md agent/
git commit -m "Update documentation to reference new testing strategy

- Updated main README.md with testing section
- Updated DEVELOPER.md with new test commands
- Updated agent/README.md to point to new docs
- All references now point to plans/new-testing-strategy/"

# Commit 5: Add new testing strategy plans (if not already committed)
git add plans/new-testing-strategy/
git commit -m "Add comprehensive new testing strategy documentation

- 01-overview.md: Executive summary and architecture
- 02-migration-plan.md: 4-week implementation plan
- 03-harness-implementation.md: Technical design
- 04-scenarios-registry.md: Scenario schema and examples
- 05-custom-validations.md: Extensibility guide
- README.md: Documentation index

New DRY approach replaces 19 duplicated scripts with harness + data"
```

---

## Complete Cleanup Script

**File**: `cleanup-workspace.ps1`

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
Prepare workspace for new testing strategy implementation

.DESCRIPTION
Archives old testing infrastructure, cleans generated files, and creates new directory structure.
Run this before starting Phase 1 of the migration plan.

.PARAMETER DryRun
Show what would be done without making changes

.PARAMETER SkipArchive
Skip archiving old demo scripts (use if already done)
#>
param(
    [switch]$DryRun,
    [switch]$SkipArchive
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Workspace Cleanup for New Testing Strategy" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Phase 1: Archive old files
if (-not $SkipArchive) {
    Write-Host "[Phase 1] Archiving old testing infrastructure..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create: old/demo-scripts/" -ForegroundColor Gray
        Write-Host "  [DRY RUN] Would copy: demos/*/{{Run,Test,Destroy}}.ps1 -> old/demo-scripts/" -ForegroundColor Gray
        Write-Host "  [DRY RUN] Would move: agent/testing-execution-guide.instructions.md -> old/docs/" -ForegroundColor Gray
        Write-Host "  [DRY RUN] Would move: plans/dx_and_test_update -> old/docs/" -ForegroundColor Gray
    } else {
        # Create archive structure
        New-Item -ItemType Directory -Path "old" -Force | Out-Null
        New-Item -ItemType Directory -Path "old/demo-scripts" -Force | Out-Null
        New-Item -ItemType Directory -Path "old/docs" -Force | Out-Null
        
        # Copy demo scripts
        $demos = Get-ChildItem -Path "demos" -Directory
        foreach ($demo in $demos) {
            $demoName = $demo.Name
            $destDir = "old/demo-scripts/$demoName"
            
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            
            Get-ChildItem -Path "demos/$demoName" -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName -Destination $destDir
                Write-Host "  ✓ Copied: $demoName/$($_.Name)" -ForegroundColor Green
            }
        }
        
        # Move old docs
        if (Test-Path "agent/testing-execution-guide.instructions.md") {
            Move-Item "agent/testing-execution-guide.instructions.md" -Destination "old/docs/"
            Write-Host "  ✓ Moved: testing-execution-guide.instructions.md" -ForegroundColor Green
        }
        
        if (Test-Path "plans/dx_and_test_update") {
            Move-Item "plans/dx_and_test_update" -Destination "old/docs/"
            Write-Host "  ✓ Moved: dx_and_test_update/" -ForegroundColor Green
        }
        
        # Create archive README
        $archiveReadme = @"
# Old Testing Infrastructure Archive

**Date Archived**: $(Get-Date -Format "yyyy-MM-dd")
**Reason**: Transitioning to new DRY harness-based testing strategy

See plans/new-testing-strategy/ for new approach.

Safe to delete after Phase 4 validation (Week 4).
"@
        $archiveReadme | Out-File "old/README.md"
        Write-Host "  ✓ Created: old/README.md" -ForegroundColor Green
    }
    Write-Host "  Phase 1 complete`n" -ForegroundColor Green
}

# Phase 2: Clean workspace
Write-Host "[Phase 2] Cleaning generated files..." -ForegroundColor Yellow

if ($DryRun) {
    $toClean = Get-ChildItem -Path "demos" -Recurse -Include ".terraform", "*.tfstate*", "dev.tfrc", "terraform.log"
    Write-Host "  [DRY RUN] Would delete $($toClean.Count) files" -ForegroundColor Gray
} else {
    $cleaned = 0
    
    # Clean Terraform generated files
    Get-ChildItem -Path "demos" -Recurse -Include ".terraform" | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force
        $cleaned++
    }
    
    Get-ChildItem -Path "demos" -Recurse -Include `
        ".terraform.lock.hcl", "terraform.tfstate*", "dev.tfrc", "terraform.log", "*.auto.tfvars" |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            $cleaned++
        }
    
    Write-Host "  ✓ Removed $cleaned generated files" -ForegroundColor Green
}
Write-Host "  Phase 2 complete`n" -ForegroundColor Green

# Phase 3: Create new structure
Write-Host "[Phase 3] Creating new testing structure..." -ForegroundColor Yellow

$newDirs = @(
    "tests",
    "tests/harness",
    "tests/scenarios",
    "tests/scenarios/custom-validations",
    "tests/contract"
)

if ($DryRun) {
    Write-Host "  [DRY RUN] Would create: $($newDirs -join ', ')" -ForegroundColor Gray
} else {
    foreach ($dir in $newDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  ✓ Created: $dir" -ForegroundColor Green
        }
    }
    
    # Create README files (abbreviated here, full content above)
    if (-not (Test-Path "tests/README.md")) {
        "# Testing Infrastructure`n`nSee ../plans/new-testing-strategy/" | Out-File "tests/README.md"
        Write-Host "  ✓ Created: tests/README.md" -ForegroundColor Green
    }
}
Write-Host "  Phase 3 complete`n" -ForegroundColor Green

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n⚠️  DRY RUN MODE - No changes made" -ForegroundColor Yellow
    Write-Host "`nRun without -DryRun to apply changes:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-workspace.ps1`n" -ForegroundColor White
} else {
    Write-Host "`n✅ Workspace cleaned and ready for Phase 1" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Review changes: git status" -ForegroundColor White
    Write-Host "  2. Commit in phases (see Phase 5 in cleanup plan)" -ForegroundColor White
    Write-Host "  3. Start Phase 1: Build harness" -ForegroundColor White
    Write-Host "  4. See: plans/new-testing-strategy/02-migration-plan.md`n" -ForegroundColor White
}
```

---

## Verification Checklist

After running cleanup, verify:

### Archive Check
- [ ] `old/demo-scripts/` contains all 19 demo directories
- [ ] Each demo in `old/demo-scripts/` has Test.ps1, Run.ps1, Destroy.ps1
- [ ] `old/docs/` contains old testing documentation
- [ ] `old/README.md` exists and explains archive

### Demos Clean Check
- [ ] Each `demos/*/` directory has ONLY main.tf (and optional README.md)
- [ ] No .terraform directories in demos/
- [ ] No terraform.tfstate files in demos/
- [ ] No dev.tfrc files in demos/
- [ ] No Test.ps1/Run.ps1/Destroy.ps1 in demos/

### New Structure Check
- [ ] `tests/` directory exists
- [ ] `tests/harness/` directory exists with README.md
- [ ] `tests/scenarios/` directory exists with README.md
- [ ] `tests/scenarios/custom-validations/` directory exists
- [ ] `tests/contract/` directory exists with README.md

### Documentation Check
- [ ] Main README.md references new testing strategy
- [ ] DEVELOPER.md has updated testing section
- [ ] agent/ has updated references

---

## Rollback Plan

If cleanup causes issues:

```powershell
# Restore demo scripts from archive
$demos = Get-ChildItem -Path "old/demo-scripts" -Directory
foreach ($demo in $demos) {
    Copy-Item "old/demo-scripts/$($demo.Name)/*.ps1" -Destination "demos/$($demo.Name)/"
}

# Restore old docs
Copy-Item "old/docs/testing-execution-guide.instructions.md" -Destination "agent/"
Copy-Item "old/docs/dx_and_test_update" -Destination "plans/" -Recurse

# Remove new structure if needed
Remove-Item "tests" -Recurse -Force

Write-Host "✓ Rollback complete" -ForegroundColor Green
```

---

## Timeline

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Archive old files | 1 hour | ⏳ Not started |
| 2 | Clean workspace | 30 min | ⏳ Not started |
| 3 | Create new structure | 30 min | ⏳ Not started |
| 4 | Update documentation | 30 min | ⏳ Not started |
| 5 | Git commits | 15 min | ⏳ Not started |
| **Total** | | **2h 45min** | |

---

## Next Steps After Cleanup

1. ✅ Run cleanup script: `.\cleanup-workspace.ps1`
2. ✅ Verify with checklist above
3. ✅ Commit changes (5 commits, see Phase 5)
4. 🚀 **Start Phase 1**: Build harness (see plans/new-testing-strategy/02-migration-plan.md)

---

**Ready to start?**
```powershell
# Preview changes first
.\cleanup-workspace.ps1 -DryRun

# Apply cleanup
.\cleanup-workspace.ps1

# Verify
git status
```
