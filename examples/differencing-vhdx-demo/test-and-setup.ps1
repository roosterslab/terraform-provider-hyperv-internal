# Test API and create parent template
$ErrorActionPreference = 'Stop'

Write-Host "=== Testing Differencing VHDX Demo ===" -ForegroundColor Cyan
Write-Host ""

# Test API
Write-Host "1. Testing API connection..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/whoami" -Method Get
    Write-Host "  ✓ API is responding" -ForegroundColor Green
    Write-Host "  User: $($response.userName)" -ForegroundColor Cyan
    Write-Host "  Groups: $($response.groups -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "  ✗ API is not responding: $_" -ForegroundColor Red
    Write-Host "  Please start the API first:" -ForegroundColor Yellow
    Write-Host "    cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\hyperv-mgmt-api-v2" -ForegroundColor Gray
    Write-Host "    dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Create parent template using API
Write-Host "2. Creating parent template..." -ForegroundColor Yellow

$parentPath = "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"

if (Test-Path $parentPath) {
    Write-Host "  - Parent template already exists" -ForegroundColor Gray
    try {
        $vhd = Get-VHD -Path $parentPath
        Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Cyan
        Write-Host "    Size: $([math]::Round($vhd.Size / 1GB, 2)) GB" -ForegroundColor Cyan
        Write-Host "    File Size: $([math]::Round($vhd.FileSize / 1MB, 2)) MB" -ForegroundColor Cyan
    } catch {
        Write-Host "  ⚠ Could not read VHD info (may need admin): $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Creating temp VM to generate parent VHDX..." -ForegroundColor Gray

    $tempVmName = "temp-parent-creator-$(Get-Random)"
    $tempPath = "C:\Temp\HyperV-Test\Templates\temp-for-parent.vhdx"

    try {
        # Create a VM using the API (this will create the VHDX)
        $createRequest = @{
            name = $tempVmName
            generation = 2
            cpuCount = 1
            memoryMB = 512
            newVhdPath = $tempPath
            newVhdSizeGB = 10
            vhdType = "Dynamic"
        } | ConvertTo-Json

        Write-Host "  Creating temp VM..." -ForegroundColor Gray
        $response = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/vms" -Method Post -Body $createRequest -ContentType "application/json"

        if ($response.success) {
            Write-Host "  ✓ Temp VM created" -ForegroundColor Green

            # Stop the VM
            Write-Host "  Stopping VM..." -ForegroundColor Gray
            Stop-VM -Name $tempVmName -Force -ErrorAction SilentlyContinue

            # Remove the VM (but keep the VHDX)
            Write-Host "  Removing VM..." -ForegroundColor Gray
            Remove-VM -Name $tempVmName -Force

            # Rename the VHDX to be our parent template
            Write-Host "  Renaming VHDX to parent template..." -ForegroundColor Gray
            Move-Item -Path $tempPath -Destination $parentPath -Force

            Write-Host "  ✓ Parent template created: $parentPath" -ForegroundColor Green

            $vhd = Get-VHD -Path $parentPath
            Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Cyan
            Write-Host "    Size: $([math]::Round($vhd.Size / 1GB, 2)) GB" -ForegroundColor Cyan
            Write-Host "    File Size: $([math]::Round($vhd.FileSize / 1MB, 2)) MB" -ForegroundColor Cyan
        } else {
            Write-Host "  ✗ Failed to create temp VM: $($response.message)" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "  ✗ Error creating parent template: $_" -ForegroundColor Red
        # Cleanup
        Stop-VM -Name $tempVmName -Force -ErrorAction SilentlyContinue
        Remove-VM -Name $tempVmName -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

Write-Host ""

# Check Go
Write-Host "3. Checking Go installation..." -ForegroundColor Yellow
try {
    $goVersion = go version 2>&1
    Write-Host "  ✓ Go is installed: $goVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Go is not installed" -ForegroundColor Red
    Write-Host "  Please install Go from: https://go.dev/dl/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Build Terraform provider
Write-Host "4. Building Terraform provider..." -ForegroundColor Yellow
Push-Location "C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2"
try {
    go build -o terraform-provider-hypervapiv2.exe
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Provider built successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Provider build failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""

# Check Terraform
Write-Host "5. Checking Terraform..." -ForegroundColor Yellow
try {
    $tfVersion = terraform version 2>&1 | Select-Object -First 1
    Write-Host "  ✓ Terraform is installed: $tfVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Terraform is not installed" -ForegroundColor Red
    Write-Host "  Please install Terraform from: https://www.terraform.io/downloads" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terraform-provider-hypervapi-v2\examples\differencing-vhdx-demo" -ForegroundColor Gray
Write-Host "  terraform init" -ForegroundColor Gray
Write-Host "  terraform plan" -ForegroundColor Gray
Write-Host "  terraform apply" -ForegroundColor Gray
Write-Host ""
