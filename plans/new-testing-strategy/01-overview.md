# New Testing Strategy — Overview

**Date**: December 3, 2025  
**Status**: 🎯 Proposed Architecture  
**Goal**: Replace duplicated demo scripts with DRY harness + data-driven scenarios

---

## Problem Statement

### Current State Issues

1. **19 demos with duplicated Test.ps1 scripts** (~200 lines each)
   - Same apply/validate/destroy logic repeated
   - Hard to maintain (change requires updating 19 files)
   - No central visibility of what's tested

2. **No test layering**
   - E2E demos exist, but no unit or contract tests
   - Can't quickly validate logic without full Hyper-V setup

3. **CI/CD bottleneck**
   - Running all 19 demos takes 30-45 minutes
   - No way to run subsets (smoke, critical, full)

---

## Proposed Solution

### Three-Layer Testing Architecture

```
┌─────────────────────────────────────────┐
│  Layer 3: E2E Scenarios (Harness+Data) │  ← 19 demos, but DRY
│  • Harness: tests/harness/             │
│  • Registry: scenarios.json            │
│  • Tags: smoke, critical, full         │
└─────────────────────────────────────────┘
                    ↑
┌─────────────────────────────────────────┐
│  Layer 2: Contract Tests (Go)          │  ← API client ↔ REST API
│  • tests/contract/client_test.go       │
│  • Wire format & compatibility         │
└─────────────────────────────────────────┘
                    ↑
┌─────────────────────────────────────────┐
│  Layer 1: Unit Tests (Go)              │  ← Pure logic, no dependencies
│  • internal/**/*_test.go               │
│  • Fast feedback (<10s)                │
└─────────────────────────────────────────┘
```

---

## Key Principles

### 1. DRY: Don't Repeat Yourself

**Before** (Current):
```
demos/01-simple-vm-new-auto/Test.ps1  (200 lines)
demos/02-vm-windows-perfect/Test.ps1  (200 lines)
demos/03-vm-with-switch/Test.ps1      (200 lines)
...                                   (×19 = 3800 lines!)
```

**After** (Proposed):
```
tests/harness/HvTestHarness.psm1       (core logic once)
tests/scenarios/scenarios.json         (data, not code)
demos/*/main.tf                        (HCL only, no scripts)
```

**Savings**: ~3500 lines of duplicated code eliminated

---

### 2. Data-Driven Scenarios

Instead of bespoke scripts, scenarios are **configuration**:

```json
{
  "id": "01-simple-vm-new-auto",
  "path": "demos/01-simple-vm-new-auto",
  "tags": ["smoke", "critical", "vm", "disk"],
  "steps": ["Init", "Apply", "Validate", "ReapplyNoop", "Destroy", "ValidateDestroyed"],
  "expectations": {
    "vmCount": 1,
    "diskScenario": "new-auto"
  }
}
```

**Benefits**:
- Central registry of all tests
- Easy to add new scenarios (just add JSON)
- Filterable by tags

---

### 3. Standard Test Harness

One implementation handles all lifecycle steps:

```powershell
# tests/run-all.ps1
param([string[]]$Tags = @("critical"))

$scenarios = Get-Content scenarios.json | ConvertFrom-Json
$filtered = $scenarios | Where-Object { $_.tags -match $Tags }

foreach ($s in $filtered) {
    Invoke-HvScenario -Scenario $s -AutoStartApi
}
```

**Harness responsibilities**:
- API management (start/stop)
- Terraform lifecycle (init/apply/destroy)
- Standard assertions (VM exists, disk created, etc.)
- Result reporting (JSON output)

---

### 4. Extensibility for Complex Cases

Some demos have unique logic (negative tests, idempotency checks). Solution: **custom hooks**

```json
{
  "id": "04-path-validate-negative",
  "tags": ["critical", "policy", "negative"],
  "steps": ["Init", "ApplyExpectFail", "ValidateErrorMessage"],
  "expectations": {
    "expectFailure": true,
    "errorPattern": "path not allowed",
    "customValidation": "Validate-PathNegative.ps1"
  }
}
```

**Harness calls custom script when specified**, but 90% of logic stays DRY.

---

## Target Structure

```
terraform-provider-hypervapi-v2/
├── tests/
│   ├── harness/
│   │   ├── HvTestHarness.psm1           # Core test lifecycle
│   │   ├── HvAssertions.psm1            # Shared assertions
│   │   ├── HvApiManagement.psm1         # API start/stop
│   │   └── HvHelpers.psm1               # Logging, JSON output
│   ├── scenarios/
│   │   ├── scenarios.json               # Central registry (19 scenarios)
│   │   └── custom-validations/          # Optional hooks
│   │       ├── Validate-Idempotency.ps1
│   │       └── Validate-PathNegative.ps1
│   ├── contract/                        # Go contract tests
│   │   └── client_test.go
│   ├── run-all.ps1                      # Main test runner
│   ├── run-single.ps1                   # Dev helper
│   └── README.md                        # Test execution guide
├── demos/                               # Keep existing structure
│   ├── 01-simple-vm-new-auto/
│   │   └── main.tf                      # HCL only (no more Test.ps1)
│   └── ...
└── internal/                            # Go unit tests
    └── **/*_test.go
```

---

## Test Execution Examples

### Local Development

```powershell
# Quick smoke test (1-2 demos, <2 min)
.\tests\run-all.ps1 -Tags smoke -AutoStartApi

# Run single scenario for debugging
.\tests\run-single.ps1 -Id "01-simple-vm-new-auto" -VerboseHttp

# Full suite (all 19 demos)
.\tests\run-all.ps1 -Tags full -AutoStartApi
```

### CI/CD Pipeline

```yaml
# GitHub Actions
jobs:
  unit-tests:
    - run: go test ./internal/... -short
  
  contract-tests:
    - run: go test ./tests/contract/...
  
  smoke-tests:
    - run: pwsh tests/run-all.ps1 -Tags smoke -AutoStartApi
  
  critical-tests:  # PR gate
    - run: pwsh tests/run-all.ps1 -Tags critical -AutoStartApi
  
  full-tests:      # Nightly
    - run: pwsh tests/run-all.ps1 -Tags full -AutoStartApi
```

---

## Benefits

### For Developers

✅ **Faster feedback**: Smoke tests run in <2 minutes  
✅ **Easier debugging**: Single entry point, consistent logs  
✅ **Less duplication**: Change logic once, affects all scenarios  
✅ **Clear registry**: `scenarios.json` shows what's tested  

### For CI/CD

✅ **Flexible test suites**: smoke/critical/full via tags  
✅ **Parallel execution**: Scenarios can run independently  
✅ **Structured output**: JSON results for tracking/reporting  
✅ **Fail fast**: Unit → Contract → Smoke → Critical → Full  

### For Maintenance

✅ **Add scenarios easily**: Just add JSON + main.tf  
✅ **Update logic once**: Harness changes affect all tests  
✅ **No drift**: All scenarios use same test pattern  
✅ **Better coverage visibility**: Central registry tracks gaps  

---

## Comparison: Current vs. Proposed

| Aspect | Current | Proposed |
|--------|---------|----------|
| **Lines of test code** | ~3800 (19 × 200) | ~800 (harness + registry) |
| **Add new scenario** | Write 200-line Test.ps1 | Add 10-line JSON entry |
| **Change test logic** | Update 19 files | Update 1 harness file |
| **Run subset** | Manual script editing | `-Tags smoke\|critical\|full` |
| **CI time (smoke)** | N/A (no smoke suite) | <2 minutes |
| **CI time (critical)** | ~30 min (all or nothing) | ~10 minutes (filtered) |
| **Test visibility** | Hunt through 19 dirs | Single `scenarios.json` |
| **Parallel execution** | Manual coordination | Built-in via harness |

---

## Migration Strategy

See `02-migration-plan.md` for detailed phases.

**Summary**:
- **Week 1**: Build harness skeleton
- **Week 2**: Migrate 3 critical demos (proof of concept)
- **Week 3**: Migrate remaining 16 demos
- **Week 4**: Add contract tests + CI/CD integration

**Total effort**: ~20-25 hours  
**Expected savings**: 50% reduction in test maintenance time

---

## Success Criteria

### Technical

- [ ] All 19 demos run through harness
- [ ] Zero duplicated test logic
- [ ] Structured JSON output for all tests
- [ ] Tag-based filtering works
- [ ] CI/CD integrated with 3-tier strategy

### Performance

- [ ] Smoke tests complete in <2 minutes
- [ ] Critical tests complete in <10 minutes
- [ ] Full suite completes in <30 minutes (no regression)

### Developer Experience

- [ ] Adding new scenario takes <30 minutes
- [ ] Single command runs any test subset
- [ ] Clear error messages with context
- [ ] Documentation updated and clear

---

## Next Steps

1. **Review and approve** this strategy
2. **Create harness skeleton** (see `03-harness-implementation.md`)
3. **Migrate pilot demos** (01, 04, 06)
4. **Validate approach**, then complete migration
5. **Add contract tests** layer
6. **Update CI/CD** pipelines

---

## References

- `02-migration-plan.md` - Detailed week-by-week plan
- `03-harness-implementation.md` - Harness module design
- `04-scenarios-registry.md` - Scenario schema and examples
- `05-custom-validations.md` - Extensibility patterns
- `../dx_and_test_update/` - Previous analysis (now superseded)
