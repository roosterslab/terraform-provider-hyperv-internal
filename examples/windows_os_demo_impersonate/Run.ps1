param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [Parameter(Mandatory=$true)][string]$Username,
  [Parameter(Mandatory=$true)][string]$Password,
  [string]$BaseVhdxPath = 'C:/HyperV/VHDX/Users/templates/windows-base.vhdx',
  [switch]$BuildProvider,
  [switch]$VerboseHttp
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN ] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue | Out-Null

if ($BuildProvider) {
  Write-Info 'Building provider'
  pushd $root; go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .; popd
}

# Dev override for local provider binary
$devTfrc = Join-Path $root 'dev.tfrc'
$binHcl = ($bin -replace '\\','/')
@'
provider_installation {
  dev_overrides {
    "vinitsiriya/hypervapiv2" = "REPLACE_BIN"
  }
  direct {}
}
'@.Replace('REPLACE_BIN', $binHcl) | Out-File -FilePath $devTfrc -Encoding ASCII -Force

$secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($Username, $secure)

# Ensure base VHD exists (run as current user)
try {
  $dir = Split-Path -Parent $BaseVhdxPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (-not (Test-Path -LiteralPath $BaseVhdxPath)) {
    Import-Module Hyper-V -ErrorAction Stop
    New-VHD -Path $BaseVhdxPath -Dynamic -SizeBytes 1GB | Out-Null
    Write-Info ("Created base VHDX at {0}" -f $BaseVhdxPath)
  }
} catch { Write-Warn ("Could not ensure base VHDX: {0}" -f $_.Exception.Message) }

# Build and run Terraform under impersonated user
$lines = @()
$lines += "`$env:TF_CLI_CONFIG_FILE='${devTfrc}'"
if ($VerboseHttp) { $lines += "`$env:TF_LOG='DEBUG'" }
$lines += "Set-Location '$PSScriptRoot'"
$lines += "terraform init -input=false"
$lines += "terraform apply -auto-approve -input=false -var endpoint='$Endpoint' -var vm_name='$VmName' -var base_vhdx_path='$BaseVhdxPath'"
$lines += "if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }"
$cmd = ($lines | ForEach-Object { $_ + ';' }) -join ' '

Write-Info "Running Terraform as $Username"
$proc = Start-Process -FilePath 'powershell.exe' -Credential $cred -WorkingDirectory $env:SystemRoot -PassThru -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command', $cmd)
if ($proc.ExitCode -ne 0) { Write-Err ("Terraform under impersonation failed (exit={0})" -f $proc.ExitCode); throw "terraform failed" }
Write-Ok 'Apply complete'

