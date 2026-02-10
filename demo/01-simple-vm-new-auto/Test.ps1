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

# Helpers to run demo create/destroy steps
function Invoke-DemoRun {
  param([string]$Endpoint,[string]$VmName,[switch]$BuildProvider,[switch]$VerboseHttp,[string]$TfLogPath)
  Write-Info ("Running demo apply: endpoint={0} vm={1}" -f $Endpoint,$VmName)
  try {
    if ($VerboseHttp -and $TfLogPath) {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp -TfLogPath $TfLogPath | Write-Host
    } elseif ($VerboseHttp) {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp | Write-Host
    } else {
      & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider | Write-Host
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
  # 0) Ensure API is reachable
  Write-Info ("Probing API: {0}/api/v2/vms" -f $Endpoint)
  try {
    Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms" -f $Endpoint) -Method Get -TimeoutSec 10 -ErrorAction Stop | Out-Null
    Write-Ok 'API reachable'
  } catch {
    Write-Warn ("API probe failed (continuing, Run may still succeed): {0}" -f $_.Exception.Message)
  }

  # A) Create/apply via demo Run.ps1
  Invoke-DemoRun -Endpoint $Endpoint -VmName $VmName -BuildProvider:$BuildProvider -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath

  # 1) Capture terraform outputs
  Write-Info 'Reading terraform outputs'
  $out = terraform output -json | ConvertFrom-Json
  $osPath = $out.os_disk_path.value
  if (-not $osPath -or $osPath -eq '') {
    $failures += 'terraform output os_disk_path is empty'
    Write-Err 'terraform output os_disk_path is empty'
  } else {
    Write-Ok ("terraform output os_disk_path: {0}" -f $osPath)
  }

  # 2) Probe API: GET /api/v2/vms/{name}
  Write-Info ("GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $vm = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    if (-not $vm) {
      $failures += 'API returned no VM payload'
      Write-Err 'API returned no VM payload'
    } else {
      # name check (case-insensitive)
      if ((""+$vm.name) -and ($vm.name -ieq $VmName)) {
        Write-Ok ("API VM found: name={0} state={1}" -f $vm.name, $vm.state)
      } else {
        $failures += ("API VM name mismatch (got '{0}', want '{1}')" -f $vm.name, $VmName)
        Write-Err $failures[-1]
      }
    }
  } catch {
    $failures += ("GET VM failed: {0}" -f $_.Exception.Message)
    Write-Err $failures[-1]
  }

  # 3) Filesystem check for planned OS disk path
  if ($osPath) {
    if (Test-Path -LiteralPath $osPath) {
      Write-Ok ("VHDX exists: {0}" -f $osPath)
    } else {
      $msg = "VHDX does not exist at path: $osPath"
      if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg }
    }
  }

  # 4) Optional: validate path against policy for visibility (non-strict)
  try {
    $body = @{ path=$osPath; operation='create'; ext='vhdx' } | ConvertTo-Json -Compress
    $resp = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/policy/validate-path" -f $Endpoint) -Method Post -TimeoutSec 10 -ContentType 'application/json' -Body $body -ErrorAction Stop
    if ($resp.allowed -eq $true) {
      Write-Ok ("Policy allows path (root={0})" -f $resp.matched_root)
    } else {
      $msg = "Policy reported path not allowed: $($resp.message)"
      if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg }
    }
  } catch {
    Write-Warn ("policy/validate-path probe failed: {0}" -f $_.Exception.Message)
  }

  # B) Destroy via demo Destroy.ps1
  Invoke-DemoDestroy -Endpoint $Endpoint -VmName $VmName -VerboseHttp:$VerboseHttp -TfLogPath $TfLogPath

  # 5) Verify VM no longer present
  Write-Info ("Verify deletion: GET {0}/api/v2/vms/{1}" -f $Endpoint, $VmName)
  try {
    $null = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/api/v2/vms/{1}" -f $Endpoint, $VmName) -Method Get -TimeoutSec 10 -ErrorAction Stop
    $msg = 'VM still present after destroy'
    if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg }
  } catch {
    # Accept 404/NotFound as success
    Write-Ok 'API indicates VM not found (as expected)'
  }

  # 6) Verify VHDX removed
  if ($osPath) {
    if (Test-Path -LiteralPath $osPath) {
      $msg = "VHDX still exists after destroy: $osPath"
      if ($Strict) { $failures += $msg; Write-Err $msg } else { Write-Warn $msg }
    } else {
      Write-Ok ("VHDX removed: {0}" -f $osPath)
    }
  }
} finally { popd }

if ($failures.Count -gt 0) {
  Write-Err ("Test FAILED with {0} issue(s)." -f $failures.Count)
  $failures | ForEach-Object { Write-Err " - $_" }
  exit 1
}
Write-Ok 'Test PASSED'
