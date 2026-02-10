param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [string]$BaseVhdxPath = 'C:/HyperV/VHDX/Users/templates/windows-base.vhdx',
  [switch]$BuildProvider,
  [switch]$VerboseHttp,
  [string]$TfLogPath,
  [switch]$Strict
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
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BaseVhdxPath $BaseVhdxPath -BuildProvider:$BuildProvider -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath | Write-Host

  $out = terraform output -json | ConvertFrom-Json
  $osPath = $out.os_disk_path.value
  if (-not $osPath) { $failures += 'os_disk_path empty'; Write-Err 'os_disk_path empty' } else { Write-Ok ("os_disk_path: {0}" -f $osPath) }

  Write-Info ("GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if ((""+$vm.name) -and ($vm.name -ieq $VmName)) { Write-Ok ("API VM found: name={0} state={1}" -f $vm.name, $vm.state) } else { $failures += 'API VM name mismatch'; Write-Err 'API VM name mismatch' }
  } catch { $failures += ("GET VM failed: {0}" -f $_.Exception.Message); Write-Err $failures[-1] }

  if ($osPath) { if (Test-Path -LiteralPath $osPath) { Write-Ok ("Cloned VHDX exists: {0}" -f $osPath) } else { $msg = "Cloned VHDX missing: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } }

  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath | Write-Host
  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $msg='VM still present after destroy'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } catch { Write-Ok 'API indicates VM not found (as expected)' }
  if ($osPath) { if (Test-Path -LiteralPath $osPath) { $msg = "Cloned VHDX still exists after destroy: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok ("Cloned VHDX removed: {0}" -f $osPath) } }
} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'

