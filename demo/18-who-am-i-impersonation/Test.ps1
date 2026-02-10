Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path (Join-Path $PSScriptRoot 'env.local.ps1')) { . (Join-Path $PSScriptRoot 'env.local.ps1') }
elseif (Test-Path (Join-Path $PSScriptRoot 'env.ps1')) { . (Join-Path $PSScriptRoot 'env.ps1') }
Push-Location $PSScriptRoot
try {
  terraform plan -input=false -lock=false -no-color | Out-Host
  terraform output -no-color | Out-Host
}
finally { Pop-Location }
