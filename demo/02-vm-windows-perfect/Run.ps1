param(
  [string]$Endpoint = 'http://localhost:5006',
  [string]$VmName = "user-tfv2-win-perfect",
  [switch]$BuildProvider,
  [switch]$VerboseHttp,
  [string]$TfLogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
$null = New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue

if ($BuildProvider) {
  Write-Host '[build] Building provider' -ForegroundColor Cyan
  pushd $root
  go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .
  popd
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

if ($VerboseHttp) {
  $env:TF_LOG = 'DEBUG'
  if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath }
  Write-Host '[debug] TF_LOG=DEBUG enabled; provider http.request/response will be emitted' -ForegroundColor Yellow
}

pushd $PSScriptRoot
try {
  terraform init -input=false | Write-Host
  terraform apply -auto-approve -input=false -var "endpoint=$Endpoint" -var "vm_name=$VmName" | Write-Host
} finally { popd }

