#[CmdletBinding()]
param(
  [string]$Endpoint = 'http://localhost:5000',
  [string]$Username,
  [string]$Password,
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$envFileCandidates = @(
  (Join-Path $PSScriptRoot 'env.local.ps1')
  (Join-Path $PSScriptRoot 'env.ps1')
)
foreach ($f in $envFileCandidates) { if (Test-Path $f) { . $f; break } }

# Apply defaults from env file if parameters not provided
if (-not $PSBoundParameters.ContainsKey('Endpoint') -and $script:EndpointDefault) { $Endpoint = $script:EndpointDefault }
if (-not $PSBoundParameters.ContainsKey('Username') -and $script:UsernameDefault) { $Username = $script:UsernameDefault }
if (-not $PSBoundParameters.ContainsKey('Password') -and $script:PasswordDefault) { $Password = $script:PasswordDefault }

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

# Force SSPI impersonation path, not raw NTLM
$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = if ($script:AllowRawNtlmDefault) { '1' } else { $null }

Write-Host ("[config] endpoint={0}" -f $Endpoint) -ForegroundColor Yellow
Write-Host ("[config] username={0}" -f ($(if ($Username) { $Username } else { '' }))) -ForegroundColor Yellow
Write-Host ("[config] TF_CLI_CONFIG_FILE={0}" -f $env:TF_CLI_CONFIG_FILE) -ForegroundColor Yellow

Push-Location $PSScriptRoot
try {
  terraform providers -no-color | Out-Host
  $vars = @('-var', ("endpoint={0}" -f $Endpoint))
  if ($Username) { $vars += @('-var', ("username={0}" -f $Username)) }
  if ($Password) { $vars += @('-var', ("password={0}" -f $Password)) }
  terraform plan -input=false -lock=false -no-color @vars | Out-Host
  terraform apply -auto-approve -input=false -lock=false -no-color @vars | Out-Host
  terraform output -no-color | Out-Host
}
finally { Pop-Location }
