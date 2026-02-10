<#
.SYNOPSIS
    Setup script for Windows Full Deployment with Differencing VHDXs example

.DESCRIPTION
    This script prepares your environment for deploying the example:
    - Creates necessary directories
    - Creates parent VHDX template (if needed)
    - Validates prerequisites
    - Configures Terraform variables

.PARAMETER CreateTemplate
    Create a new parent VHDX template if it doesn't exist

.PARAMETER TemplateSize
    Size of the parent template (default: 127GB)

.PARAMETER SkipValidation
    Skip prerequisite validation

.EXAMPLE
    .\setup.ps1
    # Interactive setup with validation

.EXAMPLE
    .\setup.ps1 -CreateTemplate -TemplateSize 200GB
    # Create a 200GB parent template

.NOTES
    Requires: Administrator privileges, Hyper-V enabled
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$CreateTemplate,

    [Parameter()]
    [string]$TemplateSize = "127GB",

    [Parameter()]
    [switch]$SkipValidation
)

# Requires PowerShell 5.1 or later
#Requires -Version 5.1
#Requires -RunAsAdministrator

# ============================================
# Configuration
# ============================================
$ErrorActionPreference = "Stop"

$Config = @{
    TemplateDir = "C:\HyperV\VHDX\Users\templates"
    TemplatePath = "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx"
    VmDir = "C:\HyperV\VHDX\Users"
    ApiEndpoint = "http://localhost:5000"
    RequiredTerraformVersion = [Version]"1.5.0"
}

# ============================================
# Helper Functions
# ============================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n[$([DateTime]::Now.ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor White
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
}

function Test-HyperVInstalled {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
        return $feature.State -eq "Enabled"
    } catch {
        return $false
    }
}

function Test-APIRunning {
    param([string]$Endpoint)
    try {
        $response = Invoke-WebRequest -Uri "$Endpoint/api/v2/whoami" -UseBasicParsing -TimeoutSec 5
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Test-TerraformInstalled {
    try {
        $version = terraform version -json | ConvertFrom-Json
        $installedVersion = [Version]$version.terraform_version
        return $installedVersion -ge $Config.RequiredTerraformVersion
    } catch {
        return $false
    }
}

# ============================================
# Validation
# ============================================

if (-not $SkipValidation) {
    Write-Step "Validating Prerequisites"

    # Check Administrator
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run as Administrator"
        exit 1
    }
    Write-Success "Running as Administrator"

    # Check Hyper-V
    if (-not (Test-HyperVInstalled)) {
        Write-Error "Hyper-V is not installed or enabled"
        Write-Host "`nTo enable Hyper-V, run:" -ForegroundColor Cyan
        Write-Host "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor White
        exit 1
    }
    Write-Success "Hyper-V is installed and enabled"

    # Check Terraform
    if (-not (Test-TerraformInstalled)) {
        Write-Warning "Terraform $($Config.RequiredTerraformVersion) or later not found"
        Write-Host "`nInstall Terraform from: https://www.terraform.io/downloads" -ForegroundColor Cyan
    } else {
        Write-Success "Terraform is installed"
    }

    # Check API
    if (-not (Test-APIRunning -Endpoint $Config.ApiEndpoint)) {
        Write-Warning "HyperV Management API is not running at $($Config.ApiEndpoint)"
        Write-Host "`nStart the API with:" -ForegroundColor Cyan
        Write-Host "cd C:\path\to\hyperv-mgmt-api-v2" -ForegroundColor White
        Write-Host "dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj" -ForegroundColor White
    } else {
        Write-Success "HyperV Management API is running"
    }
}

# ============================================
# Directory Setup
# ============================================

Write-Step "Creating Directory Structure"

# Create template directory
if (-not (Test-Path $Config.TemplateDir)) {
    New-Item -ItemType Directory -Path $Config.TemplateDir -Force | Out-Null
    Write-Success "Created template directory: $($Config.TemplateDir)"
} else {
    Write-Success "Template directory exists: $($Config.TemplateDir)"
}

# Create VM directory
if (-not (Test-Path $Config.VmDir)) {
    New-Item -ItemType Directory -Path $Config.VmDir -Force | Out-Null
    Write-Success "Created VM directory: $($Config.VmDir)"
} else {
    Write-Success "VM directory exists: $($Config.VmDir)"
}

# ============================================
# Parent Template Setup
# ============================================

Write-Step "Checking Parent Template"

if (Test-Path $Config.TemplatePath) {
    $vhd = Get-VHD $Config.TemplatePath
    Write-Success "Parent template exists: $($Config.TemplatePath)"
    Write-Host "    Type: $($vhd.VhdType), Size: $([math]::Round($vhd.Size/1GB, 1))GB, Used: $([math]::Round($vhd.FileSize/1GB, 2))GB" -ForegroundColor Gray
} elseif ($CreateTemplate) {
    Write-Step "Creating Parent Template"

    $sizeBytes = Invoke-Expression $TemplateSize
    New-VHD -Path $Config.TemplatePath -SizeBytes $sizeBytes -Dynamic | Out-Null

    Write-Success "Created parent template: $($Config.TemplatePath)"
    Write-Host "    Size: $([math]::Round($sizeBytes/1GB, 1))GB" -ForegroundColor Gray

    Write-Warning "Template is empty - install Windows Server before deploying VMs"
    Write-Host "`nTo prepare the template:" -ForegroundColor Cyan
    Write-Host "1. Create a VM with this VHDX" -ForegroundColor White
    Write-Host "2. Install Windows Server 2022" -ForegroundColor White
    Write-Host "3. Install updates and common software" -ForegroundColor White
    Write-Host "4. Run sysprep /generalize /oobe /shutdown" -ForegroundColor White
    Write-Host "5. Use the generalized VHDX as your template" -ForegroundColor White
} else {
    Write-Warning "Parent template not found: $($Config.TemplatePath)"
    Write-Host "`nCreate a template with: .\setup.ps1 -CreateTemplate" -ForegroundColor Cyan
}

# ============================================
# Terraform Configuration
# ============================================

Write-Step "Configuring Terraform"

$tfVarsPath = Join-Path $PSScriptRoot "terraform.tfvars"
$tfVarsExample = Join-Path $PSScriptRoot "terraform.tfvars.example"

if (-not (Test-Path $tfVarsPath)) {
    if (Test-Path $tfVarsExample) {
        Copy-Item $tfVarsExample $tfVarsPath
        Write-Success "Created terraform.tfvars from example"

        # Update with detected values
        $content = Get-Content $tfVarsPath -Raw
        $content = $content -replace 'endpoint = ".*"', "endpoint = `"$($Config.ApiEndpoint)`""
        $content = $content -replace 'parent_vhdx_path = ".*"', "parent_vhdx_path = `"$($Config.TemplatePath -replace '\\', '/')`""
        $content | Set-Content $tfVarsPath -NoNewline

        Write-Success "Updated terraform.tfvars with detected configuration"
    } else {
        Write-Warning "terraform.tfvars.example not found"
    }
} else {
    Write-Success "terraform.tfvars already exists"
}

# ============================================
# Network Configuration
# ============================================

Write-Step "Checking Network Configuration"

try {
    $switches = Get-VMSwitch
    if ($switches.Count -eq 0) {
        Write-Warning "No virtual switches found"
        Write-Host "`nCreate a switch with:" -ForegroundColor Cyan
        Write-Host "New-VMSwitch -Name `"Default Switch`" -SwitchType Internal" -ForegroundColor White
    } else {
        Write-Success "Found $($switches.Count) virtual switch(es):"
        foreach ($switch in $switches) {
            Write-Host "    - $($switch.Name) ($($switch.SwitchType))" -ForegroundColor Gray
        }

        if ($switches.Name -notcontains "Default Switch") {
            Write-Warning "Update switch_name in terraform.tfvars to one of the above"
        }
    }
} catch {
    Write-Warning "Could not enumerate virtual switches"
}

# ============================================
# Summary
# ============================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Yellow

if (-not (Test-Path $Config.TemplatePath)) {
    Write-Host "1. Create parent template: " -NoNewline
    Write-Host ".\setup.ps1 -CreateTemplate" -ForegroundColor White
} elseif ((Get-VHD $Config.TemplatePath).FileSize -lt 1GB) {
    Write-Host "1. Install Windows Server on template VHDX" -ForegroundColor White
}

if (-not (Test-APIRunning -Endpoint $Config.ApiEndpoint)) {
    Write-Host "2. Start HyperV Management API" -ForegroundColor White
}

Write-Host "3. Review and customize: " -NoNewline
Write-Host "terraform.tfvars" -ForegroundColor White

Write-Host "4. Initialize Terraform: " -NoNewline
Write-Host "terraform init" -ForegroundColor White

Write-Host "5. Review the plan: " -NoNewline
Write-Host "terraform plan" -ForegroundColor White

Write-Host "6. Deploy infrastructure: " -NoNewline
Write-Host "terraform apply" -ForegroundColor White

Write-Host "`nDocumentation: README.md" -ForegroundColor Cyan
Write-Host ""
