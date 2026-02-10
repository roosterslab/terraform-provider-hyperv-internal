# Example environment for demo 18 (impersonation)
# Copy this file to env.local.ps1 and set real values. env.local.ps1 is git-ignored.

# API endpoint
$script:EndpointDefault = 'http://localhost:5000'

# Explicit credentials to impersonate (DOMAIN\\user or MACHINE\\user)
$script:UsernameDefault = 'Workspace\\systemcore-user'
$script:PasswordDefault = 'CHANGE_ME'

# Auth behavior toggles
# Leave false for demo 18 (uses SSPI impersonation). Set to $true only if you
# explicitly want to enable raw NTLM fallback (not recommended here).
$script:AllowRawNtlmDefault = $false
