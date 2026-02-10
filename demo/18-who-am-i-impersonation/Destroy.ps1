param([switch]$PurgeState)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path (Join-Path $PSScriptRoot 'env.local.ps1')) { . (Join-Path $PSScriptRoot 'env.local.ps1') }
elseif (Test-Path (Join-Path $PSScriptRoot 'env.ps1')) { . (Join-Path $PSScriptRoot 'env.ps1') }
Push-Location $PSScriptRoot
try {
	terraform destroy -auto-approve -input=false -lock=false -no-color | Out-Host
	if ($PurgeState) {
		Write-Host '[cleanup] Removing local state and .terraform' -ForegroundColor Yellow
		Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .terraform, '.terraform.lock.hcl' | Out-Null
		Get-ChildItem -Filter 'terraform.tfstate*' | Remove-Item -Force -ErrorAction SilentlyContinue
	}
}
finally { Pop-Location }
