#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Setup script for differencing VHDX testing
.DESCRIPTION
    Creates parent template VHDXs and necessary directories for testing
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Differencing VHDX Test Setup ===" -ForegroundColor Cyan

# Create test directories
$testRoot = "C:\Temp\HyperV-Test"
$dirs = @(
    "$testRoot\Templates"
    "$testRoot\Diff"
    "$testRoot\Fixed"
    "$testRoot\Dynamic"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        Write-Host "Creating directory: $dir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    } else {
        Write-Host "Directory exists: $dir" -ForegroundColor Green
    }
}

# Create parent template VHDXs for differencing disks
$parentDynamic = "$testRoot\Templates\parent-dynamic.vhdx"

if (-not (Test-Path $parentDynamic)) {
    Write-Host "Creating parent dynamic VHDX: $parentDynamic" -ForegroundColor Yellow
    New-VHD -Path $parentDynamic -SizeBytes 10GB -Dynamic | Out-Null
    Write-Host "  Created: 10GB Dynamic VHDX" -ForegroundColor Green
} else {
    Write-Host "Parent template exists: $parentDynamic" -ForegroundColor Green
    $vhd = Get-VHD -Path $parentDynamic
    Write-Host "  Type: $($vhd.VhdType), Size: $([math]::Round($vhd.Size/1GB, 2))GB" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Parent templates created:"
Write-Host "  - $parentDynamic" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run: .\Run.ps1 -BuildProvider" -ForegroundColor Yellow
