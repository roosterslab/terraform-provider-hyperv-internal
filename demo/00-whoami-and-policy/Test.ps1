Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

pushd $PSScriptRoot
try {
  $out = terraform output -json | ConvertFrom-Json
  Write-Host ("User: {0}\{1}" -f $out.domain.value, $out.user.value) -ForegroundColor Green
  Write-Host ("Roots: {0}" -f ($out.roots.value -join ', ')) -ForegroundColor Green
} finally { popd }
