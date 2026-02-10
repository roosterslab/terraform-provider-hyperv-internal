#!/usr/bin/env pwsh
param(
    [switch]$DryRun,
    [switch]$SkipArchive
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workspace Cleanup for New Testing Strategy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Phase 1: Archive
if (-not $SkipArchive) {
    Write-Host "[Phase 1] Archiving old testing infrastructure..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create: old/demo-scripts/" -ForegroundColor Gray
        Write-Host "  [DRY RUN] Would create: old/docs/" -ForegroundColor Gray
        $demos = Get-ChildItem -Path "demos" -Directory -ErrorAction SilentlyContinue
        $scriptCount = 0
        foreach ($demo in $demos) {
            $scripts = Get-ChildItem -Path "demos/$($demo.Name)" -Filter "*.ps1" -ErrorAction SilentlyContinue
            $scriptCount += $scripts.Count
        }
        Write-Host "  [DRY RUN] Total: $scriptCount PowerShell scripts to archive" -ForegroundColor Gray
        if (Test-Path "agent/testing-execution-guide.instructions.md") {
            Write-Host "  [DRY RUN] Would move: agent/testing-execution-guide.instructions.md" -ForegroundColor Gray
        }
        if (Test-Path "plans/dx_and_test_update") {
            Write-Host "  [DRY RUN] Would move: plans/dx_and_test_update" -ForegroundColor Gray
        }
    } else {
        New-Item -ItemType Directory -Path "old" -Force | Out-Null
        New-Item -ItemType Directory -Path "old/demo-scripts" -Force | Out-Null
        New-Item -ItemType Directory -Path "old/docs" -Force | Out-Null
        Write-Host "  Created: old/" -ForegroundColor Green
        
        $demos = Get-ChildItem -Path "demos" -Directory -ErrorAction SilentlyContinue
        $copiedCount = 0
        foreach ($demo in $demos) {
            $scripts = Get-ChildItem -Path "demos/$($demo.Name)" -Filter "*.ps1" -ErrorAction SilentlyContinue
            if ($scripts.Count -gt 0) {
                $destDir = "old/demo-scripts/$($demo.Name)"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                foreach ($script in $scripts) {
                    Copy-Item $script.FullName -Destination $destDir
                    $copiedCount++
                }
            }
        }
        Write-Host "  Archived $copiedCount PowerShell scripts" -ForegroundColor Green
        
        if (Test-Path "agent/testing-execution-guide.instructions.md") {
            Move-Item "agent/testing-execution-guide.instructions.md" -Destination "old/docs/" -Force
        }
        if (Test-Path "plans/dx_and_test_update") {
            Move-Item "plans/dx_and_test_update" -Destination "old/docs/" -Force
        }
        
        $date = Get-Date -Format "yyyy-MM-dd"
        "# Old Testing Infrastructure Archive" | Out-File "old/README.md"
        "" | Out-File "old/README.md" -Append
        "Date Archived: $date" | Out-File "old/README.md" -Append
        "Reason: Transitioning to new DRY harness-based testing strategy" | Out-File "old/README.md" -Append
        Write-Host "  Created: old/README.md" -ForegroundColor Green
    }
    Write-Host "  Phase 1 complete" -ForegroundColor Green
    Write-Host ""
}

# Phase 2: Clean
Write-Host "[Phase 2] Cleaning generated files..." -ForegroundColor Yellow

if ($DryRun) {
    $terraformDirs = Get-ChildItem -Path "demos" -Recurse -Directory -Filter ".terraform" -ErrorAction SilentlyContinue
    $terraformFiles = Get-ChildItem -Path "demos" -Recurse -Include ".terraform.lock.hcl","terraform.tfstate*","dev.tfrc","terraform.log" -ErrorAction SilentlyContinue
    $totalClean = $terraformDirs.Count + $terraformFiles.Count
    Write-Host "  [DRY RUN] Would delete $totalClean generated files/directories" -ForegroundColor Gray
} else {
    $cleaned = 0
    $terraformDirs = Get-ChildItem -Path "demos" -Recurse -Directory -Filter ".terraform" -ErrorAction SilentlyContinue
    foreach ($dir in $terraformDirs) {
        Remove-Item $dir.FullName -Recurse -Force
        $cleaned++
    }
    $terraformFiles = Get-ChildItem -Path "demos" -Recurse -Include ".terraform.lock.hcl","terraform.tfstate*","dev.tfrc","terraform.log" -ErrorAction SilentlyContinue
    foreach ($file in $terraformFiles) {
        Remove-Item $file.FullName -Force
        $cleaned++
    }
    Write-Host "  Removed $cleaned generated files/directories" -ForegroundColor Green
}
Write-Host "  Phase 2 complete" -ForegroundColor Green
Write-Host ""

# Phase 3: Create new structure
Write-Host "[Phase 3] Creating new testing structure..." -ForegroundColor Yellow

$newDirs = @("tests","tests/harness","tests/scenarios","tests/scenarios/custom-validations","tests/contract")

if ($DryRun) {
    foreach ($dir in $newDirs) {
        if (-not (Test-Path $dir)) {
            Write-Host "  [DRY RUN] Would create: $dir" -ForegroundColor Gray
        }
    }
} else {
    foreach ($dir in $newDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  Created: $dir" -ForegroundColor Green
        }
    }
    
    if (-not (Test-Path "tests/README.md")) {
        "# Testing Infrastructure" | Out-File "tests/README.md"
        "" | Out-File "tests/README.md" -Append
        "See ../plans/new-testing-strategy/ for complete documentation." | Out-File "tests/README.md" -Append
    }
    if (-not (Test-Path "tests/harness/README.md")) {
        "# Test Harness Modules" | Out-File "tests/harness/README.md"
        "" | Out-File "tests/harness/README.md" -Append
        "See plans/new-testing-strategy/03-harness-implementation.md" | Out-File "tests/harness/README.md" -Append
    }
    if (-not (Test-Path "tests/scenarios/README.md")) {
        "# Test Scenarios" | Out-File "tests/scenarios/README.md"
        "" | Out-File "tests/scenarios/README.md" -Append
        "See plans/new-testing-strategy/04-scenarios-registry.md" | Out-File "tests/scenarios/README.md" -Append
    }
    if (-not (Test-Path "tests/contract/README.md")) {
        "# Contract Tests" | Out-File "tests/contract/README.md"
        "" | Out-File "tests/contract/README.md" -Append
        "See plans/new-testing-strategy/02-migration-plan.md Phase 4" | Out-File "tests/contract/README.md" -Append
    }
}
Write-Host "  Phase 3 complete" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run without -DryRun to apply changes:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-workspace.ps1" -ForegroundColor White
} else {
    Write-Host "Workspace cleaned and ready for Phase 1" -ForegroundColor Green
    Write-Host ""
    Write-Host "What changed:" -ForegroundColor Cyan
    Write-Host "  - Old demo scripts archived to: old/demo-scripts/" -ForegroundColor White
    Write-Host "  - Old docs moved to: old/docs/" -ForegroundColor White
    Write-Host "  - Generated files removed from demos/" -ForegroundColor White
    Write-Host "  - New testing structure created: tests/" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review changes: git status" -ForegroundColor White
    Write-Host "  2. Commit changes" -ForegroundColor White
    Write-Host "  3. Start Phase 1: Build harness" -ForegroundColor White
    Write-Host "  4. See: plans/new-testing-strategy/02-migration-plan.md" -ForegroundColor White
}
Write-Host ""
