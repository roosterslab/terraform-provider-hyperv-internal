param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$Username,
  [Parameter(Mandatory=$true)][string]$Password,
  [switch]$StartApi,
  [ValidateSet('Testing','Production')][string]$Environment = 'Production',
  [switch]$BuildProvider,
  [switch]$VerboseHttp
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN ] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue | Out-Null

if ($StartApi) {
  & (Join-Path $root 'scripts/Run-ApiForExample.ps1') -Action start -ApiUrl $Endpoint -Environment $Environment
}

if ($BuildProvider) {
  Write-Info 'Building provider'
  pushd $root; go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') .; popd
}

# Dev override for local provider binary (copy to ProgramData for broader access)
$devDir = Join-Path $env:ProgramData 'hypervapiv2'
New-Item -ItemType Directory -Path $devDir -Force -ErrorAction SilentlyContinue | Out-Null
$devTfrc = Join-Path $devDir 'dev.tfrc'
$binHcl = ($bin -replace '\\','/')
@"
provider_installation {
  dev_overrides {
    \"vinitsiriya/hypervapiv2\" = \"REPLACE_BIN\"
  }
  direct {}
}
"@.Replace('REPLACE_BIN', $binHcl) | Out-File -FilePath $devTfrc -Encoding ASCII -Force

$secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($Username, $secure)

# Build a one-shot script executed under the target user
# Build command string for the impersonated session
$lines = @()
$lines += "cd '${PSScriptRoot}'"
$lines += "`$env:TF_CLI_CONFIG_FILE='${devTfrc}'"
if ($VerboseHttp) { $lines += "`$env:TF_LOG='DEBUG'" }
$tf = (Get-Command terraform).Source
$lines += "& '${tf}' init -input=false"
$lines += "& '${tf}' apply -auto-approve -input=false -var endpoint='${Endpoint}'"
$lines += "if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }"
$cmd = ($lines | ForEach-Object { $_ + ';' }) -join ' '

Write-Info "Running Terraform as $Username"
$proc = Start-Process -FilePath 'powershell.exe' -Credential $cred -WorkingDirectory $env:SystemRoot -PassThru -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command', $cmd)
if ($proc.ExitCode -ne 0) { Write-Err ("Terraform under impersonation failed (exit={0})" -f $proc.ExitCode); throw "terraform failed" }
Write-Ok 'Apply complete'

