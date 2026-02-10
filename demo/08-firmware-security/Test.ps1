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

  # HCL/State verification for firmware/security
  Write-Info 'Verifying Terraform state attributes (firmware/security)'
  $state = terraform show -json | ConvertFrom-Json
  $vmRes = $state.values.root_module.resources | Where-Object { $_.type -eq 'hypervapiv2_vm' } | Select-Object -First 1
  if ($vmRes) {
    $vals = $vmRes.values
    if ($vals.firmware.secure_boot -ne $true) { $failures += 'state.firmware.secure_boot mismatch'; Write-Err 'state.firmware.secure_boot mismatch' } else { Write-Ok 'state.firmware.secure_boot ok' }
    if ($vals.firmware.secure_boot_template -ne 'MicrosoftWindows') { Write-Warn 'state.firmware.secure_boot_template mismatch' } else { Write-Ok 'state.firmware.secure_boot_template ok' }
    if ($vals.security.tpm -ne $true) { Write-Warn 'state.security.tpm mismatch' } else { Write-Ok 'state.security.tpm ok' }
    if ($vals.security.encrypt -ne $false) { Write-Warn 'state.security.encrypt mismatch' } else { Write-Ok 'state.security.encrypt ok' }
  } else { $failures += 'No hypervapiv2_vm in state'; Write-Err 'No hypervapiv2_vm in state' }

  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
  try { $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop; $failures += 'VM still present after destroy'; Write-Err 'VM still present after destroy' } catch { Write-Ok 'API indicates VM not found (as expected)' }
} finally { popd }

if ($failures.Count -gt 0) { Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count); $failures | ForEach-Object { Write-Err " - $_" }; exit 1 }
Write-Ok 'Test PASSED'
