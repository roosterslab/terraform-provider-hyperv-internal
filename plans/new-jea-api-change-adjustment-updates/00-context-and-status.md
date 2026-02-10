# Context and Current Status

**Date**: 2025-12-02  
**Phase**: Post-API Testing → Provider Updates

## Background

The HyperV Management API v2 has been successfully tested with:
- ✅ **Allow-all policy mode**: All 3 PerfProbe workflows passed (~21-29s each)
- ✅ **Strict RBAC mode**: All 3 PerfProbe workflows passed with policy enforcement
- ✅ **Policy enforcement verified**: VM names with `user-` prefix, VHD paths under `C:\HyperV\VHDX\Users\`
- ✅ **IPolicyProvider architecture**: Working correctly with FilePolicyProvider

## Current API State (Verified Working)

### VM Creation Endpoint
```
POST /api/v2/vms
```
**Request Body**:
```json
{
  "name": "vm-name",
  "generation": 2,
  "cpuCount": 2,
  "memoryMB": 2048,
  "switchName": "Default Switch",
  "newVhdPath": "C:\\path\\to\\disk.vhdx",
  "newVhdSizeGB": 10
}
```

**Field Names (VERIFIED)**:
- `cpuCount` (NOT `processorCount`)
- `memoryMB` (NOT `memoryStartupBytes`)
- `newVhdSizeGB` (NOT `newVhdSizeBytes`)

### Available API Endpoints (from Program.cs)

**Core VM Operations**:
- `GET /api/v2/vms` - List VMs
- `GET /api/v2/vms/{name}` - Get VM details
- `POST /api/v2/vms` - Create VM
- `POST /api/v2/vms/{name}:start` - Start VM
- `POST /api/v2/vms/{name}:stop` - Stop VM (with force/turnOff params)
- `POST /api/v2/vms/{name}:restart` - Restart VM
- `POST /api/v2/vms/{name}:checkpoint` - Create checkpoint
- `POST /api/v2/vms/{name}:delete-prepare` - Prepare delete token
- `POST /api/v2/vms/{name}:delete` - Delete VM with token

**Network Operations**:
- `GET /api/v2/switches` - List switches
- `POST /api/v2/switches` - Create switch
- `POST /api/v2/switches/{name}:delete` - Delete switch
- `GET /api/v2/vms/{name}/adapters` - List VM adapters
- `POST /api/v2/vms/{name}/adapters` - Add adapter
- `POST /api/v2/vms/{name}/adapters/{adapter}:connect` - Connect adapter
- `POST /api/v2/vms/{name}/adapters/{adapter}:disconnect` - Disconnect adapter
- `POST /api/v2/vms/{name}/adapters/{adapter}:delete` - Delete adapter

**Disk Operations**:
- `GET /api/v2/vms/{name}/disks` - List VM disks
- `GET /api/v2/vms/{name}/disks/attached` - List attached disks
- `POST /api/v2/vms/{name}/disks` - Attach existing disk
- `POST /api/v2/disks/clone:prepare` - Prepare clone operation
- `POST /api/v2/disks/clone` - Enqueue clone task
- `GET /api/v2/disks/clone/tasks/{id}` - Get clone task status
- `GET /api/v2/disks/clone/tasks` - List clone tasks
- `POST /api/v2/disks/clone/tasks/{id}:cancel` - Cancel clone task

**Firmware/Security**:
- `GET /api/v2/vms/{name}/firmware` - Get firmware config
- `POST /api/v2/vms/{name}/firmware/first-boot` - Set first boot device
- `POST /api/v2/vms/{name}/firmware/secure-boot` - Configure secure boot
- `GET /api/v2/vms/{name}/security` - Get security config
- `POST /api/v2/vms/{name}/security/shielded` - Configure shielded VM
- `POST /api/v2/vms/{name}/security/encryption-support` - Toggle encryption support
- `GET /api/v2/vms/{name}/security/tpm` - Get TPM status
- `POST /api/v2/vms/{name}/security/tpm` - Enable/disable TPM

**Configuration Query**:
- `GET /api/v2/vms/{name}/processor/config` - Get CPU config
- `GET /api/v2/vms/{name}/memory/config` - Get memory config

**Policy/Identity** (Plan-time Data Sources):
- `GET /identity/whoami` - Get caller identity (user, domain, SID, groups)
- `GET /policy/effective` - Get effective policy (roots, extensions, quotas, name patterns)
- `POST /policy/plan-disk` - Suggest policy-compliant disk path
- `POST /policy/validate-path` - Validate if path is allowed
- `GET /api/v2/policy/allowed-vhdx-paths` - (legacy endpoint)
- `POST /api/v2/policy/suggest-vhdx-path` - (legacy endpoint)
- `POST /api/v2/policy/suggest-vhdx-path-dir` - (legacy endpoint)

**Host Operations**:
- `GET /api/v2/host/enhanced-session-mode` - Get enhanced session mode status
- `POST /api/v2/host/enhanced-session-mode` - Set enhanced session mode

**Advanced VM Features**:
- `POST /api/v2/vms/{name}:enhanced-transport` - Set enhanced session transport
- `POST /api/v2/vms/{name}:nested-virt` - Configure nested virtualization

## Current Provider v2 Implementation

### Implemented Resources
1. **`hypervapiv2_vm`** - VM resource
   - ✅ Basic VM creation (name, CPU, memory, generation, switch, single VHD)
   - ✅ Firmware block (secure_boot, secure_boot_template)
   - ✅ Security block (TPM)
   - ✅ Lifecycle block (vm_lifecycle)
   - ✅ Power management (power, stop_method, wait_timeout_seconds)
   - ⚠️ **Disk block** (schema exists but not fully implemented)
   - ❌ **Missing**: Clone operations, attach existing disk, multiple disks

2. **`hypervapiv2_network`** - Network switch resource
   - ⚠️ Skeleton only (TODO: call API)

### Implemented Data Sources
1. **`hypervapiv2_disk_plan`** - Suggest policy-compliant disk path
   - ✅ Calls `/policy/plan-disk`
   - ✅ Returns: path, reason, matched_root, warnings

2. **`hypervapiv2_path_validate`** - Validate if path is allowed
   - ✅ Calls `/policy/validate-path`
   - ✅ Returns: allowed, matched_root, violations, message

3. **`hypervapiv2_policy`** - Get effective policy
   - ✅ Calls `/policy/effective`
   - ✅ Returns: roots, extensions, message
   - ❌ **Missing**: quotas, name_patterns (schema incomplete)

4. **`hypervapiv2_whoami`** - Get caller identity
   - ✅ Calls `/identity/whoami`
   - ✅ Returns: user, domain, sid, groups

### Client Implementation Status
Located in: `internal/client/client.go`

**Implemented Methods**:
- ✅ `PlanDisk` - POST /policy/plan-disk
- ✅ `ValidatePath` - POST /policy/validate-path
- ✅ `WhoAmI` - GET /identity/whoami
- ✅ `Policy` - GET /policy/effective
- ✅ `CreateVm` - POST /api/v2/vms
- ✅ `GetVm` - GET /api/v2/vms/{name}
- ✅ `DeleteVm` - Two-step delete with token
- ✅ `StartVm` - POST /api/v2/vms/{name}:start
- ✅ `StopVm` - POST /api/v2/vms/{name}:stop (with force/turnOff)
- ✅ `GetVmProcessorConfig` - GET /api/v2/vms/{name}/processor/config
- ✅ `GetVmMemoryConfig` - GET /api/v2/vms/{name}/memory/config
- ✅ `SetSecureBoot` - POST /api/v2/vms/{name}/firmware/secure-boot
- ✅ `SetFirstBootToPrimaryDisk` - POST /api/v2/vms/{name}/firmware/first-boot
- ✅ `GetFirmware` - GET /api/v2/vms/{name}/firmware
- ✅ `GetSecurity` - GET /api/v2/vms/{name}/security
- ✅ `ClonePrepare` - POST /api/v2/disks/clone:prepare
- ✅ `CloneEnqueue` - POST /api/v2/disks/clone
- ✅ `GetCloneTask` - GET /api/v2/disks/clone/tasks/{id}
- ✅ `AttachDisk` - POST /api/v2/vms/{name}/disks

**Missing Methods**:
- ❌ `ListVms` - GET /api/v2/vms
- ❌ `CreateSwitch` - POST /api/v2/switches (stubbed, needs implementation)
- ❌ `DeleteSwitch` - POST /api/v2/switches/{name}:delete
- ❌ `ListSwitches` - GET /api/v2/switches
- ❌ `AddNetworkAdapter` - POST /api/v2/vms/{name}/adapters
- ❌ `ListAdapters` - GET /api/v2/vms/{name}/adapters
- ❌ `SetTPM` - POST /api/v2/vms/{name}/security/tpm
- ❌ `SetEncryptionSupport` - POST /api/v2/vms/{name}/security/encryption-support
- ❌ Many other advanced endpoints

## Testing Status

### API Testing (PerfProbe)
- ✅ All workflows fixed and passing
- ✅ Unique VHD paths implemented (vmname.vhdx)
- ✅ Allow-all mode: 3/3 workflows PASS
- ✅ Strict RBAC mode: 3/3 workflows PASS
- ✅ CSV reports generated

### Provider Testing
- ❌ No demo scenarios executed yet
- ❌ Integration tests pending
- ❌ Manual HCL examples not verified

## Known Issues & Technical Debt

1. **Field Name Confusion**: Provider client uses old field names in some places
   - Client has both `CpuCount` and references to old names
   - Need to audit all API calls for correct field names

2. **Network Resource**: Skeleton only, needs full implementation

3. **Disk Operations**: 
   - Clone flow exists but not integrated into VM resource
   - Attach existing disk not wired up in VM resource
   - Multiple disks per VM not tested

4. **Power Management**:
   - Stop method variants (graceful/force/turnoff) exist but need testing
   - Wait timeout logic may need refinement

5. **Policy Data Source**:
   - Schema incomplete (missing quotas, name_patterns fields)
   - Only returns roots/extensions/message

6. **Missing Data Sources** (from plan.md):
   - `vm_plan` - Pre-solve entire VM config
   - `host_info` - Capabilities & storage snapshot
   - `vm_shape` - Preset sizing
   - `images` - Discover base images
   - `name_check` - Validate names with suggestions

## Next Steps (Priority Order)

See detailed plans in:
- `01-critical-fixes.md` - Immediate field name corrections
- `02-complete-vm-resource.md` - Finish disk operations
- `03-network-implementation.md` - Complete switch/adapter support
- `04-missing-data-sources.md` - Add remaining data sources
- `05-testing-strategy.md` - Demo scenarios and validation

