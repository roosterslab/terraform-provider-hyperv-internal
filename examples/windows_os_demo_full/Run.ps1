#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Run Windows OS Demo Full with Differencing Disks
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows OS Demo Full - Differencing VHDXs" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow

# Check API
try {
    $vms = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/vms" -Method Get
    Write-Host "  OK - API is running" -ForegroundColor Green
} catch {
    Write-Host "  ERROR - API not responding" -ForegroundColor Red
    Write-Host "  Start API: cd hyperv-mgmt-api-v2; dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj" -ForegroundColor Yellow
    exit 1
}

# Check parent template
$parentPath = "C:\HyperV\VHDX\Users\Templates\windows-base.vhdx"
if (Test-Path $parentPath) {
    $vhd = Get-VHD -Path $parentPath
    Write-Host "  OK - Parent template exists" -ForegroundColor Green
    Write-Host "    Type: $($vhd.VhdType), Size: $([math]::Round($vhd.Size/1GB,2))GB" -ForegroundColor Cyan
} else {
    Write-Host "  WARNING - Parent template not found: $parentPath" -ForegroundColor Yellow
    Write-Host "  Creating demo parent template..." -ForegroundColor Gray

    # Create a demo parent template (empty - user needs to install Windows)
    New-Item -ItemType Directory -Path "C:\HyperV\VHDX\Users\Templates" -Force | Out-Null
    New-VHD -Path $parentPath -SizeBytes 40GB -Dynamic | Out-Null

    Write-Host "  OK - Demo parent created (empty - install Windows manually)" -ForegroundColor Green
}

# Check Terraform
Write-Host ""
Write-Host "[2/5] Checking Terraform..." -ForegroundColor Yellow
if (Test-Path "C:\terraform\terraform.exe") {
    $tfVer = & "C:\terraform\terraform.exe" version 2>&1 | Select-Object -First 1
    Write-Host "  OK - $tfVer" -ForegroundColor Green
} else {
    Write-Host "  ERROR - Terraform not found at C:\terraform\terraform.exe" -ForegroundColor Red
    exit 1
}

# Check Provider
Write-Host ""
Write-Host "[3/5] Checking provider..." -ForegroundColor Yellow
$providerPath = "C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2\terraform-provider-hypervapiv2.exe"
if (Test-Path $providerPath) {
    Write-Host "  OK - Provider built" -ForegroundColor Green
} else {
    Write-Host "  Provider not found - attempting to build..." -ForegroundColor Yellow
    Push-Location "C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2"

    try {
        & go build -o terraform-provider-hypervapiv2.exe 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK - Provider built successfully" -ForegroundColor Green
        } else {
            Write-Host "  ERROR - Provider build failed (Go required)" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    } catch {
        Write-Host "  ERROR - Go not installed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Pop-Location
}

# Setup dev override
$tfDir = "$env:APPDATA\terraform.d"
New-Item -ItemType Directory -Path $tfDir -Force | Out-Null

$devOverride = @"
provider_installation {
  dev_overrides {
    "local/vinitsiriya/hypervapiv2" = "C:/Users/globql-ws/Documents/projects/hyperv-management-api-dev/terraform-provider-hypervapi-v2"
  }
  direct {}
}
"@
$devOverride | Set-Content "$tfDir\terraformrc"

# Initialize Terraform
Write-Host ""
Write-Host "[4/5] Initializing Terraform..." -ForegroundColor Yellow
& "C:\terraform\terraform.exe" init 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK - Terraform initialized" -ForegroundColor Green
} else {
    Write-Host "  ERROR - Terraform init failed" -ForegroundColor Red
    exit 1
}

# Apply
Write-Host ""
Write-Host "[5/5] Creating Windows VM..." -ForegroundColor Yellow
Write-Host "  This will create:" -ForegroundColor Gray
Write-Host "    - VM: win-demo-full" -ForegroundColor Gray
Write-Host "    - OS Disk: Differencing from parent template" -ForegroundColor Gray
Write-Host "    - Data Disk: 100GB Dynamic" -ForegroundColor Gray
Write-Host ""

& "C:\terraform\terraform.exe" apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  VM Created Successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""

    # Show VM details
    $vm = Get-VM -Name "win-demo-full" -ErrorAction SilentlyContinue
    if ($vm) {
        Write-Host "VM Details:" -ForegroundColor Yellow
        Write-Host "  Name: $($vm.Name)" -ForegroundColor Cyan
        Write-Host "  State: $($vm.State)" -ForegroundColor Cyan
        Write-Host "  CPU: $($vm.ProcessorCount)" -ForegroundColor Cyan
        Write-Host "  Memory: $([math]::Round($vm.MemoryAssigned/1GB,2))GB" -ForegroundColor Cyan
        Write-Host ""

        # Show disk details
        $osVhd = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-os.vhdx" -ErrorAction SilentlyContinue
        if ($osVhd) {
            Write-Host "OS Disk:" -ForegroundColor Yellow
            Write-Host "  Type: $($osVhd.VhdType)" -ForegroundColor Cyan
            Write-Host "  Parent: $($osVhd.ParentPath)" -ForegroundColor Cyan
            Write-Host "  Size: $([math]::Round($osVhd.FileSize/1MB,2))MB" -ForegroundColor Cyan
        }

        $dataVhd = Get-VHD "C:\HyperV\VHDX\Users\Demo\win-demo-full-data.vhdx" -ErrorAction SilentlyContinue
        if ($dataVhd) {
            Write-Host ""
            Write-Host "Data Disk:" -ForegroundColor Yellow
            Write-Host "  Type: $($dataVhd.VhdType)" -ForegroundColor Cyan
            Write-Host "  Size: $([math]::Round($dataVhd.FileSize/1MB,2))MB" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  Start VM:  Start-VM -Name 'win-demo-full'" -ForegroundColor Gray
        Write-Host "  Connect:   vmconnect.exe localhost 'win-demo-full'" -ForegroundColor Gray
        Write-Host "  Test:      .\Test.ps1" -ForegroundColor Gray
        Write-Host "  Cleanup:   .\Destroy.ps1" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "ERROR - Terraform apply failed" -ForegroundColor Red
    exit 1
}
