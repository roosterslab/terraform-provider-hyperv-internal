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
  $out = terraform output -json | ConvertFrom-Json
  $os = $out.os_disk_path.value
  if (-not $os) { $fails += 'no os_disk_path output' } else { Write-Ok "os_disk_path: $os" }
  if (Test-Path $os) { Write-Ok 'disk exists after create' } else { $fails += 'disk file missing after create' }

  & (Join-Path $PSScriptRoot 'Destroy.ps1') -Endpoint $Endpoint -VmName $VmName | Write-Host
  # Current provider behavior: any protected disk forces deleteDisks=false globally
  if (Test-Path $os) { Write-Ok 'disk preserved due to protect override' } else { $fails += 'disk deleted but protect was set' }
} finally { popd }

if ($fails.Count -gt 0) { $fails | ForEach-Object { Write-Err $_ }; exit 1 }
Write-Ok 'Test PASSED'

