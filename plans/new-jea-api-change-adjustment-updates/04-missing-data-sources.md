# Missing Data Sources Implementation

**Priority**: 🟢 Low (nice to have, not blocking)  
**Estimated Effort**: 3-4 hours  
**Dependencies**: API endpoints may need to be added first

## Goal

Implement remaining data sources from plan.md to provide complete plan-time helpers for Terraform users.

## Currently Implemented Data Sources

✅ `hypervapiv2_disk_plan` - Suggest policy-compliant disk path  
✅ `hypervapiv2_path_validate` - Validate if path is allowed  
✅ `hypervapiv2_policy` - Get effective policy (partial - missing quotas/patterns)  
✅ `hypervapiv2_whoami` - Get caller identity

## Missing Data Sources (from plan.md)

### 1. `hypervapiv2_vm_plan` - Pre-solve Entire VM
**Status**: ❌ Not implemented  
**API Endpoint**: ❌ Does not exist yet  
**Priority**: 🟡 Medium

**Purpose**: Plan-time validation of complete VM configuration

**Proposed Usage**:
```hcl
data "hypervapiv2_vm_plan" "p" {
  vm_name = var.vm_name
  cpu     = 4
  memory  = "8GB"

  disks = [
    { name = "os", size = "50GB", purpose = "os", boot = true },
    { name = "data", size = "100GB", placement = { co_locate_with = "os" } }
  ]

  network { switch = "Default Switch" }
}

# Use outputs in resource
resource "hypervapiv2_vm" "vm" {
  name   = data.hypervapiv2_vm_plan.p.vm_name
  cpu    = data.hypervapiv2_vm_plan.p.resolved.cpu
  memory = "${data.hypervapiv2_vm_plan.p.resolved.memory_mb}MB"
  
  disk {
    name = "os"
    path = data.hypervapiv2_vm_plan.p.resolved.disks[0].path
    size = "50GB"
  }
}
```

**Required API Endpoint**:
```
POST /policy/vm-plan
```

**Request**:
```json
{
  "vm_name": "test-vm",
  "cpu": 4,
  "memory": "8GB",
  "disks": [
    {"name": "os", "size": "50GB", "purpose": "os", "boot": true}
  ],
  "network": [{"switch": "Default Switch"}]
}
```

**Response**:
```json
{
  "resolved": {
    "cpu": 4,
    "memory_mb": 8192,
    "disks": [
      {
        "name": "os",
        "path": "C:\\HyperV\\VHDX\\Users\\test-vm\\os.vhdx",
        "mode": "create",
        "controller": "SCSI",
        "lun": 0,
        "reason": "auto-assigned to SCSI controller 0, LUN 0",
        "warnings": []
      }
    ],
    "network": [
      {"switch": "Default Switch", "mac_suggested": null}
    ]
  },
  "warnings": [],
  "errors": []
}
```

**Implementation Steps**:
1. Add API endpoint to `hyperv-mgmt-api-v2` (separate task)
2. Add client method: `client.PlanVm()`
3. Create data source: `internal/sources/vm_plan.go`
4. Register in provider
5. Create demo
6. Document

---

### 2. `hypervapiv2_host_info` - Host Capabilities
**Status**: ❌ Not implemented  
**API Endpoint**: ❌ Does not exist yet  
**Priority**: 🟢 Low

**Purpose**: Discover host capabilities and storage info

**Proposed Usage**:
```hcl
data "hypervapiv2_host_info" "cap" {}

output "can_use_tpm" {
  value = data.hypervapiv2_host_info.cap.tpm_supported
}

output "storage_roots" {
  value = data.hypervapiv2_host_info.cap.storage_roots
}
```

**Required API Endpoint**:
```
GET /host/info
```

**Response**:
```json
{
  "tpm_supported": true,
  "encryption_toggle_supported": false,
  "secure_boot_templates": ["MicrosoftWindows", "MicrosoftUEFICertificateAuthority"],
  "max_vcpu": 240,
  "storage_roots": [
    {"root": "C:\\HyperV\\VHDX", "total_gb": 500, "free_gb": 250},
    {"root": "D:\\HyperV\\VMs", "total_gb": 2000, "free_gb": 1500}
  ],
  "clustered": false,
  "host": "HV-HOST01"
}
```

**Implementation**: Similar to vm_plan - API first, then client + data source

---

### 3. `hypervapiv2_vm_shape` - Preset Sizing
**Status**: ❌ Not implemented  
**API Endpoint**: ❌ Does not exist  
**Priority**: 🟢 Low (can use locals instead)

**Purpose**: Named VM size presets

**Proposed Usage**:
```hcl
data "hypervapiv2_vm_shape" "medium" {
  name = "medium"
}

resource "hypervapiv2_vm" "app" {
  name   = "app-server"
  cpu    = data.hypervapiv2_vm_shape.medium.cpu
  memory = data.hypervapiv2_vm_shape.medium.memory
}
```

**Alternative**: Use Terraform locals
```hcl
locals {
  vm_shapes = {
    small  = { cpu = 2, memory = "2GB" }
    medium = { cpu = 4, memory = "8GB" }
    large  = { cpu = 8, memory = "16GB" }
  }
}

resource "hypervapiv2_vm" "app" {
  name   = "app-server"
  cpu    = local.vm_shapes.medium.cpu
  memory = local.vm_shapes.medium.memory
}
```

**Decision**: ✅ **Skip** - Users can use locals; not worth API complexity

---

### 4. `hypervapiv2_images` - Discover Base Images
**Status**: ❌ Not implemented  
**API Endpoint**: ❌ Does not exist  
**Priority**: 🟢 Low

**Purpose**: Find available template VHDXs

**Proposed Usage**:
```hcl
data "hypervapiv2_images" "templates" {
  filter_name = "Win11"
  under_root  = "D:/HyperV/Templates"
}

resource "hypervapiv2_vm" "vm" {
  disk {
    clone_from = data.hypervapiv2_images.templates.images[0].path
  }
}
```

**Required API Endpoint**:
```
GET /images?filter_name=Win11&under_root=D:/HyperV/Templates
```

**Response**:
```json
{
  "images": [
    {
      "path": "D:/HyperV/Templates/win11-base.vhdx",
      "size_gb": 40,
      "created": "2025-11-01T10:00:00Z",
      "tags": ["windows", "win11"],
      "notes": "Windows 11 base template"
    }
  ]
}
```

**Implementation**: Requires filesystem scanning API endpoint

**Security Consideration**: Must respect policy roots - only show allowed paths

---

### 5. `hypervapiv2_name_check` - Validate Names
**Status**: ❌ Not implemented  
**API Endpoint**: ❌ Does not exist  
**Priority**: 🟢 Low

**Purpose**: Check if VM/switch name is allowed by policy

**Proposed Usage**:
```hcl
data "hypervapiv2_name_check" "vm" {
  kind = "vm"
  name = var.vm_name
}

resource "hypervapiv2_vm" "app" {
  name = var.vm_name
  
  lifecycle {
    precondition {
      condition     = data.hypervapiv2_name_check.vm.allowed
      error_message = data.hypervapiv2_name_check.vm.message
    }
  }
}
```

**Required API Endpoint**:
```
POST /policy/validate-name
```

**Request**:
```json
{
  "kind": "vm",
  "name": "test-vm"
}
```

**Response**:
```json
{
  "allowed": true,
  "pattern": "^[a-z][a-z0-9-]{2,15}$",
  "message": "Name is valid",
  "suggestions": []
}
```

**Alternative**: Combine with `/policy/effective` which returns name_patterns

---

### 6. Complete `hypervapiv2_policy` - Add Missing Fields
**Status**: ⚠️ Partially implemented  
**API Endpoint**: ✅ Exists: `GET /policy/effective`  
**Priority**: 🟡 Medium

**Current Schema**:
```go
type policyModel struct {
    ID         types.String   `tfsdk:"id"`
    Roots      []types.String `tfsdk:"roots"`
    Extensions []types.String `tfsdk:"extensions"`
    Message    types.String   `tfsdk:"message"`
}
```

**Missing Fields** (from API response):
- `quotas` - Storage quotas per root
- `name_patterns` - VM/switch name validation rules
- `deny_reasons` - Why certain operations are denied

**API Returns**:
```json
{
  "roots": ["C:\\HyperV\\VHDX\\Users"],
  "extensions": [".vhdx", ".vhd"],
  "quotas": {
    "C:\\HyperV\\VHDX\\Users": {
      "max_gb": 500,
      "used_gb": 120,
      "free_gb": 380
    }
  },
  "name_patterns": {
    "vm": "^user-[a-z0-9-]+$",
    "switch": "^[a-z][a-z0-9-]*$"
  },
  "deny_reasons": {}
}
```

**Implementation**:
1. Update `policyModel` schema
2. Update client `PolicyEffective` struct
3. Map fields in data source Read
4. Test
5. Update docs

**Estimated Effort**: 30 minutes

---

## Implementation Priority Matrix

| Data Source | API Exists? | Priority | Effort | Value |
|-------------|-------------|----------|--------|-------|
| Complete `policy` | ✅ | 🟡 Medium | 30 min | High - plan-time validation |
| `vm_plan` | ❌ | 🟡 Medium | 3 hrs | High - comprehensive planning |
| `host_info` | ❌ | 🟢 Low | 2 hrs | Medium - nice to have |
| `vm_shape` | ❌ | 🟢 Low | - | Low - locals work fine |
| `images` | ❌ | 🟢 Low | 2 hrs | Medium - helps with cloning |
| `name_check` | ❌ | 🟢 Low | 1 hr | Low - covered by policy |

## Recommendation

**Immediate (this iteration)**:
1. ✅ Complete `hypervapiv2_policy` data source (30 min) - **DO THIS**

**Next iteration** (after API endpoints added):
2. `hypervapiv2_vm_plan` - Most valuable for users
3. `hypervapiv2_host_info` - Useful for capability discovery

**Skip**:
- `vm_shape` - Use locals instead
- `name_check` - Redundant with policy
- `images` - Low priority, complex to implement securely

## API Tasks Required

Before implementing data sources, these API endpoints need to be added to `hyperv-mgmt-api-v2`:

1. **POST /policy/vm-plan** - VM planning endpoint
2. **GET /host/info** - Host capabilities
3. **GET /images** - Image discovery (optional)

Each should follow existing patterns:
- RBAC via `ICallerInfo`
- Policy enforcement via `IPolicyQueryService`
- Proper error handling with standard envelope

## Success Criteria

- [ ] `hypervapiv2_policy` returns complete data (quotas, patterns)
- [ ] VM plan data source works (after API endpoint added)
- [ ] Host info data source works (after API endpoint added)
- [ ] Demo scenarios show usage patterns
- [ ] Docs updated with examples

