param(
  [string]$Endpoint = 'http://localhost:5006',
  [string]$VmName = "user-tfv2-win-copy",
  [switch]$BuildProvider,
  [switch]$VerboseHttp,
  [string]$TfLogPath,
  [string]$BaseVhdxPath = "C:/HyperV/VHDX/Users/templates/windows-base.vhdx",
  [switch]$SetupApi,
  [string]$Username,
  [string]$Password
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
  if ($SetupApi) {
    Write-Host '[api] Preparing API environment (JEA + policy pack + restart)' -ForegroundColor Cyan
    $providerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $apiRoot = Join-Path $providerRoot 'hyperv-mgmt-api-v2'
    $policyCliProj = Join-Path $apiRoot 'src/HyperV.Management.PolicyCli/HyperV.Management.PolicyCli.csproj'
    $jeaScript = Join-Path $apiRoot 'scripts/Register-JeaEndpoint.ps1'
    $apiHelper = Join-Path $providerRoot 'terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1'
    # Stop API if running on this Endpoint
    if (Test-Path $apiHelper) { powershell -NoProfile -ExecutionPolicy Bypass -File $apiHelper -Action stop -ApiUrl $Endpoint | Out-Null }
    # Install JEA endpoint
    if (Test-Path $jeaScript) { dotnet run --project $policyCliProj -- install-jea --scriptPath $jeaScript | Out-Null }
    # Install strict policy pack into API policies folder
    $polSrc = Join-Path $apiRoot 'policy-packs/strict-multiuser'
    $polDst = Join-Path $apiRoot 'src/HyperV.Management.Api/policies'
    if (Test-Path $polSrc) { dotnet run --project $policyCliProj -- install-pack --source $polSrc --target $polDst --force | Out-Null }
    # Start API again on requested endpoint
    if (Test-Path $apiHelper) { powershell -NoProfile -ExecutionPolicy Bypass -File $apiHelper -Action start -ApiUrl $Endpoint -Environment Testing | Out-Null }
  }

  # Readiness probe for API
  $ready = $false
  try {
    for ($i=0; $i -lt 40 -and -not $ready; $i++) {
      try {
        $resp = Invoke-WebRequest -Uri ("{0}/api/v2/vms" -f $Endpoint) -Method Get -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) { $ready = $true }
      } catch {
        if ($_.Exception.Response) { $ready = $true } else { Start-Sleep -Milliseconds 250 }
      }
    }
  } catch { }
  if (-not $ready) { throw "API not ready at $Endpoint. Use -SetupApi or start API before running the demo." }
  # Ensure base VHDX exists for clone scenario
  try {
    if ($BaseVhdxPath) {
      $dir = Split-Path -Parent $BaseVhdxPath
      if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      if (-not (Test-Path -LiteralPath $BaseVhdxPath)) {
        Write-Host ("[vhd] Creating base VHDX at {0}" -f $BaseVhdxPath) -ForegroundColor Cyan
        Import-Module Hyper-V -ErrorAction Stop
        New-VHD -Path $BaseVhdxPath -Dynamic -SizeBytes 1GB | Out-Null
      }
    }
  } catch { Write-Host ("[WARN ] Could not ensure base VHDX: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }

  $skipInit = Test-Path $devTfrc
  if ($skipInit) {
    Write-Host '[warn] Dev override active; skipping terraform init to avoid registry lookup' -ForegroundColor Yellow
  } else {
    terraform init -input=false | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed with exit code $LASTEXITCODE" }
  }
  $applyArgs = @('-auto-approve','-input=false','-var',"endpoint=$Endpoint",'-var',"vm_name=$VmName",'-var',"base_vhdx_path=$BaseVhdxPath")
  if ($Username) { $applyArgs += @('-var',"username=$Username") }
  if ($Password) { $applyArgs += @('-var',"password=$Password") }
  terraform apply @applyArgs | Write-Host
  if ($LASTEXITCODE -ne 0) { throw "terraform apply failed with exit code $LASTEXITCODE" }
} finally { popd }
