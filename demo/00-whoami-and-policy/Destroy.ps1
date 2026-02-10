Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

pushd $PSScriptRoot
try {
  terraform destroy -auto-approve -input=false | Write-Host
} finally { popd }
