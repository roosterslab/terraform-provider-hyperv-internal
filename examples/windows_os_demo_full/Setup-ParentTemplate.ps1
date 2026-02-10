#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Helper script to create Windows parent template
.DESCRIPTION
    This script creates a basic parent VHDX and a temporary VM for installing Windows.
    After running this, you'll need to:
    1. Install Windows on the temp VM
    2. Install applications and configure settings
    3. Sysprep the installation
    4. Shutdown the VM
    5. Copy the VHDX to the templates directory
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Parent Template Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$parentPath = "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"
$tempVmName = "temp-windows-installer"
$tempVhdPath = "C:\HyperV\VHDX\Users\Templates\temp-installer.vhdx"

# Check if parent already exists
if (Test-Path $parentPath) {
    Write-Host "Parent template already exists: $parentPath" -ForegroundColor Yellow
    Write-Host ""
    $vhd = Get-VHD -Path $parentPath
    Write-Host "Current template:" -ForegroundColor Cyan
    Write-Host "  Type: $($vhd.VhdType)" -ForegroundColor Gray
    Write-Host "  Size: $([math]::Round($vhd.Size/1GB,2))GB" -ForegroundColor Gray
    Write-Host "  File Size: $([math]::Round($vhd.FileSize/1GB,2))GB" -ForegroundColor Gray
    Write-Host ""

    $replace = Read-Host "Replace existing template? (y/N)"
    if ($replace -ne "y") {
        Write-Host "Keeping existing template" -ForegroundColor Green
        exit 0
    }
}

# Create directories
Write-Host "[1/3] Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "C:\HyperV\VHDX\Users\Templates" -Force | Out-Null
Write-Host "  OK" -ForegroundColor Green

# Create VHDX
Write-Host ""
Write-Host "[2/3] Creating VHDX (40GB Dynamic)..." -ForegroundColor Yellow
New-VHD -Path $tempVhdPath -SizeBytes 40GB -Dynamic | Out-Null
Write-Host "  OK - VHDX created" -ForegroundColor Green

# Create temp VM for installation
Write-Host ""
Write-Host "[3/3] Creating temporary VM for Windows installation..." -ForegroundColor Yellow

New-VM -Name $tempVmName -Generation 2 -MemoryStartupBytes 4GB -VHDPath $tempVhdPath -SwitchName "Default Switch" | Out-Null
Set-VM -Name $tempVmName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false
Set-VMFirmware -VMName $tempVmName -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"
Enable-VMIntegrationService -VMName $tempVmName -Name "Guest Service Interface"

Write-Host "  OK - Temporary VM created" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Temporary VM created: $tempVmName" -ForegroundColor Cyan
Write-Host "VHDX location: $tempVhdPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Mount Windows ISO to the VM:" -ForegroundColor White
Write-Host "   Set-VMDvdDrive -VMName '$tempVmName' -Path 'C:\path\to\windows.iso'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Start the VM and install Windows:" -ForegroundColor White
Write-Host "   Start-VM -Name '$tempVmName'" -ForegroundColor Gray
Write-Host "   vmconnect.exe localhost '$tempVmName'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. After Windows installation:" -ForegroundColor White
Write-Host "   - Install Windows updates" -ForegroundColor Gray
Write-Host "   - Install applications (Office, browsers, dev tools, etc.)" -ForegroundColor Gray
Write-Host "   - Configure Windows settings" -ForegroundColor Gray
Write-Host "   - Remove temp files" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Sysprep the installation:" -ForegroundColor White
Write-Host "   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown" -ForegroundColor Gray
Write-Host ""
Write-Host "5. After shutdown, finalize the template:" -ForegroundColor White
Write-Host "   .\Finalize-Template.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "OR manually:" -ForegroundColor Yellow
Write-Host "   Remove-VM -Name '$tempVmName' -Force" -ForegroundColor Gray
Write-Host "   Move-Item '$tempVhdPath' '$parentPath' -Force" -ForegroundColor Gray
Write-Host ""
