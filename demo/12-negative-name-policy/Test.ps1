param(
  [string]$Endpoint = 'http://localhost:5006',
  [string]$VmName = 'badname',
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$devTfrc = Join-Path $root 'dev.tfrc'
if (Test-Path $devTfrc) { $env:TF_CLI_CONFIG_FILE = $devTfrc }

pushd $PSScriptRoot
try {
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Out-Null
  $code = $LASTEXITCODE
  if ($code -eq $null) { $code = 0 }
  if ($code -eq 0) {
    Write-Err 'Expected plan/apply to fail due to name policy'
    exit 1
  } else {
    Write-Ok "Name policy violation correctly blocked apply (exit=$code)"
  }
} finally { popd }
