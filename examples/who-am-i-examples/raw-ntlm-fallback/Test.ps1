Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  terraform plan -input=false -lock=false -no-color | Out-Host
  terraform output -no-color | Out-Host
}
finally { Pop-Location }
