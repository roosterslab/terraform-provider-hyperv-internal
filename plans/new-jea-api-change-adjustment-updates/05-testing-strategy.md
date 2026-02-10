# Testing Strategy and Demo Scenarios

**Priority**: 🔴 Critical (validates all work)  
**Estimated Effort**: 4-6 hours  
**Dependencies**: Requires implemented features to test

## Overview

Comprehensive testing strategy with demo-based integration tests that serve as both validation and documentation.

## Testing Pyramid

```
           ┌─────────────┐
           │   E2E Demos │  ← Full scenarios with real API
           └─────────────┘
          ┌───────────────┐
          │  Integration  │   ← API client tests
          └───────────────┘
        ┌─────────────────────┐
        │    Unit Tests       │  ← Helpers, parsers, validators
        └─────────────────────┘
```

## Unit Tests

### Size Parsing
**File**: `internal/resources/vm_test.go`

```go
func TestParseSizeString(t *testing.T) {
    tests := []struct{
        input    string
        expected int
        wantErr  bool
    }{
        {"40GB", 40, false},
        {"2048MB", 2, false},
        {"100", 100, false},
        {"invalid", 0, true},
        {"", 0, true},
    }
    
    for _, tt := range tests {
        t.Run(tt.input, func(t *testing.T) {
            got, err := parseSizeString(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("wantErr=%v, got err=%v", tt.wantErr, err)
            }
            if got != tt.expected {
                t.Errorf("expected %d, got %d", tt.expected, got)
            }
        })
    }
}
```

### Disk Scenario Detection
```go
func TestDetectDiskScenario(t *testing.T) {
    tests := []struct{
        name     string
        disk     diskModel
        scenario string
    }{
        {
            name: "new disk auto",
            disk: diskModel{Size: types.StringValue("40GB")},
            scenario: "new_auto",
        },
        {
            name: "new disk custom",
            disk: diskModel{
                Size: types.StringValue("40GB"),
                Path: types.StringValue("D:/path.vhdx"),
            },
            scenario: "new_custom",
        },
        {
            name: "clone auto",
            disk: diskModel{CloneFrom: types.StringValue("D:/template.vhdx")},
            scenario: "clone_auto",
        },
        {
            name: "clone custom",
            disk: diskModel{
                CloneFrom: types.StringValue("D:/template.vhdx"),
                Path: types.StringValue("D:/dest.vhdx"),
            },
            scenario: "clone_custom",
        },
        {
            name: "attach existing",
            disk: diskModel{SourcePath: types.StringValue("D:/existing.vhdx")},
            scenario: "attach",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := detectDiskScenario(tt.disk)
            if got != tt.scenario {
                t.Errorf("expected %s, got %s", tt.scenario, got)
            }
        })
    }
}
```

## Integration Tests (Client)

### API Client Tests
**File**: `internal/client/client_test.go`

```go
func TestClient_CreateVm(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }
    
    cfg := Config{
        Endpoint: "http://localhost:5000",
        Auth: AuthConfig{Method: "none"},
        TimeoutSeconds: 30,
    }
    
    cl, err := New(cfg)
    if err != nil {
        t.Fatal(err)
    }
    
    req := CreateVmRequest{
        Name: "test-vm-" + randomString(6),
        Generation: 2,
        CpuCount: ptr(2),
        MemoryMB: ptr(2048),
    }
    
    resp, err := cl.CreateVm(context.Background(), req)
    if err != nil {
        t.Fatal(err)
    }
    
    if resp.VmId == "" {
        t.Error("expected VmId in response")
    }
    
    // Cleanup
    defer cl.DeleteVm(context.Background(), req.Name, DeleteVmRequest{})
}
```

**Run with**:
```powershell
go test ./internal/client -v -run TestClient
```

## Demo Scenarios (E2E Tests)

Each demo is a complete Terraform configuration that tests a specific feature or scenario.

### Demo Structure

```
demo/
├── 01-basic-vm/
│   ├── main.tf
│   ├── Run.ps1
│   ├── Test.ps1
│   ├── Destroy.ps1
│   └── README.md
├── 02-disk-auto-path/
│   ├── main.tf
│   ├── Run.ps1
│   ├── Test.ps1
│   ├── Destroy.ps1
│   └── README.md
...
```

### Demo Scripts

#### `Run.ps1` - Initialize and Apply
```powershell
#!/usr/bin/env pwsh
# Apply Terraform configuration with dev override

$env:TF_LOG = "INFO"
$DevOverride = @"
provider_installation {
  dev_overrides {
    "vinitsiriya/hypervapiv2" = "C:/path/to/terraform-provider-hypervapi-v2"
  }
  direct {}
}
"@

Set-Content -Path "dev.tfrc" -Value $DevOverride

$env:TF_CLI_CONFIG_FILE = "$PWD/dev.tfrc"

terraform init
terraform plan -out=tfplan
terraform apply tfplan

Write-Host ""
Write-Host "Demo applied successfully!" -ForegroundColor Green
Write-Host "Run ./Test.ps1 to verify" -ForegroundColor Cyan
```

#### `Test.ps1` - Verify Deployment
```powershell
#!/usr/bin/env pwsh
# Verify demo deployment

$vm_name = terraform output -raw vm_name
if (-not $vm_name) {
    Write-Error "VM name not found in outputs"
    exit 1
}

Write-Host "Verifying VM: $vm_name" -ForegroundColor Cyan

# Check via API
$response = Invoke-RestMethod -Uri "http://localhost:5000/api/v2/vms/$vm_name" -Method Get
if ($response.name -ne $vm_name) {
    Write-Error "VM not found or name mismatch"
    exit 1
}

Write-Host "✓ VM exists" -ForegroundColor Green
Write-Host "  State: $($response.state)" -ForegroundColor Gray

# Additional checks based on demo type
# ...

Write-Host ""
Write-Host "All checks passed!" -ForegroundColor Green
```

#### `Destroy.ps1` - Cleanup
```powershell
#!/usr/bin/env pwsh
# Destroy resources and verify cleanup

$env:TF_CLI_CONFIG_FILE = "$PWD/dev.tfrc"

terraform destroy -auto-approve

Write-Host "Destroyed resources" -ForegroundColor Yellow
Write-Host "Verifying cleanup..." -ForegroundColor Cyan

# Verify VM is gone
# Check VHD files deleted (if expected)
# ...

Write-Host "Cleanup complete" -ForegroundColor Green
```

### Demo Catalog

#### 1. Basic VM Creation
**Directory**: `demo/01-basic-vm/`  
**Tests**: Minimal VM with auto disk path

```hcl
resource "hypervapiv2_vm" "test" {
  name   = "basic-test-vm"
  cpu    = 2
  memory = "2GB"
  power  = "stopped"
  
  disk {
    name = "os"
    size = "10GB"
  }
}
```

**Validates**:
- VM creation works
- Disk auto-path works
- Policy enforcement active

---

#### 2. Disk - Auto Path
**Directory**: `demo/02-disk-auto-path/`  
**Tests**: disk_plan data source

```hcl
data "hypervapiv2_disk_plan" "os" {
  vm_name   = "test-vm"
  operation = "create"
  purpose   = "os"
  size_gb   = 50
}

resource "hypervapiv2_vm" "test" {
  name = "test-vm"
  
  disk {
    name = "os"
    path = data.hypervapiv2_disk_plan.os.path
    size = "50GB"
  }
}
```

**Validates**:
- disk_plan data source
- Policy-compliant path suggestion
- Warnings propagate correctly

---

#### 3. Disk - Custom Path
**Directory**: `demo/03-disk-custom-path/`  
**Tests**: Path validation

```hcl
data "hypervapiv2_path_validate" "custom" {
  path      = "D:/HyperV/VMs/test-vm/os.vhdx"
  operation = "create"
}

resource "hypervapiv2_vm" "test" {
  name = "test-vm"
  
  disk {
    name = "os"
    path = data.hypervapiv2_path_validate.custom.normalized_path
    size = "50GB"
  }
  
  lifecycle {
    precondition {
      condition     = data.hypervapiv2_path_validate.custom.allowed
      error_message = "Path not allowed: ${data.hypervapiv2_path_validate.custom.message}"
    }
  }
}
```

**Validates**:
- path_validate data source
- Policy rejection works
- Preconditions block invalid configs

---

#### 4. Clone Disk
**Directory**: `demo/04-clone-disk/`  
**Tests**: Clone operations

```hcl
resource "hypervapiv2_vm" "cloned" {
  name = "cloned-vm"
  
  disk {
    name       = "os"
    clone_from = "D:/HyperV/Templates/win11-base.vhdx"
    boot       = true
  }
}
```

**Validates**:
- Clone prepare/enqueue workflow
- Async task polling
- Cloned disk attached correctly

---

#### 5. Attach Existing Disk
**Directory**: `demo/05-attach-existing/`  
**Tests**: Attach pre-existing VHDX

```hcl
resource "hypervapiv2_vm" "test" {
  name = "test-vm"
  
  disk {
    name        = "shared"
    source_path = "D:/HyperV/Shared/shared-data.vhdx"
    read_only   = false
  }
}
```

**Validates**:
- Attach existing disk
- Not deleted on destroy
- Read-only flag works

---

#### 6. Multiple Disks
**Directory**: `demo/06-multi-disk/`  
**Tests**: VM with OS + data disks

```hcl
resource "hypervapiv2_vm" "test" {
  name = "multi-disk-vm"
  
  disk {
    name    = "os"
    size    = "50GB"
    purpose = "os"
    boot    = true
  }
  
  disk {
    name    = "data"
    size    = "100GB"
    purpose = "data"
  }
  
  disk {
    name    = "cache"
    size    = "40GB"
    purpose = "ephemeral"
    type    = "fixed"
  }
}
```

**Validates**:
- Multiple disk blocks
- Controller/LUN assignment
- Disk purposes

---

#### 7. Network - Basic
**Directory**: `demo/07-network-basic/`  
**Tests**: Switch + VM with adapter

```hcl
resource "hypervapiv2_network" "lan" {
  name = "test-internal"
  type = "Internal"
}

resource "hypervapiv2_vm" "test" {
  name = "network-test-vm"
  
  network_interface {
    switch = hypervapiv2_network.lan.name
  }
  
  disk { name = "os"; size = "10GB" }
}
```

**Validates**:
- Switch creation
- Adapter creation
- Adapter connected to switch

---

#### 8. Firmware & Security
**Directory**: `demo/08-firmware-security/`  
**Tests**: Secure boot + TPM

```hcl
resource "hypervapiv2_vm" "secure" {
  name = "secure-vm"
  
  disk { name = "os"; size = "20GB" }
  
  firmware {
    secure_boot = true
    secure_boot_template = "MicrosoftWindows"
  }
  
  security {
    tpm = true
  }
}
```

**Validates**:
- Firmware configuration
- Security features
- Generation 2 requirements

---

#### 9. Power Management
**Directory**: `demo/09-power-management/`  
**Tests**: Start/stop operations

```hcl
resource "hypervapiv2_vm" "test" {
  name   = "power-test-vm"
  power  = "running"
  stop_method = "graceful"
  wait_timeout_seconds = 120
  
  disk { name = "os"; size = "10GB" }
}
```

**Validates**:
- Power state management
- Stop methods (graceful/force/turnoff)
- Timeout handling

---

#### 10. RBAC & Policy
**Directory**: `demo/10-rbac-policy/`  
**Tests**: Policy enforcement

```hcl
data "hypervapiv2_whoami" "me" {}
data "hypervapiv2_policy" "effective" {}

output "my_identity" {
  value = data.hypervapiv2_whoami.me.user
}

output "allowed_roots" {
  value = data.hypervapiv2_policy.effective.roots
}

# Try to create VM with policy-compliant name
resource "hypervapiv2_vm" "test" {
  name = "user-testvm-${formatdate("YYYYMMDD", timestamp())}"
  
  disk {
    name = "os"
    size = "10GB"
  }
}
```

**Validates**:
- whoami data source
- policy data source
- Name prefix enforcement
- Path enforcement

---

## Running All Demos

**Script**: `demo/run-all.ps1`

```powershell
#!/usr/bin/env pwsh
# Run all demos sequentially

$demos = Get-ChildItem -Directory | Sort-Object Name

foreach ($demo in $demos) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Running: $($demo.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Push-Location $demo.FullName
    
    try {
        & ./Run.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Run failed for $($demo.Name)"
            Pop-Location
            continue
        }
        
        & ./Test.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Test failed for $($demo.Name)"
            Pop-Location
            continue
        }
        
        & ./Destroy.ps1
        
        Write-Host "✓ $($demo.Name) PASSED" -ForegroundColor Green
    }
    catch {
        Write-Error "Error in $($demo.Name): $_"
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "All demos complete" -ForegroundColor Green
```

## CI/CD Integration

**GitHub Actions Workflow**: `.github/workflows/demo-tests.yml`

```yaml
name: Demo Tests

on:
  pull_request:
  push:
    branches: [master]

jobs:
  demo-tests:
    runs-on: windows-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Build provider
        run: go build -o terraform-provider-hypervapiv2.exe
      
      - name: Start API server
        run: |
          cd hyperv-mgmt-api-v2
          dotnet run --urls http://localhost:5000 &
      
      - name: Wait for API
        run: Start-Sleep 10
      
      - name: Run demos
        working-directory: ./demo
        run: ./run-all.ps1
```

## Success Criteria

- [ ] All unit tests pass
- [ ] Integration tests pass against live API
- [ ] All 10 demo scenarios complete successfully
- [ ] Demos can run in sequence without conflicts
- [ ] CI pipeline runs demos on PR
- [ ] Each demo has clear README
- [ ] Destroy scripts verify cleanup

## Rollout Plan

1. **Week 1**: Unit tests + basic demos (01-03)
2. **Week 2**: Disk operation demos (04-06)
3. **Week 3**: Network + security demos (07-08)
4. **Week 4**: Power + RBAC demos (09-10)
5. **Week 5**: CI integration + documentation

