param(
  [string]$Endpoint = 'http://localhost:5006',
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$providerRoot = Join-Path $root ''
$bin = Join-Path $providerRoot 'bin'
$null = New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue

if ($BuildProvider) {
  Write-Host '[build] Building provider' -ForegroundColor Cyan
  pushd $providerRoot
  go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .
  popd
}
# Dev override
$devTfrc = Join-Path $providerRoot 'dev.tfrc'
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

pushd $PSScriptRoot
try {
  $env:TF_LOG = 'INFO'
  terraform init -input=false | Write-Host
  terraform apply -auto-approve -input=false -var "endpoint=$Endpoint" | Write-Host
} finally {
  popd
}
