param(
  [string]$Endpoint = 'http://localhost:5006',
  [string]$VmName = "user-tfv2-disk-scen",
  [string]$BaseVhdxPath = 'C:/HyperV/VHDX/Users/templates/windows-base.vhdx',
  [switch]$BuildProvider,
  [switch]$VerboseHttp,
  [string]$TfLogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
$null = New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue

if ($BuildProvider) { Write-Host '[build] Building provider' -ForegroundColor Cyan; pushd $root; go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .; popd }

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
$env:TF_CLI_CONFIG_FILE = $devTfrc

if ($VerboseHttp) { $env:TF_LOG = 'DEBUG'; if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath } }

# Ensure base VHDX exists for clone scenario when not provided by caller
try {
  if ($BaseVhdxPath) {
    $dir = Split-Path -Parent $BaseVhdxPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $BaseVhdxPath)) {
      Write-Host ("[vhd] Creating base VHDX at {0}" -f $BaseVhdxPath) -ForegroundColor Cyan
      Import-Module Hyper-V -ErrorAction Stop
      New-VHD -Path $BaseVhdxPath -Dynamic -SizeBytes 1GB | Out-Null
    }
  }
} catch { Write-Host ("[WARN ] Could not ensure base VHDX: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }

pushd $PSScriptRoot
try {
  terraform init -input=false | Write-Host
  terraform apply -auto-approve -input=false -var "endpoint=$Endpoint" -var "vm_name=$VmName" -var "base_vhdx_path=$BaseVhdxPath" | Write-Host
} finally { popd }
