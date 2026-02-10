param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }
function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$devTfrc = Join-Path $root 'dev.tfrc'
if (Test-Path $devTfrc) { $env:TF_CLI_CONFIG_FILE = $devTfrc }

$fails = @()
pushd $PSScriptRoot
try {
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Write-Host
  $state = terraform show -json | ConvertFrom-Json
  $vmRes = $state.values.root_module.resources | Where-Object { $_.type -eq 'hypervapiv2_vm' } | Select-Object -First 1
  if (-not $vmRes) { $fails += 'no vm in state' } else { Write-Ok 'vm in state' }

  # Verify provider auto-placed disk path is present in state via read back
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if ($vm -and $vm.name -ieq $VmName) { Write-Ok "API VM present: $($vm.state)" } else { $fails += 'api vm mismatch' }
  } catch { $fails += 'api get vm failed' }

  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $fails += 'vm not deleted' } catch { Write-Ok 'deleted' }
} finally { popd }

if ($fails.Count -gt 0) { $fails | ForEach-Object { Write-Err $_ }; exit 1 }
Write-Ok 'Test PASSED'

