param(
  [string]$Endpoint = 'http://localhost:5006',
  [Parameter(Mandatory=$true)][string]$VmName,
  [Parameter(Mandatory=$true)][string]$Username,
  [Parameter(Mandatory=$true)][string]$Password
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$devTfrc = Join-Path $root 'dev.tfrc'

$secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($Username, $secure)

$lines = @()
$lines += "`$env:TF_CLI_CONFIG_FILE='${devTfrc}'"
$lines += "Set-Location '$PSScriptRoot'"
$lines += "terraform destroy -auto-approve -input=false -var endpoint='$Endpoint' -var vm_name='$VmName'"
$cmd = ($lines | ForEach-Object { $_ + ';' }) -join ' '

Start-Process -FilePath 'powershell.exe' -Credential $cred -WorkingDirectory $env:SystemRoot -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command', $cmd)

