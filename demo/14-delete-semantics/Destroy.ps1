param(
  [string]$Endpoint = 'http://localhost:5006',
  [string]$VmName = "user-tfv2-del-semantics"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

pushd $PSScriptRoot
try {
  terraform destroy -auto-approve -input=false -var "endpoint=$Endpoint" -var "vm_name=$VmName" | Write-Host
} finally { popd }

