# Example environment for demo 19 (raw NTLM)
# Copy this file to env.local.ps1 and set real values. env.local.ps1 is git-ignored.

# API endpoint
$script:EndpointDefault = 'http://localhost:5000'

# Explicit credentials (DOMAIN\\user or MACHINE\\user)
$script:UsernameDefault = 'Workspace\\systemcore-user'
$script:PasswordDefault = 'CHANGE_ME'

# Auth behavior toggles
# For this demo we intentionally enable raw NTLM fallback.
$script:AllowRawNtlmDefault = $false  # set to $true only if your server accepts NTLM
