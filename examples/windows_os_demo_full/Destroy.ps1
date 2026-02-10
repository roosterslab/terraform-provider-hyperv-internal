#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Destroy Windows OS Demo Full deployment
#>

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Destroying Windows OS Demo Full" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$vmName = "win-demo-full"

# Check if VM exists
Write-Host "[1/3] Checking VM status..." -ForegroundColor Yellow
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if ($vm) {
    Write-Host "  Found VM: $vmName (State: $($vm.State))" -ForegroundColor Cyan

    # Stop VM if running
    if ($vm.State -ne "Off") {
        Write-Host "  Stopping VM..." -ForegroundColor Gray
        Stop-VM -Name $vmName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
} else {
    Write-Host "  No VM found" -ForegroundColor Gray
}

# Run Terraform destroy
Write-Host ""
Write-Host "[2/3] Running Terraform destroy..." -ForegroundColor Yellow

if (Test-Path ".terraform") {
    & "C:\terraform\terraform.exe" destroy -auto-approve

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK - Terraform destroy completed" -ForegroundColor Green
    } else {
        Write-Host "  WARNING - Terraform destroy had issues" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No Terraform state found" -ForegroundColor Gray
}

# Manual cleanup (belt and suspenders)
Write-Host ""
Write-Host "[3/3] Manual cleanup..." -ForegroundColor Yellow

# Remove VM if still exists
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "  Removing VM..." -ForegroundColor Gray
    Stop-VM -Name $vmName -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $vmName -Force -ErrorAction SilentlyContinue
    Write-Host "  OK - VM removed" -ForegroundColor Green
} else {
    Write-Host "  VM already removed" -ForegroundColor Gray
}

# Remove VHDXs
$osPath = "C:\HyperV\VHDX\Users\Demo\$vmName-os.vhdx"
$dataPath = "C:\HyperV\VHDX\Users\Demo\$vmName-data.vhdx"

if (Test-Path $osPath) {
    Write-Host "  Removing OS disk..." -ForegroundColor Gray
    Remove-Item $osPath -Force -ErrorAction SilentlyContinue
    Write-Host "  OK - OS disk removed" -ForegroundColor Green
} else {
    Write-Host "  OS disk already removed" -ForegroundColor Gray
}

if (Test-Path $dataPath) {
    Write-Host "  Removing data disk..." -ForegroundColor Gray
    Remove-Item $dataPath -Force -ErrorAction SilentlyContinue
    Write-Host "  OK - Data disk removed" -ForegroundColor Green
} else {
    Write-Host "  Data disk already removed" -ForegroundColor Gray
}

# Verify cleanup
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Cleanup Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
$osExists = Test-Path $osPath
$dataExists = Test-Path $dataPath

if (-not $vm -and -not $osExists -and -not $dataExists) {
    Write-Host "ALL CLEANED UP!" -ForegroundColor Green
    Write-Host "  VM: Removed" -ForegroundColor Green
    Write-Host "  OS Disk: Removed" -ForegroundColor Green
    Write-Host "  Data Disk: Removed" -ForegroundColor Green
} else {
    Write-Host "Cleanup status:" -ForegroundColor Yellow
    Write-Host "  VM: $(if ($vm) { 'Still exists' } else { 'Removed' })" -ForegroundColor $(if ($vm) { "Red" } else { "Green" })
    Write-Host "  OS Disk: $(if ($osExists) { 'Still exists' } else { 'Removed' })" -ForegroundColor $(if ($osExists) { "Red" } else { "Green" })
    Write-Host "  Data Disk: $(if ($dataExists) { 'Still exists' } else { 'Removed' })" -ForegroundColor $(if ($dataExists) { "Red" } else { "Green" })
}

Write-Host ""
Write-Host "Note: Parent template preserved at:" -ForegroundColor Cyan
Write-Host "  C:\HyperV\VHDX\Users\Templates\windows-base.vhdx" -ForegroundColor Gray
Write-Host ""
