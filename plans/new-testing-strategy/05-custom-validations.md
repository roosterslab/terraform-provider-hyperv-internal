# Custom Validations — Extensibility Guide

**Date**: December 3, 2025  
**Directory**: `tests/scenarios/custom-validations/`  
**Purpose**: Handle scenario-specific validation logic

---

## When to Use Custom Validations

### Use Standard Harness When:
- ✅ Validating VM exists/destroyed
- ✅ Checking disk created/removed
- ✅ Verifying policy allows path
- ✅ Standard Terraform lifecycle (init, apply, destroy)

### Use Custom Validation When:
- ⚠️ Checking specific configuration (firmware settings, TPM enabled)
- ⚠️ Validating error messages (negative tests)
- ⚠️ Complex multi-step checks (idempotency, cloning workflows)
- ⚠️ Authentication-specific data (whoami output)
- ⚠️ Performance/timing measurements

**Rule of Thumb**: If 3+ other scenarios need the same logic, add it to the harness. Otherwise, use custom validation.

---

## Custom Validation Pattern

### File Location
```
tests/scenarios/custom-validations/
├── Validate-WindowsPerfect.ps1
├── Validate-PathNegative.ps1
├── Validate-Idempotency.ps1
├── Validate-CloneVhd.ps1
└── Validate-WhoAmI.ps1
```

### Standard Signature

```powershell
<#
.SYNOPSIS
Custom validation for [scenario name]

.DESCRIPTION
Detailed description of what this validates

.PARAMETER Scenario
Scenario object from scenarios.json

.PARAMETER WorkingDir
Working directory (demo path)

.PARAMETER Endpoint
API endpoint URL
#>
param(
    [Parameter(Mandatory)]
    [hashtable]$Scenario,
    
    [Parameter(Mandatory)]
    [string]$WorkingDir,
    
    [string]$Endpoint = "http://localhost:5006"
)

# Validation logic here
# Throw exception on failure
# Write success messages with Write-HvLog
```

### Return Behavior
- **Success**: Script completes without throwing
- **Failure**: Throw exception with descriptive message
- **Logging**: Use `Write-HvLog` for status updates

---

## Example Implementations

### 1. Validate Path Negative (Negative Test)

**File**: `tests/scenarios/custom-validations/Validate-PathNegative.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir,
    [string]$Endpoint = "http://localhost:5006"
)

Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"

Write-HvLog "Validating path rejection (negative test)" -Level Info

# Read terraform log
$logPath = Join-Path $WorkingDir "terraform.log"
if (-not (Test-Path $logPath)) {
    throw "Terraform log not found: $logPath"
}

$logContent = Get-Content $logPath -Raw

# Check for expected error pattern
$errorPattern = $Scenario.expectations.errorPattern
if ($logContent -notmatch $errorPattern) {
    throw @"
Expected error pattern not found in logs
  Pattern: $errorPattern
  Log file: $logPath
  
  Log excerpt:
  $(($logContent -split "`n" | Select-Object -Last 20) -join "`n")
"@
}

Write-HvLog "✓ Error pattern validated: $errorPattern" -Level Success

# Optional: Verify specific policy message
if ($logContent -match "Policy violation: (.+)") {
    $policyMessage = $matches[1]
    Write-HvLog "Policy message: $policyMessage" -Level Info
}
```

**Triggered by**:
```json
{
  "id": "04-path-validate-negative",
  "expectations": {
    "expectFailure": true,
    "errorPattern": "path not allowed",
    "customValidation": "Validate-PathNegative.ps1"
  }
}
```

---

### 2. Validate Idempotency

**File**: `tests/scenarios/custom-validations/Validate-Idempotency.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir,
    [string]$Endpoint = "http://localhost:5006"
)

Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"

Write-HvLog "Validating idempotency (no-op reapply)" -Level Info

Push-Location $WorkingDir
try {
    # Run terraform plan with detailed exit code
    # Exit code 0 = no changes (idempotent)
    # Exit code 2 = changes detected (NOT idempotent)
    
    terraform plan -detailed-exitcode -no-color 2>&1 | Out-File "idempotency-check.log"
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-HvLog "✓ Idempotency verified: terraform plan detected no changes" -Level Success
    } elseif ($exitCode -eq 2) {
        # Read what changed
        $planOutput = Get-Content "idempotency-check.log" -Raw
        throw @"
Idempotency check FAILED
  terraform plan detected changes after initial apply
  
  Changes detected:
  $planOutput
"@
    } else {
        throw "terraform plan failed with exit code $exitCode"
    }
    
} finally {
    Pop-Location
}
```

**Triggered by**:
```json
{
  "id": "06-vm-idempotency",
  "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy"],
  "expectations": {
    "customValidation": "Validate-Idempotency.ps1"
  }
}
```

---

### 3. Validate Windows Perfect

**File**: `tests/scenarios/custom-validations/Validate-WindowsPerfect.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir,
    [string]$Endpoint = "http://localhost:5006"
)

Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"
Import-Module "$PSScriptRoot/../../harness/HvAssertions.psm1"

Write-HvLog "Validating Windows Perfect configuration" -Level Info

$vmName = $Scenario.expectations.vmName

# Get VM details from API
$vm = Invoke-RestMethod -Uri "$Endpoint/api/v2/vms/$vmName" -Method Get

# Validate Generation 2
if ($vm.generation -ne 2) {
    throw "Expected Generation 2, got: $($vm.generation)"
}
Write-HvLog "✓ Generation: 2" -Level Success

# Validate Secure Boot
if ($vm.firmware.secureBoot -ne $true) {
    throw "Secure Boot should be enabled"
}
Write-HvLog "✓ Secure Boot: Enabled" -Level Success

# Validate Secure Boot Template
$expectedTemplate = "MicrosoftWindows"
if ($vm.firmware.secureBootTemplate -ne $expectedTemplate) {
    throw "Expected Secure Boot template '$expectedTemplate', got: $($vm.firmware.secureBootTemplate)"
}
Write-HvLog "✓ Secure Boot Template: $expectedTemplate" -Level Success

# Validate TPM
if ($vm.security.tpm -ne $true) {
    throw "TPM should be enabled"
}
Write-HvLog "✓ TPM: Enabled" -Level Success

# Validate CPU/Memory
if ($vm.cpuCount -lt 2) {
    throw "Expected at least 2 CPUs, got: $($vm.cpuCount)"
}
Write-HvLog "✓ CPU Count: $($vm.cpuCount)" -Level Success

if ($vm.memoryMB -lt 2048) {
    throw "Expected at least 2048 MB memory, got: $($vm.memoryMB)"
}
Write-HvLog "✓ Memory: $($vm.memoryMB) MB" -Level Success

Write-HvLog "All Windows Perfect validations passed" -Level Success
```

**Triggered by**:
```json
{
  "id": "02-vm-windows-perfect",
  "expectations": {
    "vmName": "user-windows-vm",
    "customValidation": "Validate-WindowsPerfect.ps1"
  }
}
```

---

### 4. Validate Clone VHD

**File**: `tests/scenarios/custom-validations/Validate-CloneVhd.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir,
    [string]$Endpoint = "http://localhost:5006"
)

Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"

Write-HvLog "Validating VHD clone workflow" -Level Info

# Get Terraform outputs
Push-Location $WorkingDir
try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    $clonedDiskPath = $outputs.cloned_disk_path.value
    $templatePath = $outputs.template_path.value
    
    # Validate cloned disk exists
    if (-not (Test-Path $clonedDiskPath)) {
        throw "Cloned disk not found: $clonedDiskPath"
    }
    Write-HvLog "✓ Cloned disk exists: $clonedDiskPath" -Level Success
    
    # Validate template still exists (should not be deleted)
    if (-not (Test-Path $templatePath)) {
        throw "Template disk missing (should not be deleted): $templatePath"
    }
    Write-HvLog "✓ Template disk preserved: $templatePath" -Level Success
    
    # Validate clone is different file
    if ($clonedDiskPath -eq $templatePath) {
        throw "Cloned disk path matches template (not cloned?)"
    }
    Write-HvLog "✓ Clone is separate file" -Level Success
    
    # Optional: Validate file size
    $clonedSize = (Get-Item $clonedDiskPath).Length
    $templateSize = (Get-Item $templatePath).Length
    
    Write-HvLog "Clone size: $([math]::Round($clonedSize / 1GB, 2)) GB" -Level Info
    Write-HvLog "Template size: $([math]::Round($templateSize / 1GB, 2)) GB" -Level Info
    
} finally {
    Pop-Location
}

Write-HvLog "Clone validation passed" -Level Success
```

---

### 5. Validate WhoAmI

**File**: `tests/scenarios/custom-validations/Validate-WhoAmI.ps1`

```powershell
param(
    [Parameter(Mandatory)][hashtable]$Scenario,
    [Parameter(Mandatory)][string]$WorkingDir,
    [string]$Endpoint = "http://localhost:5006"
)

Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"

Write-HvLog "Validating WhoAmI data source" -Level Info

# Get Terraform outputs
Push-Location $WorkingDir
try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    # Validate whoami output exists
    if (-not $outputs.whoami) {
        throw "whoami output not found"
    }
    
    $whoami = $outputs.whoami.value
    
    # Validate user field
    if ([string]::IsNullOrWhiteSpace($whoami.user)) {
        throw "whoami.user is empty"
    }
    Write-HvLog "✓ User: $($whoami.user)" -Level Success
    
    # Validate auth_type field
    if ([string]::IsNullOrWhiteSpace($whoami.auth_type)) {
        throw "whoami.auth_type is empty"
    }
    Write-HvLog "✓ Auth Type: $($whoami.auth_type)" -Level Success
    
    # Validate policy output exists
    if (-not $outputs.policy) {
        throw "policy output not found"
    }
    
    $policy = $outputs.policy.value
    
    # Validate policy has roots
    if (-not $policy.roots -or $policy.roots.Count -eq 0) {
        throw "policy.roots is empty"
    }
    Write-HvLog "✓ Policy roots: $($policy.roots.Count) defined" -Level Success
    
    # Validate policy mode
    if ([string]::IsNullOrWhiteSpace($policy.mode)) {
        throw "policy.mode is empty"
    }
    Write-HvLog "✓ Policy mode: $($policy.mode)" -Level Success
    
} finally {
    Pop-Location
}

Write-HvLog "WhoAmI validation passed" -Level Success
```

---

## Validation Best Practices

### 1. Use Descriptive Error Messages

**Bad**:
```powershell
if ($vm.generation -ne 2) {
    throw "Generation check failed"
}
```

**Good**:
```powershell
if ($vm.generation -ne 2) {
    throw @"
VM Generation mismatch
  Expected: 2
  Actual: $($vm.generation)
  VM: $vmName
  
  This scenario requires a Generation 2 VM for UEFI/Secure Boot support.
"@
}
```

### 2. Log Intermediate Steps

```powershell
Write-HvLog "Checking VM generation..." -Level Debug
$vm = Invoke-RestMethod -Uri "$Endpoint/api/v2/vms/$vmName"
Write-HvLog "VM retrieved: $vmName (gen $($vm.generation))" -Level Debug

if ($vm.generation -ne 2) { throw "..." }
Write-HvLog "✓ Generation: 2" -Level Success
```

### 3. Handle Missing Data Gracefully

```powershell
# Check if output exists
if (-not $outputs.disk_path) {
    throw "Terraform output 'disk_path' not found. Check main.tf has: output `"disk_path`" { value = ... }"
}

# Check if file exists
if (-not (Test-Path $diskPath)) {
    throw @"
Disk file not found: $diskPath
  
  Possible causes:
    1. Terraform apply succeeded but disk creation failed
    2. Path is incorrect in Terraform output
    3. Permissions issue accessing the path
"@
}
```

### 4. Import Required Modules

```powershell
# Always import harness modules for consistency
Import-Module "$PSScriptRoot/../../harness/HvHelpers.psm1"
Import-Module "$PSScriptRoot/../../harness/HvAssertions.psm1"

# Use harness functions
Write-HvLog "Starting validation" -Level Info
Assert-HvVmExists -Name $vmName -Endpoint $Endpoint
```

### 5. Clean Up After Yourself

```powershell
Push-Location $WorkingDir
try {
    # Validation logic
} finally {
    Pop-Location
    # Clean up temp files if any
}
```

---

## Testing Custom Validations

### Unit Test Pattern

```powershell
# tests/scenarios/custom-validations/Validate-WindowsPerfect.Tests.ps1

Describe "Validate-WindowsPerfect" {
    It "Throws on non-Generation 2 VM" {
        # Mock scenario and VM response
        $scenario = @{ expectations = @{ vmName = "test-vm" } }
        $mockVm = @{ generation = 1 }
        
        Mock Invoke-RestMethod { return $mockVm }
        
        { & ./Validate-WindowsPerfect.ps1 -Scenario $scenario -WorkingDir "." } |
            Should -Throw "*Generation*"
    }
    
    It "Passes on valid configuration" {
        $scenario = @{ expectations = @{ vmName = "test-vm" } }
        $mockVm = @{
            generation = 2
            firmware = @{ secureBoot = $true; secureBootTemplate = "MicrosoftWindows" }
            security = @{ tpm = $true }
            cpuCount = 4
            memoryMB = 4096
        }
        
        Mock Invoke-RestMethod { return $mockVm }
        
        { & ./Validate-WindowsPerfect.ps1 -Scenario $scenario -WorkingDir "." } |
            Should -Not -Throw
    }
}
```

### Integration Test

```powershell
# Run scenario with custom validation
tests/run-all.ps1 -Id "02-vm-windows-perfect" -AutoStartApi -VerboseHttp

# Check logs for validation output
cat demos/02-vm-windows-perfect/terraform.log | Select-String "Validating Windows Perfect"
```

---

## When to Promote to Harness

If you find yourself:
- Writing the same validation in 3+ custom scripts
- Copying code between validations
- Wishing for a reusable assertion

**Then**: Move it to `HvAssertions.psm1`

**Example**:
```powershell
# Instead of repeating in 5 validations:
if ($vm.generation -ne 2) { throw "..." }

# Add to HvAssertions.psm1:
function Assert-HvVmGeneration {
    param([string]$Name, [int]$Generation, [string]$Endpoint)
    
    $vm = Invoke-RestMethod -Uri "$Endpoint/api/v2/vms/$Name"
    if ($vm.generation -ne $Generation) {
        throw "VM '$Name' generation mismatch: expected $Generation, got $($vm.generation)"
    }
}

# Now use in validations:
Assert-HvVmGeneration -Name $vmName -Generation 2 -Endpoint $Endpoint
```

---

## Summary

**Custom validations**:
- ✅ Handle scenario-specific logic
- ✅ Throw exceptions on failure
- ✅ Use `Write-HvLog` for status
- ✅ Import harness modules
- ✅ Have descriptive error messages
- ✅ Are optional (standard harness handles most cases)

**When to use**:
- Complex configuration checks
- Negative test validation
- Multi-step workflows
- Scenario-unique assertions

**Next steps**:
1. Create `tests/scenarios/custom-validations/` directory
2. Implement validations for pilot demos (04, 06)
3. Test each validation independently
4. Integrate with harness
