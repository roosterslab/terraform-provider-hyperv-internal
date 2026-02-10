#Requires -Version 5.1

<#
.SYNOPSIS
    Destroy test VMs and cleanup
.DESCRIPTION
    Uses Terraform to destroy all test VMs and optionally cleans up test files
#>

[CmdletBinding()]
param(
    [switch]$CleanupAll
)

$ErrorActionPreference = 'Stop'
$demoDir = $PSScriptRoot

Write-Host "=== Destroying Differencing VHDX Test VMs ===" -ForegroundColor Cyan
Write-Host ""

# Destroy Terraform resources
Push-Location $demoDir
try {
    Write-Host "Running terraform destroy..." -ForegroundColor Yellow
    terraform destroy -auto-approve

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Terraform destroy completed" -ForegroundColor Green
    } else {
        Write-Host "⚠ Terraform destroy had errors" -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}

Write-Host ""

# Optional cleanup of test files
if ($CleanupAll) {
    Write-Host "Cleaning up test directories..." -ForegroundColor Yellow

    $testRoot = "C:\Temp\HyperV-Test"
    $dirs = @(
        "$testRoot\Diff"
        "$testRoot\Fixed"
        "$testRoot\Dynamic"
    )

    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Write-Host "  Removing: $dir" -ForegroundColor Gray
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "✓ Cleanup complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Parent templates in $testRoot\Templates were preserved" -ForegroundColor Cyan
    Write-Host "      Run with -CleanupTemplates to remove them as well" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
