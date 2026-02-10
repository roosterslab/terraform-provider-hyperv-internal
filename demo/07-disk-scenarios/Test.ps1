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
  $newPath = $out.new_auto_path.value
  $newAllowed = $out.new_auto_allowed.value
  $clonePath = $out.clone_auto_path.value
  $attachReason = if ($out.PSObject.Properties.Name -contains 'attach_plan_reason') { $out.attach_plan_reason.value } else { $null }
  if (-not $newPath) { $failures += 'new_auto_path empty'; Write-Err 'new_auto_path empty' } else { Write-Ok ("new_auto_path: {0}" -f $newPath) }
  if ($newAllowed -ne $true) { $failures += 'new_auto path_validate not allowed'; Write-Err 'new_auto path_validate not allowed' } else { Write-Ok 'new_auto path allowed' }
  if ($clonePath) { Write-Ok ("clone_auto planned path: {0}" -f $clonePath) } else { Write-Warn 'clone_auto planned path empty (template may not exist)' }
  if ($attachReason) { Write-Ok ("attach plan reason: {0}" -f $attachReason) }

  # HCL/State verification (before destroy)
  Write-Info 'Verifying Terraform state attributes'
  $state = terraform show -json | ConvertFrom-Json
  $vmRes = $state.values.root_module.resources | Where-Object { $_.type -eq 'hypervapiv2_vm' } | Select-Object -First 1
  if ($vmRes) {
    $vals = $vmRes.values
    if ($vals.new_vhd_size_gb -ne 20) { Write-Warn 'state.new_vhd_size_gb mismatch' } else { Write-Ok 'state.new_vhd_size_gb ok' }
  } else { Write-Warn 'No hypervapiv2_vm in state (unexpected)'}

  # API presence check
  Write-Info ("GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if ((""+$vm.name) -and ($vm.name -ieq $VmName)) { Write-Ok ("API VM found: name={0} state={1}" -f $vm.name, $vm.state) } else { $failures += 'API VM name mismatch'; Write-Err 'API VM name mismatch' }
  } catch { $failures += ("GET VM failed: {0}" -f $_.Exception.Message); Write-Err $failures[-1] }

  # Destroy and verify
  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $failures += 'VM still present after destroy'; Write-Err 'VM still present after destroy' } catch { Write-Ok 'API indicates VM not found (as expected)' }

} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'
