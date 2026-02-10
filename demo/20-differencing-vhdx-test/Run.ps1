#Requires -Version 5.1

<#
.SYNOPSIS
    Run differencing VHDX Terraform test
.DESCRIPTION
    Builds the provider (if requested) and applies the Terraform configuration
#>

[CmdletBinding()]
param(
    [switch]$BuildProvider,
    [switch]$SkipSetup
)

$ErrorActionPreference = 'Stop'
$demoDir = $PSScriptRoot
$repoRoot = Split-Path (Split-Path $demoDir -Parent) -Parent

Write-Host "=== Differencing VHDX Terraform Test ===" -ForegroundColor Cyan
Write-Host ""

# Check if setup was run
if (-not $SkipSetup) {
    $parentVhdx = "C:\Temp\HyperV-Test\Templates\parent-dynamic.vhdx"
    if (-not (Test-Path $parentVhdx)) {
        Write-Host "ERROR: Parent template not found!" -ForegroundColor Red
        Write-Host "Please run: .\Setup.ps1" -ForegroundColor Yellow
        exit 1
    }
}

# Build provider if requested
if ($BuildProvider) {
    Write-Host "Building Terraform provider..." -ForegroundColor Yellow
    Push-Location $repoRoot
    try {
        $binDir = Join-Path $repoRoot "bin"
        if (-not (Test-Path $binDir)) {
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        }

        $env:GOOS = "windows"
        $env:GOARCH = "amd64"

        Write-Host "  go build -o bin\terraform-provider-hypervapiv2.exe" -ForegroundColor Gray
        go build -o "bin\terraform-provider-hypervapiv2.exe"

        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code $LASTEXITCODE"
        }

        Write-Host "  Build successful!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

# Setup Terraform dev override
$tfDevFile = Join-Path $env:APPDATA "terraform.rc"
$providerPath = Join-Path $repoRoot "bin"
$devOverride = @"
provider_installation {
  dev_overrides {
    "local/vinitsiriya/hypervapiv2" = "$($providerPath -replace '\\', '/')"
  }
  direct {}
}
"@

Write-Host "Configuring Terraform dev override..." -ForegroundColor Yellow
Set-Content -Path $tfDevFile -Value $devOverride -Force
Write-Host "  Created: $tfDevFile" -ForegroundColor Gray
Write-Host ""

# Initialize and apply Terraform
Push-Location $demoDir
try {
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init
    Write-Host ""

    Write-Host "Planning Terraform changes..." -ForegroundColor Yellow
    terraform plan -out=tfplan
    Write-Host ""

    Write-Host "Applying Terraform configuration..." -ForegroundColor Yellow
    terraform apply tfplan
    Write-Host ""

    Write-Host "=== Terraform Apply Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run '.\Test.ps1' to verify the VMs and VHDXs" -ForegroundColor Cyan
}
finally {
    Pop-Location
}
