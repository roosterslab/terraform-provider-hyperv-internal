#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Test Windows OS Demo Full deployment
#>

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Testing Windows OS Demo Full" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$vmName = "win-demo-full"
$passed = 0
$failed = 0

# Test 1: VM Exists
Write-Host "[Test 1] VM exists..." -ForegroundColor Yellow
try {
    $vm = Get-VM -Name $vmName -ErrorAction Stop
    Write-Host "  PASS - VM found" -ForegroundColor Green
    $passed++
} catch {
    Write-Host "  FAIL - VM not found" -ForegroundColor Red
    $failed++
    exit 1
}

# Test 2: VM Configuration
Write-Host ""
Write-Host "[Test 2] VM configuration..." -ForegroundColor Yellow
if ($vm.ProcessorCount -ge 4) {
    Write-Host "  PASS - CPU count: $($vm.ProcessorCount)" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAIL - CPU count too low: $($vm.ProcessorCount)" -ForegroundColor Red
    $failed++
}

if ($vm.MemoryAssigned -ge 7GB) {
    Write-Host "  PASS - Memory: $([math]::Round($vm.MemoryAssigned/1GB,2))GB" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAIL - Memory too low: $([math]::Round($vm.MemoryAssigned/1GB,2))GB" -ForegroundColor Red
    $failed++
}

# Test 3: OS Disk (Differencing)
Write-Host ""
Write-Host "[Test 3] OS disk (differencing)..." -ForegroundColor Yellow
$osPath = "C:\HyperV\VHDX\Users\Demo\$vmName-os.vhdx"

if (Test-Path $osPath) {
    Write-Host "  PASS - OS disk exists" -ForegroundColor Green
    $passed++

    $osVhd = Get-VHD -Path $osPath
    if ($osVhd.VhdType -eq "Differencing") {
        Write-Host "  PASS - Disk type: Differencing" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  FAIL - Disk type: $($osVhd.VhdType) (expected Differencing)" -ForegroundColor Red
        $failed++
    }

    if ($osVhd.ParentPath) {
        Write-Host "  PASS - Parent path: $($osVhd.ParentPath)" -ForegroundColor Green
        $passed++

        if (Test-Path $osVhd.ParentPath) {
            Write-Host "  PASS - Parent template exists" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  FAIL - Parent template not found" -ForegroundColor Red
            $failed++
        }
    } else {
        Write-Host "  FAIL - No parent path set" -ForegroundColor Red
        $failed++
    }

    Write-Host "  INFO - OS disk size: $([math]::Round($osVhd.FileSize/1MB,2))MB" -ForegroundColor Cyan
} else {
    Write-Host "  FAIL - OS disk not found: $osPath" -ForegroundColor Red
    $failed++
}

# Test 4: Data Disk (Dynamic)
Write-Host ""
Write-Host "[Test 4] Data disk (dynamic)..." -ForegroundColor Yellow
$dataPath = "C:\HyperV\VHDX\Users\Demo\$vmName-data.vhdx"

if (Test-Path $dataPath) {
    Write-Host "  PASS - Data disk exists" -ForegroundColor Green
    $passed++

    $dataVhd = Get-VHD -Path $dataPath
    if ($dataVhd.VhdType -eq "Dynamic") {
        Write-Host "  PASS - Disk type: Dynamic" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  FAIL - Disk type: $($dataVhd.VhdType) (expected Dynamic)" -ForegroundColor Red
        $failed++
    }

    if ($dataVhd.Size -ge 99GB) {
        Write-Host "  PASS - Disk capacity: $([math]::Round($dataVhd.Size/1GB,2))GB" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  FAIL - Disk capacity too small: $([math]::Round($dataVhd.Size/1GB,2))GB" -ForegroundColor Red
        $failed++
    }

    Write-Host "  INFO - Data disk size: $([math]::Round($dataVhd.FileSize/1MB,2))MB" -ForegroundColor Cyan
} else {
    Write-Host "  FAIL - Data disk not found: $dataPath" -ForegroundColor Red
    $failed++
}

# Test 5: VM Disks Attached
Write-Host ""
Write-Host "[Test 5] VM disk attachments..." -ForegroundColor Yellow
$disks = Get-VMHardDiskDrive -VMName $vmName
if ($disks.Count -ge 2) {
    Write-Host "  PASS - Found $($disks.Count) disk(s) attached" -ForegroundColor Green
    $passed++

    foreach ($disk in $disks) {
        Write-Host "    - $($disk.Path)" -ForegroundColor Cyan
    }
} else {
    Write-Host "  FAIL - Expected 2+ disks, found $($disks.Count)" -ForegroundColor Red
    $failed++
}

# Test 6: SecureBoot
Write-Host ""
Write-Host "[Test 6] SecureBoot configuration..." -ForegroundColor Yellow
$firmware = Get-VMFirmware -VMName $vmName
if ($firmware.SecureBoot -eq "On") {
    Write-Host "  PASS - SecureBoot enabled" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAIL - SecureBoot not enabled" -ForegroundColor Red
    $failed++
}

if ($firmware.SecureBootTemplate -eq "MicrosoftWindows") {
    Write-Host "  PASS - SecureBoot template: MicrosoftWindows" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  INFO - SecureBoot template: $($firmware.SecureBootTemplate)" -ForegroundColor Cyan
}

# Test 7: TPM
Write-Host ""
Write-Host "[Test 7] TPM configuration..." -ForegroundColor Yellow
try {
    $tpm = Get-VMSecurity -VMName $vmName
    if ($tpm.TpmEnabled) {
        Write-Host "  PASS - TPM enabled" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  FAIL - TPM not enabled" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host "  FAIL - Could not check TPM status" -ForegroundColor Red
    $failed++
}

# Test 8: Network Adapter
Write-Host ""
Write-Host "[Test 8] Network configuration..." -ForegroundColor Yellow
$adapters = Get-VMNetworkAdapter -VMName $vmName
if ($adapters.Count -gt 0) {
    Write-Host "  PASS - Found $($adapters.Count) network adapter(s)" -ForegroundColor Green
    $passed++

    foreach ($adapter in $adapters) {
        Write-Host "    - Switch: $($adapter.SwitchName)" -ForegroundColor Cyan
    }
} else {
    Write-Host "  FAIL - No network adapters found" -ForegroundColor Red
    $failed++
}

# Storage Efficiency Test
Write-Host ""
Write-Host "[Bonus] Storage efficiency..." -ForegroundColor Yellow

if ((Test-Path $osPath) -and (Test-Path $dataPath)) {
    $osVhd = Get-VHD -Path $osPath
    $dataVhd = Get-VHD -Path $dataPath
    $parentVhd = Get-VHD -Path $osVhd.ParentPath

    $actualSize = $osVhd.FileSize + $dataVhd.FileSize
    $logicalSize = $osVhd.Size + $dataVhd.Size
    $savings = (1 - $actualSize / $logicalSize) * 100

    Write-Host "  Actual usage: $([math]::Round($actualSize/1GB,2))GB" -ForegroundColor Cyan
    Write-Host "  Logical capacity: $([math]::Round($logicalSize/1GB,2))GB" -ForegroundColor Cyan
    Write-Host "  Efficiency: $([math]::Round($savings,1))% space saved" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host "Ready to use:" -ForegroundColor Yellow
    Write-Host "  Start-VM -Name '$vmName'" -ForegroundColor Gray
    Write-Host "  vmconnect.exe localhost '$vmName'" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
