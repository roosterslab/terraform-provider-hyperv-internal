#[CmdletBinding()]
param(
  [string]$Endpoint = 'http://localhost:5000',
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue | Out-Null

if ($BuildProvider) {
  Write-Host '[build] Building provider' -ForegroundColor Cyan
  Push-Location $root
  try { go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') . | Out-Null }
  finally { Pop-Location }
}

# Dev override
$devTfrc = Join-Path $root 'dev.tfrc'
$binHcl = ($bin -replace '\\','/')
@'
provider_installation {
  dev_overrides {
    "vinitsiriya/hypervapiv2" = "REPLACE_BIN"
  }
  direct {}
}
'@.Replace('REPLACE_BIN', $binHcl) | Out-File -FilePath $devTfrc -Encoding ASCII -Force
$env:TF_CLI_CONFIG_FILE = $devTfrc

# Ensure raw NTLM fallback is disabled for SSPI demo
$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = $null

Write-Host ("[config] endpoint={0}" -f $Endpoint) -ForegroundColor Yellow
Write-Host ("[config] TF_CLI_CONFIG_FILE={0}" -f $env:TF_CLI_CONFIG_FILE) -ForegroundColor Yellow

Push-Location $PSScriptRoot
try {
  terraform providers -no-color | Out-Host
  terraform plan -input=false -lock=false -no-color -var ("endpoint={0}" -f $Endpoint) | Out-Host
  terraform apply -auto-approve -input=false -lock=false -no-color -var ("endpoint={0}" -f $Endpoint) | Out-Host
  terraform output -no-color | Out-Host
}
finally { Pop-Location }
