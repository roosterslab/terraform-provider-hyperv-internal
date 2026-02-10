#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Cleanup differencing VHDX demo resources
.DESCRIPTION
    Destroys Terraform resources and optionally cleans up test files
#>

[CmdletBinding()]
param(
    [switch]$KeepParent,
    [switch]$RemoveAll
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Differencing VHDX Demo Cleanup ===" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "main.tf")) {
    Write-Host "Error: main.tf not found. Please run from the example directory." -ForegroundColor Red
    exit 1
}

# Destroy Terraform resources
if (Test-Path ".terraform") {
    Write-Host "Destroying Terraform resources..." -ForegroundColor Yellow

    try {
        terraform destroy -auto-approve

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Terraform resources destroyed" -ForegroundColor Green
        } else {
            Write-Host "⚠ Terraform destroy completed with warnings" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠ Error during terraform destroy: $_" -ForegroundColor Yellow
        Write-Host "  Continuing with manual cleanup..." -ForegroundColor Gray
    }
} else {
    Write-Host "- No Terraform state found, skipping terraform destroy" -ForegroundColor Gray
}

Write-Host ""

# Manual VM cleanup (in case Terraform didn't catch everything)
Write-Host "Checking for remaining VMs..." -ForegroundColor Yellow

$vms = Get-VM | Where-Object { $_.Name -like "demo-diff-*" }

if ($vms) {
    Write-Host "  Found $($vms.Count) VM(s) to clean up" -ForegroundColor Yellow

    foreach ($vm in $vms) {
        Write-Host "    Removing: $($vm.Name)" -ForegroundColor Gray

        # Stop if running
        if ($vm.State -ne "Off") {
            Stop-VM -Name $vm.Name -Force -ErrorAction SilentlyContinue
        }

        # Remove VM
        Remove-VM -Name $vm.Name -Force -ErrorAction SilentlyContinue
    }

    Write-Host "  ✓ VMs removed" -ForegroundColor Green
} else {
    Write-Host "  - No VMs found" -ForegroundColor Gray
}

Write-Host ""

# Cleanup child VHDXs
if ($RemoveAll) {
    Write-Host "Removing all test files (including parent template)..." -ForegroundColor Yellow

    if (Test-Path "C:\Temp\HyperV-Test") {
        Remove-Item "C:\Temp\HyperV-Test" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed C:\Temp\HyperV-Test" -ForegroundColor Green
    }
} else {
    Write-Host "Removing child VHDXs..." -ForegroundColor Yellow

    $dirs = @(
        "C:\Temp\HyperV-Test\Demo"
    )

    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            $vhdxFiles = Get-ChildItem -Path $dir -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue

            if ($vhdxFiles) {
                foreach ($file in $vhdxFiles) {
                    Write-Host "    Removing: $($file.FullName)" -ForegroundColor Gray
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                }
                Write-Host "  ✓ Removed $($vhdxFiles.Count) child VHDX file(s)" -ForegroundColor Green
            } else {
                Write-Host "  - No child VHDXs found" -ForegroundColor Gray
            }
        }
    }

    if (-not $KeepParent) {
        Write-Host ""
        Write-Host "Removing parent template..." -ForegroundColor Yellow

        $parentPath = "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"

        if (Test-Path $parentPath) {
            Remove-Item $parentPath -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed parent template" -ForegroundColor Green
        } else {
            Write-Host "  - Parent template not found" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "Parent template preserved:" -ForegroundColor Cyan
        Write-Host "  C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
Write-Host ""

if ($RemoveAll) {
    Write-Host "All demo resources have been removed." -ForegroundColor Cyan
} elseif ($KeepParent) {
    Write-Host "Demo VMs and child VHDXs removed. Parent template preserved for reuse." -ForegroundColor Cyan
} else {
    Write-Host "All demo resources removed." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Yellow
Write-Host "  .\Cleanup.ps1                # Remove everything including parent" -ForegroundColor Gray
Write-Host "  .\Cleanup.ps1 -KeepParent    # Remove VMs/children, keep parent template" -ForegroundColor Gray
Write-Host "  .\Cleanup.ps1 -RemoveAll     # Remove entire C:\Temp\HyperV-Test directory" -ForegroundColor Gray
Write-Host ""
