param(
  [string]$Endpoint,
  [string]$VmName,
  [switch]$VerboseHttp,
  [string]$TfLogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure dev override is active like Run.ps1
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$devTfrc = Join-Path $root 'dev.tfrc'
if (Test-Path $devTfrc) { $env:TF_CLI_CONFIG_FILE = $devTfrc }
if ($VerboseHttp) {
  $env:TF_LOG = 'DEBUG'
  if ($TfLogPath) { $env:TF_LOG_PATH = $TfLogPath }
}

pushd $PSScriptRoot
try {
  if ($Endpoint -or $VmName) {
    terraform destroy -auto-approve -input=false @('-var', "endpoint=$Endpoint", '-var', "vm_name=$VmName") | Write-Host
  } else {
    terraform destroy -auto-approve -input=false | Write-Host
  }
} finally { popd }