#[CmdletBinding()]
param(
  [string]$Endpoint = 'http://localhost:5000',
  [string]$Username,
  [string]$Password,
  [switch]$BuildProvider,
  [switch]$ForceRawNtlm
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

# Decide raw NTLM vs impersonation based on env/defaults and server advertise
$wantRaw = $true
if ($script:AllowRawNtlmDefault -ne $null) { $wantRaw = [bool]$script:AllowRawNtlmDefault }

if (-not $ForceRawNtlm) {
  # Probe server WWW-Authenticate without auto-auth to detect Negotiate vs NTLM
  try {
    $probeUrl = ($Endpoint.TrimEnd('/') + '/')
    $req = [System.Net.HttpWebRequest]::Create($probeUrl)
    $req.Method = 'GET'
    $req.AllowAutoRedirect = $false
    $req.PreAuthenticate = $false
    $req.UseDefaultCredentials = $false
    $req.Credentials = $null
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
    $vals = @()
    if ($resp -and $resp.Headers) { try { $vals = $resp.Headers.GetValues('WWW-Authenticate') } catch { } }
    $hasNegotiate = $false; $hasNtlm = $false
    foreach ($v in $vals) {
      if ($v -match '^\s*Negotiate\b') { $hasNegotiate = $true }
      if ($v -match '^\s*NTLM\b') { $hasNtlm = $true }
    }
    if ($hasNegotiate -and -not $hasNtlm) { $wantRaw = $false }
  } catch { }
}

$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = if ($wantRaw) { '1' } else { $null }

Write-Host ("[config] endpoint={0}" -f $Endpoint) -ForegroundColor Yellow
Write-Host ("[config] username={0}" -f ($(if ($Username) { $Username } else { '' }))) -ForegroundColor Yellow
Write-Host ("[config] TF_CLI_CONFIG_FILE={0}" -f $env:TF_CLI_CONFIG_FILE) -ForegroundColor Yellow
Write-Host ("[config] HYPERVAPI_V2_ALLOW_RAW_NTLM={0}" -f ($(if ($env:HYPERVAPI_V2_ALLOW_RAW_NTLM) { '1' } else { '0' }))) -ForegroundColor Yellow

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
