$ErrorActionPreference = 'Stop'

# Test API
Write-Host "Testing API..." -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/whoami" -Method Get
Write-Host "API OK - User: $($response.userName)" -ForegroundColor Green

# Create parent template
$parentPath = "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"
if (-not (Test-Path $parentPath)) {
    Write-Host "Creating parent template via API..." -ForegroundColor Yellow
    $tempVmName = "temp-parent-$(Get-Random)"
    $tempPath = "C:\Temp\HyperV-Test\Templates\temp.vhdx"

    $body = @{
        name = $tempVmName
        generation = 2
        cpuCount = 1
        memoryMB = 512
        newVhdPath = $tempPath
        newVhdSizeGB = 10
        vhdType = "Dynamic"
    } | ConvertTo-Json

    $result = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/vms" -Method Post -Body $body -ContentType "application/json"
    Write-Host "VM created: $($result.success)" -ForegroundColor Green

    Stop-VM -Name $tempVmName -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $tempVmName -Force
    Move-Item -Path $tempPath -Destination $parentPath -Force
    Write-Host "Parent template created!" -ForegroundColor Green
} else {
    Write-Host "Parent template exists" -ForegroundColor Green
}

Write-Host "Setup complete!" -ForegroundColor Cyan
