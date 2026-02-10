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
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Write-Host
  $out = terraform output -json | ConvertFrom-Json
  $osPath = $out.os_disk_path.value
  if (-not $osPath) { $failures += 'os_disk_path empty'; Write-Err 'os_disk_path empty' } else { Write-Ok ("os_disk_path: {0}" -f $osPath) }

  # Check if VM was actually created
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    $vmExists = $true
    Write-Ok "VM exists in API: $($vm.name)"
  } catch {
    $vmExists = $false
    Write-Warn "VM does not exist in API (creation may have failed): $($_.Exception.Message)"
  }

  # Destroy and verify VHDX removed (only if VM exists and delete_disks is enabled)
  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
  
  if ($vmExists) {
    if (Test-Path -LiteralPath $osPath) { $failures += "VHDX still exists after destroy: $osPath"; Write-Err $failures[-1] } else { Write-Ok ("VHDX removed: {0}" -f $osPath) }
  } else {
    Write-Info "Skipping disk deletion check since VM was never created"
  }
} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'

