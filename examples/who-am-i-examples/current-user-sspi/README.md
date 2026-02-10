# Who Am I — Current User (SSPI)

Runs the `hypervapiv2_whoami` data source using Windows Integrated Auth (Negotiate) as the current user.

Quick start
```powershell
cd "$PSScriptRoot"
./Run.ps1 -Endpoint "http://localhost:5000" -BuildProvider
./Test.ps1
```

Notes
- Uses local provider via `dev.tfrc` override.
- Raw NTLM is disabled for this example.
