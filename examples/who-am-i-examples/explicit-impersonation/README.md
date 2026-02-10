# Who Am I — Explicit Impersonation (SSPI)

Uses username/password on Windows to impersonate and authenticate via SSPI Negotiate.

Quick start
```powershell
cd "$PSScriptRoot"
./Run.ps1 -Endpoint "http://localhost:5000" -Username "Workspace\systemcore-user" -Password "0202" -BuildProvider
./Test.ps1
```

Notes
- Uses local provider via `dev.tfrc` override.
- Raw NTLM is disabled; this path leverages Windows impersonation + SSPI.
