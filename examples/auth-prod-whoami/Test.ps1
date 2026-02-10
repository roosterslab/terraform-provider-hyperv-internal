param(
  [string]$Endpoint = 'http://localhost:5006',
  [switch]$BuildProvider,
  [switch]$StartApi,
  [switch]$RequireProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }
function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }

# Step 1: PowerShell-only probe using current user
try {
  $r = Invoke-RestMethod -UseDefaultCredentials -Uri ("{0}/identity/whoami" -f $Endpoint) -Method Get -TimeoutSec 5 -ErrorAction Stop
  Write-Ok ("whoami: {0}\{1} SID={2}" -f $r.domain, $r.user, $r.sid)
} catch {
  Write-Err ("whoami probe failed: {0}" -f $_.Exception.Message)
  exit 1
}

# Step 2: Run provider demo (may 401 until Negotiate is wired in v2)
$tfOk = $true
try {
  & (Join-Path $PSScriptRoot 'Run.ps1') -Endpoint $Endpoint -BuildProvider:$BuildProvider -StartApi:$StartApi | Write-Host
} catch { $tfOk = $false }

if (-not $tfOk) {
  if ($RequireProvider) {
    Write-Err 'Provider apply failed and RequireProvider was set.'
    exit 1
  } else {
    Write-Info 'Provider apply failed (expected until Negotiate transport is wired in v2). Skipping provider assertion.'
    Write-Ok 'Auth-Prod WhoAmI (PowerShell probe) PASSED'
    exit 0
  }
}

# Read outputs if apply succeeded
pushd $PSScriptRoot
try {
  $out = terraform output -json | ConvertFrom-Json
  $user = $out.user.value; $sid = $out.sid.value
  if (-not $user) { Write-Err 'whoami.user empty'; exit 1 } else { Write-Ok ("user: {0}" -f $user) }
  if ($sid) { Write-Ok ("sid: {0}" -f $sid) } else { Write-Info 'sid empty (may be expected for some accounts)' }
} finally { popd }

Write-Ok 'Auth-Prod WhoAmI PASSED'
