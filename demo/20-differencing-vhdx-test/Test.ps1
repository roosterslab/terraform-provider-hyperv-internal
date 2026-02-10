#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Test and verify differencing VHDX implementation
.DESCRIPTION
    Verifies that VMs were created correctly and VHDXs have the right types and parent references
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== Differencing VHDX Test Verification ===" -ForegroundColor Cyan
Write-Host ""

$testResults = @()

function Test-VM {
    param(
        [string]$Name,
        [string]$ExpectedVhdPath,
        [string]$ExpectedVhdType,
        [string]$ExpectedParentPath = $null
    )

    Write-Host "Testing VM: $Name" -ForegroundColor Yellow

    # Check if VM exists
    $vm = Get-VM -Name $Name -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "  ❌ FAIL: VM not found" -ForegroundColor Red
        return $false
    }
    Write-Host "  ✓ VM exists" -ForegroundColor Green

    # Check VHD
    if (-not (Test-Path $ExpectedVhdPath)) {
        Write-Host "  ❌ FAIL: VHDX not found: $ExpectedVhdPath" -ForegroundColor Red
        return $false
    }
    Write-Host "  ✓ VHDX exists: $ExpectedVhdPath" -ForegroundColor Green

    # Get VHD info
    $vhd = Get-VHD -Path $ExpectedVhdPath
    Write-Host "  VHD Type: $($vhd.VhdType)" -ForegroundColor Gray

    # Verify VHD type
    if ($vhd.VhdType -ne $ExpectedVhdType) {
        Write-Host "  ❌ FAIL: Expected VhdType=$ExpectedVhdType, got $($vhd.VhdType)" -ForegroundColor Red
        return $false
    }
    Write-Host "  ✓ VHD Type correct: $ExpectedVhdType" -ForegroundColor Green

    # Verify parent path for differencing disks
    if ($ExpectedVhdType -eq "Differencing") {
        if ([string]::IsNullOrEmpty($vhd.ParentPath)) {
            Write-Host "  ❌ FAIL: Differencing disk has no parent path" -ForegroundColor Red
            return $false
        }

        if ($ExpectedParentPath -and $vhd.ParentPath -ne $ExpectedParentPath) {
            Write-Host "  ❌ FAIL: Expected ParentPath=$ExpectedParentPath" -ForegroundColor Red
            Write-Host "           Got: $($vhd.ParentPath)" -ForegroundColor Red
            return $false
        }

        Write-Host "  ✓ Parent Path: $($vhd.ParentPath)" -ForegroundColor Green

        # Verify parent exists
        if (-not (Test-Path $vhd.ParentPath)) {
            Write-Host "  ❌ FAIL: Parent VHDX not found" -ForegroundColor Red
            return $false
        }
        Write-Host "  ✓ Parent VHDX exists" -ForegroundColor Green
    }

    # Check file size
    $fileSize = (Get-Item $ExpectedVhdPath).Length
    $fileSizeGB = [math]::Round($fileSize / 1GB, 2)
    Write-Host "  File Size: $fileSizeGB GB" -ForegroundColor Gray

    # For differencing disks, file should be small
    if ($ExpectedVhdType -eq "Differencing" -and $fileSizeGB -gt 1) {
        Write-Host "  ⚠ WARNING: Differencing disk is larger than expected" -ForegroundColor Yellow
    }

    Write-Host "  ✅ PASS: All checks passed" -ForegroundColor Green
    Write-Host ""
    return $true
}

# Test 1: Differencing disk (top-level attributes)
$test1 = Test-VM `
    -Name "tf-diff-test-01" `
    -ExpectedVhdPath "C:\Temp\HyperV-Test\Diff\child-dynamic.vhdx" `
    -ExpectedVhdType "Differencing" `
    -ExpectedParentPath "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"

$testResults += @{ Name = "Test 1: Differencing (top-level)"; Result = $test1 }

# Test 2: Fixed disk
$test2 = Test-VM `
    -Name "tf-fixed-test-01" `
    -ExpectedVhdPath "C:\Temp\HyperV-Test\Fixed\disk-fixed.vhdx" `
    -ExpectedVhdType "Fixed"

$testResults += @{ Name = "Test 2: Fixed disk"; Result = $test2 }

# Test 3: Dynamic disk (default)
$test3 = Test-VM `
    -Name "tf-dynamic-test-01" `
    -ExpectedVhdPath "C:\Temp\HyperV-Test\Dynamic\disk-dynamic.vhdx" `
    -ExpectedVhdType "Dynamic"

$testResults += @{ Name = "Test 3: Dynamic (default)"; Result = $test3 }

# Test 4: Differencing disk (disk{} block)
$test4 = Test-VM `
    -Name "tf-diff-test-02" `
    -ExpectedVhdPath "C:\Temp\HyperV-Test\Diff\child-block.vhdx" `
    -ExpectedVhdType "Differencing" `
    -ExpectedParentPath "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"

$testResults += @{ Name = "Test 4: Differencing (disk block)"; Result = $test4 }

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

foreach ($result in $testResults) {
    $status = if ($result.Result) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($result.Result) { "Green" } else { "Red" }

    Write-Host "$status - $($result.Name)" -ForegroundColor $color

    if ($result.Result) { $passCount++ } else { $failCount++ }
}

Write-Host ""
Write-Host "Total: $($testResults.Count) tests" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Differencing VHDX implementation is working correctly!" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}
