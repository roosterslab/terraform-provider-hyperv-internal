param(
  [string]$Endpoint = 'http://localhost:5006',
  [switch]$StartApi,
  [ValidateSet('Testing','Production')][string]$Environment = 'Production',
  [switch]$BuildProvider,
  [switch]$VerboseHttp
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue | Out-Null

if ($StartApi) {
  & (Join-Path $root 'scripts/Run-ApiForExample.ps1') -Action start -ApiUrl $Endpoint -Environment $Environment
}

if ($BuildProvider) {
  Write-Host '[build] Building provider' -ForegroundColor Cyan
  pushd $root; go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .; popd
}

# Dev override for local provider binary
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
if ($VerboseHttp) { $env:TF_LOG = 'DEBUG' }

pushd $PSScriptRoot
try {
  if (Test-Path 'terraform.tfvars' -PathType Leaf) { Write-Host '[info] using terraform.tfvars' -ForegroundColor Cyan }
  $skipInit = Test-Path $devTfrc
  if ($skipInit) {
    Write-Host '[warn] Dev override active; skipping terraform init to avoid registry lookup' -ForegroundColor Yellow
  } else {
    terraform init -input=false | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed with exit code $LASTEXITCODE" }
  }
  terraform apply -auto-approve -input=false -var "endpoint=$Endpoint" | Write-Host
  if ($LASTEXITCODE -ne 0) { throw "terraform apply failed with exit code $LASTEXITCODE" }
} finally { popd }
