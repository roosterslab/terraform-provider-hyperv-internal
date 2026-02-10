# Scenarios Registry — Schema and Examples

**Date**: December 3, 2025  
**File**: `tests/scenarios/scenarios.json`  
**Format**: JSON array of scenario objects

---

## Schema Definition

### Scenario Object

```typescript
interface Scenario {
  // Identification
  id: string;                    // Unique identifier (matches demo directory name)
  description?: string;          // Human-readable description
  
  // Location
  path: string;                  // Relative path to demo directory from repo root
  
  // Classification
  tags: string[];                // Tags for filtering (smoke, critical, full, etc.)
  priority?: "high" | "medium" | "low";  // Optional priority
  
  // Execution
  steps: string[];               // Ordered list of steps to execute
  timeout?: number;              // Max execution time in seconds (default: 300)
  
  // Configuration
  variables?: Record<string, any>;  // Terraform variables to pass
  expectations: Expectations;       // What to validate
}

interface Expectations {
  // VM expectations
  vmName?: string;               // Expected VM name
  vmCount?: number;              // Number of VMs created
  vmState?: "Off" | "Running";   // Expected VM state
  
  // Disk expectations
  diskScenario?: "new-auto" | "new-custom" | "clone-auto" | "clone-custom" | "attach";
  diskCount?: number;            // Number of disks
  disksShouldBeDeleted?: boolean;  // True if disks should be removed on destroy
  
  // Network expectations
  switchCount?: number;          // Number of switches
  adapterCount?: number;         // Number of network adapters
  
  // Failure expectations (negative tests)
  expectFailure?: boolean;       // True if test should fail
  errorPattern?: string;         // Regex pattern for expected error message
  
  // Custom validation
  customValidation?: string;     // Path to custom validation script (relative to custom-validations/)
}
```

---

## Standard Tags

| Tag | Purpose | When to Use |
|-----|---------|-------------|
| `smoke` | Fast sanity check | Basic functionality, <2 min, run on every commit |
| `critical` | PR gate | Must pass before merge, ~10 min total |
| `full` | Complete suite | All scenarios, run nightly or on release |
| `vm` | VM-related | Tests VM creation, configuration, lifecycle |
| `disk` | Disk operations | Tests disk creation, cloning, attachment |
| `network` | Networking | Tests switches, adapters, VLANs |
| `policy` | Policy enforcement | Tests RBAC, path validation, name patterns |
| `negative` | Negative tests | Expects failures, validates error handling |
| `idempotency` | Idempotency checks | Validates no-op applies |
| `auth` | Authentication | Tests whoami, SSPI, NTLM, impersonation |

---

## Standard Steps

| Step | Purpose | Terraform Command | Expected Exit Code |
|------|---------|-------------------|--------------------|
| `Init` | Initialize Terraform | `terraform init` | 0 |
| `Apply` | Create resources | `terraform apply -auto-approve` | 0 |
| `ApplyExpectFail` | Expect apply to fail | `terraform apply -auto-approve` | Non-zero |
| `Validate` | Run assertions | N/A (calls assertions) | N/A |
| `ReapplyNoop` | Idempotency check | `terraform plan -detailed-exitcode` | 0 (no changes) |
| `Destroy` | Destroy resources | `terraform destroy -auto-approve` | 0 |
| `ValidateDestroyed` | Verify cleanup | N/A (calls assertions) | N/A |
| `ValidateErrorMessage` | Check error text | N/A (reads logs) | N/A |

---

## Example Scenarios

### 1. Simple VM (Smoke Test)

```json
{
  "id": "01-simple-vm-new-auto",
  "description": "Basic VM with auto disk path",
  "path": "demos/01-simple-vm-new-auto",
  "tags": ["smoke", "critical", "vm", "disk"],
  "priority": "high",
  "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
  "timeout": 180,
  "expectations": {
    "vmName": "user-tfv2-demo",
    "vmCount": 1,
    "vmState": "Off",
    "diskScenario": "new-auto",
    "diskCount": 1,
    "disksShouldBeDeleted": true
  }
}
```

**Use**: Quick sanity check, runs in <2 minutes

---

### 2. Windows Perfect (Complete Configuration)

```json
{
  "id": "02-vm-windows-perfect",
  "description": "Full Windows VM with firmware, security, TPM",
  "path": "demos/02-vm-windows-perfect",
  "tags": ["critical", "vm", "firmware", "security"],
  "priority": "high",
  "steps": ["Init", "Apply", "Validate", "Destroy", "ValidateDestroyed"],
  "timeout": 300,
  "expectations": {
    "vmName": "user-windows-vm",
    "vmCount": 1,
    "diskScenario": "new-auto",
    "diskCount": 1,
    "customValidation": "Validate-WindowsPerfect.ps1"
  }
}
```

**Use**: Validates complex VM configuration (Gen2, secure boot, TPM)

---

### 3. Path Validation Negative Test

```json
{
  "id": "04-path-validate-negative",
  "description": "Policy rejection on disallowed path",
  "path": "demos/04-path-validate-negative",
  "tags": ["critical", "policy", "negative"],
  "priority": "high",
  "steps": ["Init", "ApplyExpectFail", "ValidateErrorMessage"],
  "timeout": 120,
  "expectations": {
    "expectFailure": true,
    "errorPattern": "path not allowed|policy violation",
    "customValidation": "Validate-PathNegative.ps1"
  }
}
```

**Use**: Validates policy enforcement (negative test)

---

### 4. Idempotency Check

```json
{
  "id": "06-vm-idempotency",
  "description": "No-op apply after initial creation",
  "path": "demos/06-vm-idempotency",
  "tags": ["critical", "idempotency"],
  "priority": "medium",
  "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
  "timeout": 200,
  "expectations": {
    "vmName": "user-idem-test",
    "vmCount": 1,
    "diskCount": 1,
    "customValidation": "Validate-Idempotency.ps1"
  }
}
```

**Use**: Validates Terraform state doesn't drift

---

### 5. VM with Switch

```json
{
  "id": "03-vm-with-switch",
  "description": "VM with network switch and adapter",
  "path": "demos/03-vm-with-switch",
  "tags": ["critical", "vm", "network"],
  "priority": "high",
  "steps": ["Init", "Apply", "Validate", "Destroy", "ValidateDestroyed"],
  "timeout": 240,
  "expectations": {
    "vmName": "user-network-vm",
    "vmCount": 1,
    "diskCount": 1,
    "switchCount": 1,
    "adapterCount": 1
  }
}
```

**Use**: Validates network integration

---

### 6. Clone VHD

```json
{
  "id": "16_windows_perfect_with_copy_vhdx",
  "description": "Clone VHD from template",
  "path": "demos/16_windows_perfect_with_copy_vhdx",
  "tags": ["full", "disk", "clone"],
  "priority": "medium",
  "steps": ["Init", "Apply", "Validate", "Destroy", "ValidateDestroyed"],
  "timeout": 600,
  "expectations": {
    "vmName": "user-cloned-vm",
    "vmCount": 1,
    "diskScenario": "clone-auto",
    "diskCount": 1,
    "disksShouldBeDeleted": true,
    "customValidation": "Validate-CloneVhd.ps1"
  }
}
```

**Use**: Validates VHD cloning workflow (slower, ~5-8 min)

---

### 7. WhoAmI Data Source

```json
{
  "id": "00-whoami-and-policy",
  "description": "Identity and policy data sources",
  "path": "demos/00-whoami-and-policy",
  "tags": ["smoke", "auth", "policy"],
  "priority": "high",
  "steps": ["Init", "Apply", "Validate"],
  "timeout": 60,
  "expectations": {
    "vmCount": 0,
    "customValidation": "Validate-WhoAmI.ps1"
  }
}
```

**Use**: Tests data sources without creating VMs (fast)

---

### 8. Authentication Tests

```json
{
  "id": "17-who-am-i-current-user-sspi",
  "description": "Windows Integrated Auth (current user)",
  "path": "demos/17-who-am-i-current-user-sspi",
  "tags": ["full", "auth"],
  "priority": "low",
  "steps": ["Init", "Apply", "Validate"],
  "timeout": 60,
  "expectations": {
    "vmCount": 0,
    "customValidation": "Validate-AuthSSPI.ps1"
  }
},
{
  "id": "18-who-am-i-impersonation",
  "description": "Auth with explicit credentials",
  "path": "demos/18-who-am-i-impersonation",
  "tags": ["full", "auth"],
  "priority": "low",
  "steps": ["Init", "Apply", "Validate"],
  "timeout": 60,
  "variables": {
    "username": "testuser",
    "password": "TestPass123!"
  },
  "expectations": {
    "vmCount": 0,
    "customValidation": "Validate-AuthImpersonation.ps1"
  }
}
```

**Use**: Validates different authentication methods

---

## Complete Registry Example

```json
[
  {
    "id": "01-simple-vm-new-auto",
    "path": "demos/01-simple-vm-new-auto",
    "tags": ["smoke", "critical", "vm", "disk"],
    "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
    "expectations": {
      "vmName": "user-tfv2-demo",
      "vmCount": 1,
      "diskScenario": "new-auto"
    }
  },
  {
    "id": "04-path-validate-negative",
    "path": "demos/04-path-validate-negative",
    "tags": ["critical", "policy", "negative"],
    "steps": ["Init", "ApplyExpectFail", "ValidateErrorMessage"],
    "expectations": {
      "expectFailure": true,
      "errorPattern": "path not allowed",
      "customValidation": "Validate-PathNegative.ps1"
    }
  },
  {
    "id": "06-vm-idempotency",
    "path": "demos/06-vm-idempotency",
    "tags": ["critical", "idempotency"],
    "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
    "expectations": {
      "vmName": "user-idem-test",
      "vmCount": 1,
      "customValidation": "Validate-Idempotency.ps1"
    }
  }
]
```

---

## Validation Rules

### Registry Level

- [ ] All IDs are unique
- [ ] All paths exist
- [ ] All tags are from standard set (or documented as custom)
- [ ] All steps are valid step names

### Scenario Level

- [ ] ID matches directory name convention
- [ ] Path points to existing demo directory
- [ ] At least one tag specified
- [ ] Steps array is not empty
- [ ] If `expectFailure=true`, must have `ApplyExpectFail` step
- [ ] If `expectFailure=true`, must have `errorPattern`
- [ ] If `customValidation` specified, file must exist

---

## Adding New Scenarios

### Step 1: Create Demo

```powershell
# Create demo directory
New-Item -ItemType Directory -Path demos/20-new-feature

# Create Terraform config
New-Item -ItemType File -Path demos/20-new-feature/main.tf
```

### Step 2: Add to Registry

```json
{
  "id": "20-new-feature",
  "description": "Brief description of what this tests",
  "path": "demos/20-new-feature",
  "tags": ["full", "feature-name"],
  "steps": ["Init", "Apply", "Validate", "Destroy", "ValidateDestroyed"],
  "expectations": {
    "vmName": "user-feature-vm",
    "vmCount": 1
  }
}
```

### Step 3: Test

```powershell
# Test single scenario
tests/run-all.ps1 -Id "20-new-feature" -AutoStartApi

# Or by tag
tests/run-all.ps1 -Tags "feature-name" -AutoStartApi
```

---

## Tag-Based Test Suites

### Smoke Suite (Fast, ~2 min)

```json
// Run with: tests/run-all.ps1 -Tags smoke
// Scenarios: 1-2 basic tests
[
  "01-simple-vm-new-auto",
  "00-whoami-and-policy"
]
```

### Critical Suite (PR Gate, ~10 min)

```json
// Run with: tests/run-all.ps1 -Tags critical
// Scenarios: 5-8 must-pass tests
[
  "01-simple-vm-new-auto",
  "02-vm-windows-perfect",
  "04-path-validate-negative",
  "06-vm-idempotency",
  "13-disk-unified-new-auto",
  "03-vm-with-switch"
]
```

### Full Suite (Nightly, ~30 min)

```json
// Run with: tests/run-all.ps1 -Tags full
// Scenarios: All 19 demos
```

---

## Next Steps

1. Create `tests/scenarios/scenarios.json` with initial 3 scenarios
2. Validate JSON schema
3. Test filtering by tags
4. Add remaining scenarios incrementally
5. Document custom tags as they're added
