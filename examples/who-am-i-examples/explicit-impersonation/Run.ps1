param(
  [switch]$BuildProvider
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root (three levels up)
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue | Out-Null

if ($BuildProvider) {
  Write-Host '[build] Building provider' -ForegroundColor Cyan
  Push-Location $root
  try { go build -o (Join-Path $bin 'terraform-provider-hypervapiv2.exe') . | Out-Null }
  finally { Pop-Location }
}

# Dev override to local provider
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

# Prefer impersonation (disable raw NTLM)
$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = $null

# Ensure tfvars exists (prefer example)
$tfvars = Join-Path $PSScriptRoot 'terraform.tfvars'
$tfvarsExample = Join-Path $PSScriptRoot 'terraform.tfvars.example'
if (-not (Test-Path $tfvars)) {
  if (Test-Path $tfvarsExample) { Copy-Item $tfvarsExample $tfvars -Force }
  else {
    @(
      'endpoint="http://localhost:5000"',
      'username="Workspace\\systemcore-user"',
      'password="0202"'
    ) -join [Environment]::NewLine | Out-File -FilePath $tfvars -Encoding ASCII
  }
}

Write-Host "[config] vars from terraform.tfvars (endpoint/username/password)" -ForegroundColor Yellow
Write-Host ("[config] TF_CLI_CONFIG_FILE={0}" -f $env:TF_CLI_CONFIG_FILE) -ForegroundColor Yellow

Push-Location $PSScriptRoot
try {
  terraform providers -no-color | Out-Host
  terraform plan -input=false -lock=false -no-color | Out-Host
  terraform apply -auto-approve -input=false -lock=false -no-color | Out-Host
  terraform output -no-color | Out-Host
}
finally { Pop-Location }
