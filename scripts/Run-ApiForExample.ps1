param(
  [ValidateSet('start','stop')] [string]$Action = 'start',
  [string]$ApiUrl = 'http://localhost:5006',
  [ValidateSet('Testing','Production')] [string]$Environment = 'Testing'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[INFO ] $m" -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host "[ OK  ] $m" -ForegroundColor Green }
function Write-Warn($m){ Write-Host "[WARN ] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR  ] $m" -ForegroundColor Red }

# Repo roots
$providerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$apiRepo = Join-Path $providerRoot 'hyperv-mgmt-api-v2'
$apiProj = Join-Path $apiRepo 'src/HyperV.Management.Api/HyperV.Management.Api.csproj'
$stateDir = $PSScriptRoot
$pidFile = Join-Path $stateDir '.api.pid'

function Test-Tcp([string]$Url){
  try { $u=[Uri]$Url; $c=New-Object System.Net.Sockets.TcpClient; $ar=$c.BeginConnect($u.Host,$u.Port,$null,$null); $ok=$ar.AsyncWaitHandle.WaitOne(500); if($ok -and $c.Connected){$c.Close();return $true}; $c.Close(); return $false } catch { return $false }
}

function Test-ApiSignature([string]$Url){
  try {
    $u = [Uri]$Url
    $probe = "$($u.Scheme)://$($u.Host):$($u.Port)/api/v2/vms"
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $probe -Method Get -TimeoutSec 2 -MaximumRedirection 0 -ErrorAction Stop
    if ($resp.StatusCode -eq 200) { return $true }
    return $false
  } catch {
    if ($_.Exception.Response -and ($_.Exception.Response.StatusCode.value__ -eq 401)) { return $true }
    return $false
  }
}

switch ($Action) {
  'start' {
    Write-Info 'Building API solution (fast if up-to-date)'
    Push-Location $apiRepo; & dotnet build --nologo | Out-Null; Pop-Location

    if (Test-Tcp $ApiUrl) {
      if (Test-ApiSignature $ApiUrl) {
        Write-Warn ("Port in use, detected API running at {0}" -f $ApiUrl)
        Write-Ok ("API ready: {0}" -f $ApiUrl)
        return
      } else {
        Write-Err ("Port {0} is in use but does not appear to be HyperV.Management.Api. Free the port or choose a different -ApiUrl." -f $ApiUrl)
        exit 1
      }
    }

    $cmd = @(
      "`$env:ASPNETCORE_ENVIRONMENT='$Environment'",
      "`$env:ASPNETCORE_URLS='$ApiUrl'",
      "Set-Location '$apiRepo'",
      "dotnet run --no-build --no-launch-profile --project '$apiProj' --urls '$ApiUrl'"
    ) -join '; '

    Write-Info ("Starting API (new window) at {0}" -f $ApiUrl)
    $psProc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-Command', $cmd) -PassThru
    "$($psProc.Id)" | Out-File -FilePath $pidFile -Encoding ASCII -Force
    Start-Sleep -Milliseconds 200

    $deadline = (Get-Date).AddSeconds(30)
    while(-not (Test-ApiSignature $ApiUrl) -and (Get-Date) -lt $deadline){ Start-Sleep -Milliseconds 300 }
    if (-not (Test-ApiSignature $ApiUrl)) { Write-Err ("API failed readiness probe at {0}" -f $ApiUrl); exit 1 }
    Write-Ok ("API ready: {0}" -f $ApiUrl)
  }
  'stop' {
    if (Test-Path $pidFile) {
      $apiPid = Get-Content $pidFile -Raw
      if ($apiPid) {
        Write-Info ("Stopping API window (PID {0})" -f $apiPid)
        try { Stop-Process -Id ([int]$apiPid) -Force -ErrorAction Stop } catch { Write-Warn $_ }
      }
      Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    } else {
      Write-Warn 'No PID file found; API may not be running.'
    }
  }
  default { throw "Unknown action: $Action" }
}
