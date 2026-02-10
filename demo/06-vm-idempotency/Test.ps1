param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
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

$failures = @()

pushd $PSScriptRoot
try {
  # First apply
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Write-Host

  # Second apply to assert idempotency
  Write-Info 'Re-applying to verify idempotency'
  $applyOut = & terraform apply -auto-approve -input=false -var "endpoint=$Endpoint" -var "vm_name=$VmName" | Out-String
  if ($applyOut -match 'No changes') { Write-Ok 'Idempotency confirmed (No changes)' } else { $failures += 'Second apply did not report No changes'; Write-Err 'Second apply did not report No changes' }

  # Destroy
  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'

