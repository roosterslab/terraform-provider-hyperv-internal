param(
  [string]$Endpoint = 'http://localhost:5006',
  [switch]$VerboseHttp,
  [string]$TfLogPath,
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN ] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$devTfrc = Join-Path $root 'dev.tfrc'
if (Test-Path $devTfrc) { $env:TF_CLI_CONFIG_FILE = $devTfrc }
if ($VerboseHttp) { $env:TF_LOG = 'DEBUG'; if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath } }

pushd $PSScriptRoot
try {
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -BuildProvider:$BuildProvider | Write-Host
  $out = terraform output -json | ConvertFrom-Json
  $allowed = $out.neg_allowed.value
  $msg = $out.neg_message.value
  if ($allowed -eq $false) { Write-Ok ("path_validate denied as expected: {0}" -f $msg) } else { Write-Err 'Expected denial but got allowed'; exit 1 }
  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint | Write-Host
} finally { popd }

Write-Ok 'Test PASSED'

