# Critical API Field Name Fixes

**Priority**: 🔴 **CRITICAL** - Must fix before any testing  
**Estimated Effort**: 30 minutes  
**Risk**: High - Wrong field names cause API 400 errors

## Problem

The API server expects specific field names that differ from what some provider code might assume. Recent PerfProbe testing confirmed the correct names.

## Verified Correct Field Names

From successful PerfProbe tests (2025-12-02):

```json
{
  "name": "vm-name",
  "generation": 2,
  "cpuCount": 2,              // ✅ NOT processorCount
  "memoryMB": 2048,            // ✅ NOT memoryStartupBytes
  "switchName": "switch-name",
  "newVhdPath": "path.vhdx",
  "newVhdSizeGB": 10           // ✅ NOT newVhdSizeBytes
}
```

## Files to Audit and Fix

### 1. Client Struct Definitions

**File**: `internal/client/client.go`

**Current**:
```go
type CreateVmRequest struct {
	Name         string  `json:"name"`
	Generation   int     `json:"generation,omitempty"`
	CpuCount     *int    `json:"cpuCount,omitempty"`      // ✅ CORRECT
	MemoryMB     *int    `json:"memoryMB,omitempty"`      // ✅ CORRECT
	SwitchName   *string `json:"switchName,omitempty"`
	NewVhdPath   *string `json:"newVhdPath,omitempty"`
	NewVhdSizeGB *int    `json:"newVhdSizeGB,omitempty"`  // ✅ CORRECT
}
```

**Status**: ✅ **Already correct** - No changes needed

### 2. VM Resource Implementation

**File**: `internal/resources/vm.go`

**Check areas**:
1. Line ~156-400: `VMResource.Create` method
2. Anywhere building API request bodies
3. Any hardcoded field names in strings

**Action**: Search for any references to:
- `processorCount` → should be `cpuCount`
- `memoryStartupBytes` → should be `memoryMB`
- `newVhdSizeBytes` → should be `newVhdSizeGB`

### 3. Documentation

**Files**:
- `docs/HCL-Reference.md`
- `docs/Resources-VM.md`
- `docs/Data-Sources.md`

**Action**: Ensure examples use correct field names in JSON request examples

## Verification Steps

1. **Grep Search**:
   ```powershell
   grep -r "processorCount" internal/
   grep -r "memoryStartupBytes" internal/
   grep -r "newVhdSizeBytes" internal/
   ```

2. **Build Test**:
   ```powershell
   go build
   ```
   Should compile without errors

3. **API Call Test** (after fix):
   Create simple demo that calls CreateVm and verify success

## Expected Outcome

- ✅ All API calls use correct field names
- ✅ No 400 Bad Request errors due to unknown fields
- ✅ Provider can successfully create VMs
- ✅ Documentation matches actual API contract

## Rollout Plan

1. **Audit** (5 min): Grep search for incorrect field names
2. **Fix** (10 min): Update any found instances
3. **Build** (2 min): Verify compilation
4. **Test** (10 min): Run simple create VM demo
5. **Document** (3 min): Update any affected docs

## Success Criteria

- [ ] All grep searches return zero matches for old field names
- [ ] `go build` succeeds
- [ ] Simple VM creation demo works against live API
- [ ] Docs reflect correct field names

