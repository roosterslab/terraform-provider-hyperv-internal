# Complete VM Resource - Disk Operations

**Priority**: 🟡 Medium (after critical fixes)  
**Estimated Effort**: 4-6 hours  
**Dependencies**: 01-critical-fixes.md must be complete

## Goal

Implement full disk operation support in `hypervapiv2_vm` resource to match plan.md specification.

## Current State

**Schema exists** but implementation incomplete:

```go
type diskModel struct {
    Name         types.String    `tfsdk:"name"`
    Purpose      types.String    `tfsdk:"purpose"`
    Size         types.String    `tfsdk:"size"`
    Boot         types.Bool      `tfsdk:"boot"`
    Path         types.String    `tfsdk:"path"`
    CloneFrom    types.String    `tfsdk:"clone_from"`
    SourcePath   types.String    `tfsdk:"source_path"`
    Type         types.String    `tfsdk:"type"`
    Controller   types.String    `tfsdk:"controller"`
    Lun          types.Int64     `tfsdk:"lun"`
    ReadOnly     types.Bool      `tfsdk:"read_only"`
    AutoAttach   types.Bool      `tfsdk:"auto_attach"`
    Protect      types.Bool      `tfsdk:"protect"`
    Placement    *placementModel `tfsdk:"placement"`
}
```

**Currently**: VM creation only handles ONE disk via top-level `newVhdPath` + `newVhdSizeGB`

**Needed**: Support multiple disks with different scenarios in `disk {}` blocks

## Disk Scenarios to Implement

### 1. New Disk (Auto Path)
**User Intent**: "Create a 40GB disk, let policy decide where"

```hcl
disk {
  name    = "cache"
  purpose = "ephemeral"
  size    = "40GB"
}
```

**Implementation**:
1. Parse `size` (e.g., "40GB") → size_gb (int)
2. Call `client.PlanDisk()` with operation="create"
3. Use returned `path`
4. Include in VM creation or attach post-create

### 2. New Disk (Custom Path)
**User Intent**: "Create disk at specific location"

```hcl
disk {
  name = "data"
  path = "D:/HyperV/VMs/app01/data.vhdx"
  size = "100GB"
  type = "fixed"  # or "dynamic"
}
```

**Implementation**:
1. Validate `path` with `client.ValidatePath()`
2. Parse `size` and `type`
3. If creating during VM creation, use `newVhdPath` + `newVhdSizeGB`
4. If VM exists, may need separate VHD creation endpoint (check API)

### 3. Clone Disk (Auto Path)
**User Intent**: "Clone from template, let policy decide destination"

```hcl
disk {
  name       = "os"
  clone_from = "D:/HyperV/Templates/win11-base.vhdx"
  purpose    = "os"
  boot       = true
}
```

**Implementation**:
1. Call `client.ClonePrepare()` without target_path
2. Get `plannedTarget` from response
3. Call `client.CloneEnqueue()` with token
4. Poll `client.GetCloneTask()` until complete
5. Attach resulting disk to VM

### 4. Clone Disk (Custom Path)
**User Intent**: "Clone to specific destination"

```hcl
disk {
  name       = "os"
  clone_from = "D:/HyperV/Templates/win11-base.vhdx"
  path       = "D:/HyperV/VMs/app01/os.vhdx"
}
```

**Implementation**:
1. Validate custom `path`
2. Call `client.ClonePrepare()` with `targetPath`
3. Same clone workflow as #3

### 5. Attach Existing Disk
**User Intent**: "Use an existing VHDX file"

```hcl
disk {
  name        = "shared"
  source_path = "D:/HyperV/Shared/shared-data.vhdx"
  read_only   = false
}
```

**Implementation**:
1. Validate `source_path` exists and is allowed
2. Call `client.AttachDisk(vmName, sourcePath, readOnly)`
3. Track in state but never delete (not provider-owned)

## Implementation Plan

### Phase 1: Single Disk Support (2 hours)
**Goal**: Support ONE disk via `disk {}` block

**Tasks**:
1. Detect disk scenario from fields:
   - Has `size` + no `clone_from`/`source_path` → New disk
   - Has `clone_from` → Clone disk
   - Has `source_path` → Attach existing
2. Implement new disk (auto/custom path) flows
3. Update `Create()` to use first disk block instead of top-level fields
4. Test with single disk scenarios

**Files to modify**:
- `internal/resources/vm.go` (Create method)
- Add helpers: `detectDiskScenario()`, `handleNewDisk()`, `parseSizeString()`

### Phase 2: Clone Support (1.5 hours)
**Goal**: Clone disk operations work

**Tasks**:
1. Add `handleCloneDisk()` helper
2. Implement async clone wait logic
3. Handle clone failures gracefully
4. Test clone scenarios

**Considerations**:
- Clone is async - need to wait or track task ID
- Should we block Create until clone completes?
- Alternative: Mark VM as "provisioning" and finish later

### Phase 3: Attach Existing (30 min)
**Goal**: Attach pre-existing disks

**Tasks**:
1. Add `handleAttachDisk()` helper
2. Call `client.AttachDisk()`
3. Mark disk as "not provider-owned" in state
4. Test attach scenario

### Phase 4: Multiple Disks (2 hours)
**Goal**: Support multiple `disk {}` blocks

**Tasks**:
1. Iterate over all disk blocks
2. Handle ordering (boot disk first?)
3. Assign controller/LUN if not specified
4. Handle failures (rollback? partial success?)
5. Test multi-disk scenarios

**Challenges**:
- VM creation with first disk
- Subsequent disks via attach
- Atomic vs. best-effort
- State consistency on partial failure

## Size Parsing Utility

```go
func parseSizeString(s string) (int, error) {
    s = strings.TrimSpace(strings.ToUpper(s))
    
    // Try GB suffix
    if strings.HasSuffix(s, "GB") {
        val, err := strconv.Atoi(strings.TrimSuffix(s, "GB"))
        if err != nil { return 0, fmt.Errorf("invalid size: %w", err) }
        return val, nil
    }
    
    // Try MB suffix
    if strings.HasSuffix(s, "MB") {
        val, err := strconv.Atoi(strings.TrimSuffix(s, "MB"))
        if err != nil { return 0, fmt.Errorf("invalid size: %w", err) }
        return val / 1024, nil // Convert to GB
    }
    
    // Try raw number (assume GB)
    val, err := strconv.Atoi(s)
    if err != nil { return 0, fmt.Errorf("size must have GB/MB suffix or be a number: %s", s) }
    return val, nil
}
```

## Testing Strategy

### Unit Tests
- Size parsing (various formats)
- Disk scenario detection
- Controller/LUN assignment

### Integration Tests (Demos)
Each scenario as a demo:

1. `demo/single-disk-auto/` - One disk, auto path
2. `demo/single-disk-custom/` - One disk, custom path
3. `demo/clone-disk-auto/` - Clone from template, auto path
4. `demo/clone-disk-custom/` - Clone to custom path
5. `demo/attach-existing/` - Attach pre-existing disk
6. `demo/multi-disk/` - Multiple disks (OS + data)

Each with:
- `main.tf`
- `Run.ps1`
- `Test.ps1`
- `Destroy.ps1`

## Error Handling

### Scenarios to handle:
1. **Invalid size format**: Clear error message with examples
2. **Path validation failure**: Show violations from policy
3. **Clone source not found**: Specific error
4. **Clone timeout**: Allow configurable timeout
5. **Attach failure**: Disk in use, path not found, etc.
6. **Partial multi-disk failure**: Document behavior

## State Management

### Disk Metadata to Track
```go
type diskState struct {
    Name           string
    Path           string
    ProviderOwned  bool   // false for source_path attach
    Protected      bool   // from protect flag
    ControllerType string
    ControllerNum  int
    Lun            int
}
```

### Delete Behavior
- **Provider-owned disks**: Delete if `delete_disks=true` AND `!protect`
- **Attached disks**: Never delete
- **Clone source**: Never touch

## API Endpoint Gaps

Check if API supports:
- [ ] Create VHD without VM
- [ ] Attach disk to existing VM ✅ (already exists: POST /api/v2/vms/{name}/disks)
- [ ] Detach disk from VM
- [ ] Query disk metadata

If missing, file separate plan to add to API.

## Success Criteria

- [ ] All 5 disk scenarios work in demos
- [ ] Multiple disks can be configured
- [ ] Policy-compliant paths enforced
- [ ] Clone operations complete successfully
- [ ] Attach existing disks works
- [ ] Delete respects `protect` flag
- [ ] State accurately reflects disk configuration
- [ ] Clear error messages for common failures

## Rollout Sequence

1. Implement Phase 1 (single new disk)
2. Create demo + test
3. Implement Phase 2 (clone)
4. Create demo + test
5. Implement Phase 3 (attach)
6. Create demo + test
7. Implement Phase 4 (multiple disks)
8. Create comprehensive demo
9. Update docs

