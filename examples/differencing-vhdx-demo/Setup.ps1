#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Setup parent templates and directories for differencing VHDX demo
.DESCRIPTION
    Creates the parent VHDX template and directory structure needed for the Terraform example
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Differencing VHDX Demo Setup ===" -ForegroundColor Cyan
Write-Host ""

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor Yellow

$dirs = @(
    "C:\Temp\HyperV-Test\Templates"
    "C:\Temp\HyperV-Test\Demo"
    "C:\Temp\HyperV-Test\Demo\VDI"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✓ Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  - Already exists: $dir" -ForegroundColor Gray
    }
}

Write-Host ""

# Create parent template
$parentPath = "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"

Write-Host "Creating parent template..." -ForegroundColor Yellow

if (Test-Path $parentPath) {
    Write-Host "  - Parent template already exists: $parentPath" -ForegroundColor Gray

    $vhd = Get-VHD -Path $parentPath
    Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Gray
    Write-Host "    Size: $([math]::Round($vhd.Size / 1GB, 2)) GB" -ForegroundColor Gray
    Write-Host "    File Size: $([math]::Round($vhd.FileSize / 1MB, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "  Creating new parent VHDX (10GB Dynamic)..." -ForegroundColor Yellow

    New-VHD -Path $parentPath -SizeBytes 10GB -Dynamic | Out-Null

    Write-Host "  ✓ Parent template created: $parentPath" -ForegroundColor Green

    $vhd = Get-VHD -Path $parentPath
    Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Cyan
    Write-Host "    Size: $([math]::Round($vhd.Size / 1GB, 2)) GB" -ForegroundColor Cyan
    Write-Host "    File Size: $([math]::Round($vhd.FileSize / 1MB, 2)) MB" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Ensure the HyperV Management API is running:" -ForegroundColor White
Write-Host "     cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\hyperv-mgmt-api-v2" -ForegroundColor Gray
Write-Host "     dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Build the Terraform provider (if not already done):" -ForegroundColor White
Write-Host "     cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2" -ForegroundColor Gray
Write-Host "     go build -o terraform-provider-hypervapiv2.exe" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Run the Terraform example:" -ForegroundColor White
Write-Host "     terraform init" -ForegroundColor Gray
Write-Host "     terraform plan" -ForegroundColor Gray
Write-Host "     terraform apply" -ForegroundColor Gray
Write-Host ""
Write-Host "Optional: Install OS on parent template" -ForegroundColor Yellow
Write-Host "  To create a bootable parent template, mount the VHDX, install Windows," -ForegroundColor Gray
Write-Host "  then sysprep it for cloning. See README.md for detailed instructions." -ForegroundColor Gray
Write-Host ""
