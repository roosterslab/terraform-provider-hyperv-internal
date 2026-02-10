param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [switch]$VerboseHttp,
  [string]$TfLogPath,
  [switch]$Strict,
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
if ($VerboseHttp) { $env:TF_LOG = 'DEBUG'; if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath }; Write-Warn 'TF_LOG=DEBUG enabled' }

$failures = @()

pushd $PSScriptRoot
try {
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Write-Host

  $out = terraform output -json | ConvertFrom-Json
  $osPath = $out.os_disk_path.value
  if (-not $osPath) { $failures += 'os_disk_path empty'; Write-Err 'os_disk_path empty' } else { Write-Ok ("os_disk_path: {0}" -f $osPath) }

  Write-Info ("GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if ((""+$vm.name) -and ($vm.name -ieq $VmName)) { Write-Ok ("API VM found: name={0} state={1}" -f $vm.name, $vm.state) } else { $failures += 'API VM name mismatch'; Write-Err 'API VM name mismatch' }
  } catch { $failures += ("GET VM failed: {0}" -f $_.Exception.Message); Write-Err $failures[-1] }

  if ($osPath) { if (Test-Path -LiteralPath $osPath) { Write-Ok ("VHDX exists: {0}" -f $osPath) } else { $msg = "VHDX missing: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } }

  # HCL/State verification
  Write-Info 'Verifying Terraform state attributes'
  $state = terraform show -json | ConvertFrom-Json
  $vmRes = $state.values.root_module.resources | Where-Object { $_.type -eq 'hypervapiv2_vm' } | Select-Object -First 1
  if ($vmRes) {
    $vals = $vmRes.values
    if ($vals.generation -ne 1) { $failures += 'state.generation mismatch'; Write-Err 'state.generation mismatch' } else { Write-Ok 'state.generation ok' }
    if ($vals.memory -ne '2048MB') { Write-Warn 'state.memory mismatch' } else { Write-Ok 'state.memory ok' }
  } else { $failures += 'No hypervapiv2_vm in state'; Write-Err 'No hypervapiv2_vm in state' }

  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host

  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $msg='VM still present after destroy'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } catch { Write-Ok 'API indicates VM not found (as expected)' }
  if ($osPath) { if (Test-Path -LiteralPath $osPath) { $msg = "VHDX still exists after destroy: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok ("VHDX removed: {0}" -f $osPath) } }
} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'
