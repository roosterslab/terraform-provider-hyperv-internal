#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Finalize Windows parent template
.DESCRIPTION
    After installing Windows and running sysprep, this script:
    - Removes the temporary VM
    - Moves the VHDX to the parent template location
    - Verifies the template is ready
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Finalizing Windows Parent Template" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$tempVmName = "temp-windows-installer"
$tempVhdPath = "C:\HyperV\VHDX\Users\Templates\temp-installer.vhdx"
$parentPath = "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"

# Check temp VM
Write-Host "[1/3] Checking temporary VM..." -ForegroundColor Yellow
$vm = Get-VM -Name $tempVmName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "  ERROR - Temporary VM not found: $tempVmName" -ForegroundColor Red
    Write-Host "  Did you run Setup-ParentTemplate.ps1 first?" -ForegroundColor Yellow
    exit 1
}

if ($vm.State -ne "Off") {
    Write-Host "  WARNING - VM is not off (State: $($vm.State))" -ForegroundColor Yellow
    Write-Host "  Did you run sysprep /shutdown?" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Force shutdown and continue? (y/N)"
    if ($continue -ne "y") {
        Write-Host "Cancelled" -ForegroundColor Red
        exit 1
    }
    Stop-VM -Name $tempVmName -Force
    Start-Sleep -Seconds 2
}

Write-Host "  OK - VM is off" -ForegroundColor Green

# Check VHDX
if (-not (Test-Path $tempVhdPath)) {
    Write-Host "  ERROR - VHDX not found: $tempVhdPath" -ForegroundColor Red
    exit 1
}

$vhd = Get-VHD -Path $tempVhdPath
Write-Host "  VHDX Size: $([math]::Round($vhd.FileSize/1GB,2))GB" -ForegroundColor Cyan

# Remove VM
Write-Host ""
Write-Host "[2/3] Removing temporary VM..." -ForegroundColor Yellow
Remove-VM -Name $tempVmName -Force
Write-Host "  OK - VM removed" -ForegroundColor Green

# Move VHDX to parent location
Write-Host ""
Write-Host "[3/3] Creating parent template..." -ForegroundColor Yellow

if (Test-Path $parentPath) {
    Write-Host "  WARNING - Parent template already exists" -ForegroundColor Yellow
    $replace = Read-Host "Replace? (y/N)"
    if ($replace -ne "y") {
        Write-Host "Cancelled" -ForegroundColor Red
        exit 1
    }
    Remove-Item $parentPath -Force
}

Move-Item $tempVhdPath $parentPath -Force
Write-Host "  OK - Template created: $parentPath" -ForegroundColor Green

# Verify
$parent = Get-VHD -Path $parentPath
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Parent Template Ready!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Template Details:" -ForegroundColor Cyan
Write-Host "  Path: $parentPath" -ForegroundColor Gray
Write-Host "  Type: $($parent.VhdType)" -ForegroundColor Gray
Write-Host "  Size: $([math]::Round($parent.Size/1GB,2))GB" -ForegroundColor Gray
Write-Host "  File Size: $([math]::Round($parent.FileSize/1GB,2))GB" -ForegroundColor Gray
Write-Host ""
Write-Host "READY TO USE!" -ForegroundColor Green
Write-Host ""
Write-Host "Run the demo:" -ForegroundColor Yellow
Write-Host "  .\Run.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use with Terraform:" -ForegroundColor Yellow
Write-Host "  C:\terraform\terraform.exe apply" -ForegroundColor Gray
Write-Host ""
