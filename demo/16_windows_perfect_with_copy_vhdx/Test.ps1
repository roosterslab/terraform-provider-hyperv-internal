param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [switch]$VerboseHttp,
  [string]$TfLogPath,
  [switch]$Strict,
  [switch]$BuildProvider,
  [string]$BaseVhdxPath = "C:/HyperV/Templates/windows-base.vhdx",
  [string]$Username,
  [string]$Password
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN ] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

# Ensure dev override is active like Run.ps1
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
$devTfrc = Join-Path $root 'dev.tfrc'
if (Test-Path $devTfrc) { $env:TF_CLI_CONFIG_FILE = $devTfrc }
if ($VerboseHttp) {
  $env:TF_LOG = 'DEBUG'
  if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath }
  Write-Warn 'TF_LOG=DEBUG enabled; provider HTTP logs will be visible'
}

$failures = @()

function Invoke-DemoRun {
  param([string]$Endpoint,[string]$VmName,[switch]$BuildProvider,[switch]$VerboseHttp,[string]$TfLogPath,[string]$BaseVhdxPath,[string]$Username,[string]$Password)
  Write-Info ("Running demo apply: endpoint={0} vm={1} base={2}" -f $Endpoint,$VmName,$BaseVhdxPath)
  try {
    if ($VerboseHttp -and $TfLogPath) {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp -TfLogPath $TfLogPath -BaseVhdxPath $BaseVhdxPath -Username $Username -Password $Password | Write-Host
    } elseif ($VerboseHttp) {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp -BaseVhdxPath $BaseVhdxPath -Username $Username -Password $Password | Write-Host
    } else {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -BaseVhdxPath $BaseVhdxPath -Username $Username -Password $Password | Write-Host
    }
    Write-Ok 'Demo apply completed'
  } catch {
    $failures += ("Demo apply failed: {0}" -f $_.Exception.Message)
    Write-Err $failures[-1]
  }
}

function Invoke-DemoDestroy {
  param([string]$Endpoint,[string]$VmName,[switch]$VerboseHttp,[string]$TfLogPath)
  Write-Info ("Running demo destroy: endpoint={0} vm={1}" -f $Endpoint,$VmName)
  try {
    if ($VerboseHttp -and $TfLogPath) {
      & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName -VerboseHttp -TfLogPath $TfLogPath | Write-Host
    } elseif ($VerboseHttp) {
      & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName -VerboseHttp | Write-Host
    } else {
      & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
    }
    Write-Ok 'Demo destroy completed'
  } catch {
    $failures += ("Demo destroy failed: {0}" -f $_.Exception.Message)
    Write-Err $failures[-1]
  }
}

pushd $PSScriptRoot
try {
  # API probe
  Write-Info ("Probing API: {0}/api/v2/vms" -f $Endpoint)
  try { Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms" -f $Endpoint) -Method Get -TimeoutSec 10 -ErrorAction Stop | Out-Null; Write-Ok 'API reachable' } catch { Write-Warn ("API probe failed (continuing): {0}" -f $_.Exception.Message) }

  # Check base VHDX exists
  if (Test-Path -LiteralPath $BaseVhdxPath) { Write-Ok ("Base VHDX exists: {0}" -f $BaseVhdxPath) } else { $msg = "Base VHDX missing: $BaseVhdxPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } }

  # Apply
  Invoke-DemoRun -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath -BaseVhdxPath $BaseVhdxPath

  # Read outputs
  Write-Info 'Reading terraform outputs'
  $out = terraform output -json | ConvertFrom-Json
  $osPath = $out.os_disk_path.value
  $pathAllowed = $out.path_allowed.value
  $roots = $out.policy_roots.value
  $exts = $out.policy_extensions.value
  $baseVhdx = $out.base_vhdx.value
  $secureBoot = $out.secure_boot.value
  $secureBootTemplate = $out.secure_boot_template.value
  $tpmEnabled = $out.tpm_enabled.value
  $encryptEnabled = $out.encrypt_enabled.value
  if (-not $osPath) { $failures += 'os_disk_path empty'; Write-Err 'os_disk_path empty' } else { Write-Ok ("os_disk_path: {0}" -f $osPath) }
  if (-not $roots -or $roots.Count -le 0) { Write-Warn 'policy roots empty'; if ($Strict) { $failures += 'policy roots empty' } } else { Write-Ok ("policy roots: {0}" -f ($roots -join ',')) }
  if (-not $exts -or $exts.Count -le 0) { Write-Warn 'policy extensions empty'; if ($Strict) { $failures += 'policy extensions empty' } } else { Write-Ok ("policy extensions: {0}" -f ($exts -join ',')) }
  if ($pathAllowed -ne $true) { $msg = 'path_validate not allowed'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'path_validate allowed' }
  if ($baseVhdx -ne $BaseVhdxPath) { $msg = 'base_vhdx mismatch'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'base_vhdx ok' }
  if ($secureBoot -ne $true) { $msg = 'secure_boot not enabled'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'secure_boot enabled' }
  if ($secureBootTemplate -ne 'MicrosoftWindows') { $msg = 'secure_boot_template mismatch'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'secure_boot_template ok' }
  if ($tpmEnabled -ne $true) { $msg = 'tpm not enabled'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'tpm enabled' }
  if ($encryptEnabled -ne $false) { $msg = 'encrypt not disabled'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok 'encrypt disabled' }

  # API VM
  Write-Info ("GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if ((""+$vm.name) -and ($vm.name -ieq $VmName)) { Write-Ok ("API VM found: name={0} state={1}" -f $vm.name, $vm.state) } else { $failures += 'API VM name mismatch'; Write-Err 'API VM name mismatch' }
  } catch { $failures += ("GET VM failed: {0}" -f $_.Exception.Message); Write-Err $failures[-1] }

  # Filesystem check
  if ($osPath) { if (Test-Path -LiteralPath $osPath) { Write-Ok ("Cloned VHDX exists: {0}" -f $osPath) } else { $msg = "Cloned VHDX missing: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } }

  # HCL/State verification
  Write-Info 'Verifying Terraform state attributes'
  $state = terraform show -json | ConvertFrom-Json
  $vmRes = $state.values.root_module.resources | Where-Object { $_.type -eq 'hypervapiv2_vm' } | Select-Object -First 1
  if (-not $vmRes) { $failures += 'No hypervapiv2_vm in state'; Write-Err 'No hypervapiv2_vm in state' }
  else {
    $vals = $vmRes.values
    if ($vals.name -ne $VmName) { $failures += 'state.name mismatch'; Write-Err 'state.name mismatch' } else { Write-Ok 'state.name ok' }
    if ($vals.cpu -ne 4) { Write-Warn 'state.cpu mismatch' } else { Write-Ok 'state.cpu ok' }
    if ($vals.memory -ne '4GB') { Write-Warn 'state.memory mismatch' } else { Write-Ok 'state.memory ok' }
    if ($vals.power -ne 'stopped') { Write-Warn 'state.power mismatch' } else { Write-Ok 'state.power ok' }
    if ($vals.generation -ne 2) { Write-Warn 'state.generation mismatch' } else { Write-Ok 'state.generation ok' }
    if ($vals.switch_name -ne 'Default Switch') { Write-Warn 'state.switch_name mismatch' } else { Write-Ok 'state.switch_name ok' }
    if ($vals.disk -and $vals.disk[0].path -ne $osPath) { Write-Warn 'state.disk[0].path mismatch' } else { Write-Ok 'state.disk[0].path ok' }
    if ($vals.disk -and $vals.disk[0].clone_from -ne $BaseVhdxPath) { Write-Warn 'state.disk[0].clone_from mismatch' } else { Write-Ok 'state.disk[0].clone_from ok' }
    if ($vals.firmware.secure_boot -ne $true) { Write-Warn 'state.firmware.secure_boot mismatch' } else { Write-Ok 'state.firmware.secure_boot ok' }
    if ($vals.firmware.secure_boot_template -ne 'MicrosoftWindows') { Write-Warn 'state.firmware.secure_boot_template mismatch' } else { Write-Ok 'state.firmware.secure_boot_template ok' }
    if ($vals.security.tpm -ne $true) { Write-Warn 'state.security.tpm mismatch' } else { Write-Ok 'state.security.tpm ok' }
    if ($vals.security.encrypt -ne $false) { Write-Warn 'state.security.encrypt mismatch' } else { Write-Ok 'state.security.encrypt ok' }
  }

  # Destroy
  Invoke-DemoDestroy -Endpoint $Endpoint -VmName $VmName -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath

  # Post-delete API
  Write-Info ("Verify deletion: GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $msg='VM still present after destroy'; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } catch { Write-Ok 'API indicates VM not found (as expected)' }

  # Post-delete filesystem
  if ($osPath) { if (Test-Path -LiteralPath $osPath) { $msg = "Cloned VHDX still exists after destroy: $osPath"; if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg } } else { Write-Ok ("Cloned VHDX removed: {0}" -f $osPath) } }
} finally { popd }

if ($failures.Count -gt 0) {
  Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count)
  $failures | ForEach-Object { Write-Err " - $_" }
  exit 1
}
Write-Ok 'Test PASSED'
