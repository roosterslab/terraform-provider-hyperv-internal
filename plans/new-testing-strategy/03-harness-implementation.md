# Harness Implementation — Technical Design

**Date**: December 3, 2025  
**Module**: `tests/harness/`  
**Language**: PowerShell 7+

---

## Module Structure

```
tests/harness/
├── HvTestHarness.psm1           # Core orchestration
├── HvAssertions.psm1            # Shared assertion library
├── HvApiManagement.psm1         # API lifecycle management
├── HvHelpers.psm1               # Utilities (logging, JSON, etc.)
└── HvSteps.psm1                 # Individual test steps
```

---

## 1. HvTestHarness.psm1 — Main Orchestrator

### Primary Function: `Invoke-HvScenario`

```powershell
function Invoke-HvScenario {
    <#
    .SYNOPSIS
    Executes a complete test scenario
    
    .PARAMETER Scenario
    Scenario object from scenarios.json
    
    .PARAMETER AutoStartApi
    Automatically start API if not running
    
    .PARAMETER VerboseHttp
    Enable TF_LOG=DEBUG for HTTP tracing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Scenario,
        
        [switch]$AutoStartApi,
        [switch]$VerboseHttp,
        [string]$Endpoint = "http://localhost:5006"
    )
    
    $result = @{
        id = $Scenario.id
        status = "running"
        startTime = Get-Date
        checks = @()
        errors = @()
        warnings = @()
    }
    
    try {
        Write-HvLog "Starting scenario: $($Scenario.id)" -Level Info
        
        # 1. Ensure API is running
        if ($AutoStartApi) {
            $apiStarted = Start-HvApiIfNeeded -Endpoint $Endpoint
        }
        
        # 2. Setup environment
        $workingDir = Resolve-Path $Scenario.path
        Push-Location $workingDir
        
        # Setup dev override
        Initialize-HvDevOverride -WorkingDir $workingDir
        
        # Setup TF environment
        if ($VerboseHttp) {
            $env:TF_LOG = "DEBUG"
        }
        $env:TF_CLI_CONFIG_FILE = "$workingDir/dev.tfrc"
        
        # 3. Execute steps
        foreach ($step in $Scenario.steps) {
            $stepResult = Invoke-HvStep -Step $step -Scenario $Scenario -Endpoint $Endpoint
            $result.checks += $stepResult
            
            if ($stepResult.passed -eq $false) {
                throw "Step '$step' failed: $($stepResult.message)"
            }
        }
        
        # 4. Run custom validation if specified
        if ($Scenario.expectations.customValidation) {
            $validationScript = Join-Path $PSScriptRoot "../scenarios/custom-validations/$($Scenario.expectations.customValidation)"
            if (Test-Path $validationScript) {
                Write-HvLog "Running custom validation: $($Scenario.expectations.customValidation)" -Level Info
                & $validationScript -Scenario $Scenario -WorkingDir $workingDir -Endpoint $Endpoint
            }
        }
        
        $result.status = "passed"
        Write-HvLog "Scenario passed: $($Scenario.id)" -Level Success
        
    } catch {
        $result.status = "failed"
        $result.errors += $_.Exception.Message
        Write-HvLog "Scenario failed: $($Scenario.id) - $($_.Exception.Message)" -Level Error
    } finally {
        Pop-Location
        
        # Cleanup API if we started it
        if ($AutoStartApi -and $apiStarted) {
            Stop-HvApi
        }
        
        $result.endTime = Get-Date
        $result.duration = ($result.endTime - $result.startTime).TotalSeconds
    }
    
    return $result
}
```

### Helper: `Invoke-HvStep`

```powershell
function Invoke-HvStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Step,
        
        [Parameter(Mandatory)]
        [hashtable]$Scenario,
        
        [string]$Endpoint
    )
    
    $stepResult = @{
        step = $Step
        startTime = Get-Date
        passed = $false
        message = ""
    }
    
    try {
        Write-HvLog "Executing step: $Step" -Level Info
        
        switch ($Step) {
            "Init" {
                Invoke-HvStepInit
                $stepResult.message = "Terraform initialized"
            }
            "Apply" {
                Invoke-HvStepApply -Scenario $Scenario
                $stepResult.message = "Terraform applied successfully"
            }
            "ApplyExpectFail" {
                Invoke-HvStepApplyExpectFail -Scenario $Scenario
                $stepResult.message = "Terraform apply failed as expected"
            }
            "Validate" {
                Invoke-HvStepValidate -Scenario $Scenario -Endpoint $Endpoint
                $stepResult.message = "Validation checks passed"
            }
            "ReapplyNoop" {
                Invoke-HvStepReapplyNoop
                $stepResult.message = "Reapply was no-op (idempotent)"
            }
            "Destroy" {
                Invoke-HvStepDestroy
                $stepResult.message = "Terraform destroyed successfully"
            }
            "ValidateDestroyed" {
                Invoke-HvStepValidateDestroyed -Scenario $Scenario -Endpoint $Endpoint
                $stepResult.message = "Destroy validation passed"
            }
            "ValidateErrorMessage" {
                Invoke-HvStepValidateErrorMessage -Scenario $Scenario
                $stepResult.message = "Error message validated"
            }
            default {
                throw "Unknown step: $Step"
            }
        }
        
        $stepResult.passed = $true
        Write-HvLog "Step passed: $Step" -Level Success
        
    } catch {
        $stepResult.passed = $false
        $stepResult.message = $_.Exception.Message
        Write-HvLog "Step failed: $Step - $($_.Exception.Message)" -Level Error
    } finally {
        $stepResult.endTime = Get-Date
        $stepResult.duration = ($stepResult.endTime - $stepResult.startTime).TotalSeconds
    }
    
    return $stepResult
}
```

---

## 2. HvSteps.psm1 — Test Step Implementations

### `Invoke-HvStepInit`

```powershell
function Invoke-HvStepInit {
    Write-HvLog "Running: terraform init" -Level Debug
    
    terraform init -no-color 2>&1 | Tee-Object -FilePath "terraform.log"
    
    if ($LASTEXITCODE -ne 0) {
        throw "terraform init failed with exit code $LASTEXITCODE"
    }
}
```

### `Invoke-HvStepApply`

```powershell
function Invoke-HvStepApply {
    param([hashtable]$Scenario)
    
    Write-HvLog "Running: terraform apply" -Level Debug
    
    # Generate tfvars if scenario has variables
    if ($Scenario.variables) {
        $tfvars = $Scenario.variables.GetEnumerator() | ForEach-Object {
            "$($_.Key) = `"$($_.Value)`""
        }
        $tfvars | Out-File "terraform.auto.tfvars"
    }
    
    terraform apply -auto-approve -no-color 2>&1 | Tee-Object -FilePath "terraform.log" -Append
    
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed with exit code $LASTEXITCODE"
    }
}
```

### `Invoke-HvStepApplyExpectFail`

```powershell
function Invoke-HvStepApplyExpectFail {
    param([hashtable]$Scenario)
    
    Write-HvLog "Running: terraform apply (expecting failure)" -Level Debug
    
    terraform apply -auto-approve -no-color 2>&1 | Tee-Object -FilePath "terraform.log" -Append
    
    if ($LASTEXITCODE -eq 0) {
        throw "terraform apply succeeded, but failure was expected"
    }
    
    Write-HvLog "terraform apply failed as expected (exit code: $LASTEXITCODE)" -Level Success
}
```

### `Invoke-HvStepValidate`

```powershell
function Invoke-HvStepValidate {
    param(
        [hashtable]$Scenario,
        [string]$Endpoint
    )
    
    $expectations = $Scenario.expectations
    
    # Standard validations based on expectations
    if ($expectations.vmName) {
        Assert-HvVmExists -Name $expectations.vmName -Endpoint $Endpoint
    }
    
    if ($expectations.vmCount) {
        $outputs = terraform output -json | ConvertFrom-Json
        # Assert VM count matches
    }
    
    if ($expectations.diskScenario) {
        # Validate disk scenario (new-auto, clone, etc.)
        Assert-HvDiskScenario -Scenario $expectations.diskScenario -Endpoint $Endpoint
    }
    
    Write-HvLog "All standard validations passed" -Level Success
}
```

### `Invoke-HvStepReapplyNoop`

```powershell
function Invoke-HvStepReapplyNoop {
    Write-HvLog "Running: terraform plan -detailed-exitcode (idempotency check)" -Level Debug
    
    terraform plan -detailed-exitcode -no-color 2>&1 | Tee-Object -FilePath "terraform.log" -Append
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-HvLog "No changes detected (idempotent)" -Level Success
    } elseif ($exitCode -eq 2) {
        throw "Idempotency check FAILED: terraform plan detected changes"
    } else {
        throw "terraform plan failed with exit code $exitCode"
    }
}
```

### `Invoke-HvStepDestroy`

```powershell
function Invoke-HvStepDestroy {
    Write-HvLog "Running: terraform destroy" -Level Debug
    
    terraform destroy -auto-approve -no-color 2>&1 | Tee-Object -FilePath "terraform.log" -Append
    
    if ($LASTEXITCODE -ne 0) {
        throw "terraform destroy failed with exit code $LASTEXITCODE"
    }
}
```

### `Invoke-HvStepValidateDestroyed`

```powershell
function Invoke-HvStepValidateDestroyed {
    param(
        [hashtable]$Scenario,
        [string]$Endpoint
    )
    
    $expectations = $Scenario.expectations
    
    if ($expectations.vmName) {
        Assert-HvVmDestroyed -Name $expectations.vmName -Endpoint $Endpoint
    }
    
    # Check disks removed (if delete_disks=true)
    if ($expectations.disksShouldBeDeleted) {
        # Assert VHDX files removed
    }
    
    Write-HvLog "Destroy validation passed" -Level Success
}
```

---

## 3. HvAssertions.psm1 — Shared Assertions

### `Assert-HvVmExists`

```powershell
function Assert-HvVmExists {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Endpoint = "http://localhost:5006"
    )
    
    Write-HvLog "Asserting VM exists: $Name" -Level Debug
    
    try {
        $response = Invoke-RestMethod -Uri "$Endpoint/api/v2/vms/$Name" -Method Get
        
        if ($response.name -ne $Name) {
            throw "VM name mismatch: expected '$Name', got '$($response.name)'"
        }
        
        Write-HvLog "✓ VM exists: $Name (state: $($response.state))" -Level Success
        return $response
        
    } catch {
        throw "VM does not exist: $Name - $($_.Exception.Message)"
    }
}
```

### `Assert-HvVmDestroyed`

```powershell
function Assert-HvVmDestroyed {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Endpoint = "http://localhost:5006"
    )
    
    Write-HvLog "Asserting VM destroyed: $Name" -Level Debug
    
    try {
        $response = Invoke-RestMethod -Uri "$Endpoint/api/v2/vms/$Name" -Method Get
        throw "VM still exists: $Name (should have been destroyed)"
        
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-HvLog "✓ VM destroyed: $Name" -Level Success
        } else {
            throw "Unexpected error checking VM: $($_.Exception.Message)"
        }
    }
}
```

### `Assert-HvDiskExists`

```powershell
function Assert-HvDiskExists {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-HvLog "Asserting disk exists: $Path" -Level Debug
    
    if (-not (Test-Path $Path)) {
        throw "Disk does not exist: $Path"
    }
    
    Write-HvLog "✓ Disk exists: $Path" -Level Success
}
```

### `Assert-HvPolicyAllows`

```powershell
function Assert-HvPolicyAllows {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Operation = "create",
        [string]$Endpoint = "http://localhost:5006"
    )
    
    Write-HvLog "Asserting policy allows: $Path" -Level Debug
    
    $body = @{
        path = $Path
        operation = $Operation
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$Endpoint/policy/validate-path" -Method Post `
        -Body $body -ContentType "application/json"
    
    if ($response.allowed -ne $true) {
        throw "Policy does not allow path: $Path - $($response.message)"
    }
    
    Write-HvLog "✓ Policy allows: $Path" -Level Success
}
```

---

## 4. HvApiManagement.psm1 — API Lifecycle

### `Start-HvApiIfNeeded`

```powershell
function Start-HvApiIfNeeded {
    param([string]$Endpoint = "http://localhost:5006")
    
    Write-HvLog "Checking if API is running: $Endpoint" -Level Debug
    
    try {
        Invoke-RestMethod -Uri "$Endpoint/api/v2/vms" -Method Get -TimeoutSec 2 | Out-Null
        Write-HvLog "API already running" -Level Info
        return $false  # Didn't start (was already running)
        
    } catch {
        Write-HvLog "API not running, starting..." -Level Info
        
        $scriptPath = "$PSScriptRoot/../../scripts/Run-ApiForExample.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -Action start
        } else {
            throw "API management script not found: $scriptPath"
        }
        
        return $true  # Started API
    }
}
```

### `Stop-HvApi`

```powershell
function Stop-HvApi {
    Write-HvLog "Stopping API" -Level Info
    
    $scriptPath = "$PSScriptRoot/../../scripts/Run-ApiForExample.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -Action stop
    }
}
```

---

## 5. HvHelpers.psm1 — Utilities

### `Write-HvLog`

```powershell
function Write-HvLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("Debug", "Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    $color = switch ($Level) {
        "Debug"   { "Gray" }
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }
    
    $prefix = switch ($Level) {
        "Debug"   { "[DEBUG]" }
        "Info"    { "[INFO ]" }
        "Success" { "[ OK  ]" }
        "Warning" { "[WARN ]" }
        "Error"   { "[ERROR]" }
    }
    
    Write-Host "$timestamp $prefix $Message" -ForegroundColor $color
}
```

### `Initialize-HvDevOverride`

```powershell
function Initialize-HvDevOverride {
    param([string]$WorkingDir)
    
    $binPath = Resolve-Path "$PSScriptRoot/../../bin"
    
    $devOverride = @"
provider_installation {
  dev_overrides {
    "vinitsiriya/hypervapiv2" = "$binPath"
  }
  direct {}
}
"@
    
    Set-Content -Path "$WorkingDir/dev.tfrc" -Value $devOverride
    Write-HvLog "Created dev override: $WorkingDir/dev.tfrc" -Level Debug
}
```

---

## Module Exports

Each module should export its public functions:

```powershell
# HvTestHarness.psm1
Export-ModuleMember -Function Invoke-HvScenario

# HvAssertions.psm1
Export-ModuleMember -Function Assert-*

# HvApiManagement.psm1
Export-ModuleMember -Function Start-HvApiIfNeeded, Stop-HvApi

# HvHelpers.psm1
Export-ModuleMember -Function Write-HvLog, Initialize-HvDevOverride
```

---

## Usage Example

```powershell
# Import harness
Import-Module tests/harness/HvTestHarness.psm1

# Load scenario
$scenario = @{
    id = "01-simple-vm-new-auto"
    path = "demos/01-simple-vm-new-auto"
    tags = @("smoke", "critical")
    steps = @("Init", "Apply", "Validate", "Destroy", "ValidateDestroyed")
    expectations = @{
        vmName = "user-test-vm"
        vmCount = 1
        diskScenario = "new-auto"
    }
}

# Run scenario
$result = Invoke-HvScenario -Scenario $scenario -AutoStartApi

# Check result
if ($result.status -eq "passed") {
    Write-Host "Test passed!" -ForegroundColor Green
} else {
    Write-Host "Test failed: $($result.errors)" -ForegroundColor Red
}
```

---

## Testing the Harness

```powershell
# Unit test individual steps
Invoke-Pester tests/harness/HvSteps.Tests.ps1

# Integration test full harness
Invoke-Pester tests/harness/HvTestHarness.Tests.ps1
```

---

## Error Handling Strategy

1. **Step failures**: Throw exceptions, harness catches and records
2. **API failures**: Retry logic for transient errors
3. **Terraform failures**: Capture output, include in error message
4. **Cleanup failures**: Log but don't fail test (best effort)

---

## Performance Considerations

- **Parallel execution**: Harness supports running scenarios in parallel (future enhancement)
- **API caching**: Reuse API instance across scenarios
- **Terraform caching**: Keep .terraform directory between runs

---

## Next Steps

1. Implement core harness (HvTestHarness.psm1)
2. Add basic assertions (HvAssertions.psm1)
3. Test with one simple scenario
4. Iterate and add more features
