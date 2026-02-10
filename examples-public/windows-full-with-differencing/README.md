# Windows Server Production Deployment with Differencing VHDXs

This example demonstrates a complete production Windows infrastructure deployment using the **public published version** of the HyperV Terraform provider, featuring:

- **Windows Integrated Authentication** with impersonation
- **Differencing VHDX** technology for storage efficiency
- **Policy-enforced paths** for security compliance
- **Multi-tier architecture** (Web, App, Database servers)
- **VDI workstations** with massive storage savings
- **Mixed disk types** optimized for different workloads

## 🎯 What This Example Deploys

This configuration creates a complete 7-VM infrastructure:

### Production Tier (3 VMs)
1. **Web Server** (`prod-win-web-01`)
   - 2 CPU, 4GB RAM
   - Differencing OS disk + 50GB dynamic data disk
   - Running IIS with web content storage

2. **Application Server** (`prod-win-app-01`)
   - 4 CPU, 8GB RAM
   - Differencing OS disk + 30GB fixed binaries + 100GB dynamic data
   - Mixed disk types for optimal performance

3. **Database Server** (`prod-win-db-01`)
   - 8 CPU, 16GB RAM
   - Differencing OS disk + 200GB fixed DB files + 50GB fixed logs + 500GB dynamic backups
   - Production-grade disk configuration

### VDI Tier (3 VMs)
4-6. **User Workstations** (`prod-win-vdi-user-1/2/3`)
   - 2 CPU, 4GB RAM each
   - All use differencing disks from same parent
   - ~90% storage savings compared to traditional VMs

### Development Tier (1 VM)
7. **Dev Workstation** (`prod-win-dev-01`)
   - 6 CPU, 12GB RAM
   - Differencing disk with dev tools pre-installed
   - Auto-starts on deployment

## 💾 Storage Architecture Benefits

### Differencing VHDX Advantages
- **90% Storage Savings**: OS disks share common parent template
- **Fast Provisioning**: New VMs deploy in seconds
- **Template Management**: Update parent → all VMs benefit
- **Consistency**: All VMs start from same golden image

### Mixed Disk Types
- **Differencing**: OS disks (fast provisioning from template)
- **Fixed**: Database files (predictable performance, no fragmentation)
- **Dynamic**: Data/logs (grows as needed, saves space)

## 📋 Prerequisites

### Infrastructure Requirements
- **Windows Server 2019+** or **Windows 10/11 Pro** with Hyper-V
- **Administrator privileges** on Hyper-V host
- **HyperV Management API v2** running (port 5000)
- **Network switch** configured in Hyper-V
- **Parent VHDX template** prepared (Windows Server 2022 recommended)

### Software Requirements
- **Terraform** 1.5.0 or later
- **PowerShell** 5.1 or PowerShell 7+
- **Internet connection** (to download provider from Terraform Registry)

### Authentication Requirements
- **Windows Domain** or **Local Administrator** credentials
- **Hyper-V Administrators** group membership
- **File system permissions** to managed paths

## 🚀 Quick Start

### Step 1: Prepare Parent Template

Create a Windows Server base template:

```powershell
# Create directory structure
New-Item -ItemType Directory -Path "C:\HyperV\VHDX\Users\templates" -Force

# Option 1: Create empty VHDX (for testing)
New-VHD -Path "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx" `
        -SizeBytes 127GB -Dynamic

# Option 2: Create from Windows Server ISO (recommended for production)
# 1. Create a VM with the VHDX
# 2. Install Windows Server 2022
# 3. Install updates, drivers, and common software
# 4. Run Sysprep to generalize
# 5. Shut down and use as parent template
```

**Production Template Preparation:**
```powershell
# Inside the template VM (before sysprep):
# - Install Windows updates
# - Install common software (Office, browsers, etc.)
# - Configure Windows settings
# - Install Hyper-V integration services

# Sysprep the template
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown
```

### Step 2: Configure HyperV Management API

Ensure the API is running with appropriate permissions:

```powershell
cd C:\path\to\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj

# API should be listening on http://localhost:5000
# Verify with:
curl http://localhost:5000/api/v2/whoami
```

### Step 3: Initialize Terraform

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terrraform-provider-hypervapi-v2-new\examples-public\windows-full-with-differencing

# Initialize (downloads provider from Terraform Registry)
terraform init
```

**Expected Output:**
```
Initializing the backend...

Initializing provider plugins...
- Finding roosterslab/hyperv-internal versions matching "0.1.0"...
- Installing roosterslab/hyperv-internal v0.1.0...
- Installed roosterslab/hyperv-internal v0.1.0 (signed by a HashiCorp partner)

Terraform has been successfully initialized!
```

### Step 4: Configure Variables

Create `terraform.tfvars`:

```hcl
endpoint           = "http://localhost:5000"
parent_vhdx_path   = "C:/HyperV/VHDX/Users/templates/windows-server-2022-base.vhdx"
vm_name_prefix     = "prod-win"
switch_name        = "Default Switch"
```

### Step 5: Review Plan

```powershell
terraform plan
```

Review the 7 VMs that will be created and their configurations.

### Step 6: Deploy Infrastructure

```powershell
terraform apply
```

Type `yes` when prompted.

**Expected Output:**
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

app_server = {
  "id" = "..."
  "name" = "prod-win-app-01"
  "os_disk" = "C:/HyperV/VHDX/Users/prod-win-app-01/os.vhdx"
  "state" = "running"
}
db_server = {
  "id" = "..."
  "name" = "prod-win-db-01"
  "os_disk" = "C:/HyperV/VHDX/Users/prod-win-db-01/os.vhdx"
  "state" = "running"
}
deployment_summary = {
  "authentication" = "Windows Integrated Authentication (Negotiate)"
  "dev_workstations" = 1
  "differencing_disks" = "All OS disks use differencing VHDXs"
  "expected_savings" = "~70-90% storage reduction for OS disks"
  "parent_template" = "C:/HyperV/VHDX/Users/templates/windows-server-2022-base.vhdx"
  "policy_enforcement" = "Enabled - all paths validated against policy"
  "production_vms" = 3
  "total_vms" = 7
  "vdi_users" = 3
}
dev_workstation = {...}
vdi_users = [...]
web_server = {...}
```

## 🔍 Verification

### Verify VMs Created

```powershell
# List all deployed VMs
Get-VM | Where-Object { $_.Name -like "prod-win-*" } |
    Format-Table Name, State, CPUUsage, @{L="Memory(GB)";E={$_.MemoryAssigned/1GB}}
```

**Expected Output:**
```
Name                State   CPUUsage Memory(GB)
----                -----   -------- ----------
prod-win-app-01     Running 0        8
prod-win-db-01      Running 0        16
prod-win-dev-01     Running 0        12
prod-win-vdi-user-1 Off     0        4
prod-win-vdi-user-2 Off     0        4
prod-win-vdi-user-3 Off     0        4
prod-win-web-01     Running 0        4
```

### Verify Differencing Disks

```powershell
# Check web server OS disk
$vm = Get-VM "prod-win-web-01"
$vm | Get-VMHardDiskDrive | Where-Object {$_.Name -eq "os"} | ForEach-Object {
    Get-VHD $_.Path | Format-List Path, VhdType, ParentPath, FileSize, Size
}
```

**Expected Output:**
```
Path       : C:\HyperV\VHDX\Users\prod-win-web-01\os.vhdx
VhdType    : Differencing
ParentPath : C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx
FileSize   : 41943040      # ~40MB (almost empty!)
Size       : 136365211648  # 127GB (inherited from parent)
```

### Calculate Storage Savings

```powershell
# Storage analysis script
$parentPath = "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx"
$parentSize = (Get-Item $parentPath).Length

# Get all child differencing disks
$vms = Get-VM | Where-Object { $_.Name -like "prod-win-*" }
$totalChild = 0
foreach ($vm in $vms) {
    $disks = $vm | Get-VMHardDiskDrive
    foreach ($disk in $disks) {
        $vhd = Get-VHD $disk.Path
        if ($vhd.VhdType -eq "Differencing") {
            $totalChild += $vhd.FileSize
        }
    }
}

$actualTotal = $parentSize + $totalChild
$traditionalTotal = 7 * 127GB  # 7 VMs × 127GB each

Write-Host "`nStorage Analysis:" -ForegroundColor Cyan
Write-Host "Parent template: $([math]::Round($parentSize/1GB, 2)) GB" -ForegroundColor White
Write-Host "All child disks: $([math]::Round($totalChild/1GB, 2)) GB" -ForegroundColor White
Write-Host "Total actual: $([math]::Round($actualTotal/1GB, 2)) GB" -ForegroundColor Green
Write-Host "Traditional (no differencing): $([math]::Round($traditionalTotal/1GB, 2)) GB" -ForegroundColor Yellow
Write-Host "Savings: $([math]::Round((1 - $actualTotal/$traditionalTotal) * 100, 1))%" -ForegroundColor Green
```

**Expected Output:**
```
Storage Analysis:
Parent template: 15.25 GB
All child disks: 0.38 GB
Total actual: 15.63 GB
Traditional (no differencing): 889.00 GB
Savings: 98.2%
```

### Inspect Disk Configurations

**Web Server:**
```powershell
Get-VM "prod-win-web-01" | Get-VMHardDiskDrive | ForEach-Object {
    $vhd = Get-VHD $_.Path
    [PSCustomObject]@{
        Name = Split-Path $vhd.Path -Leaf
        Type = $vhd.VhdType
        Size = "$([math]::Round($vhd.Size/1GB, 1))GB"
        Used = "$([math]::Round($vhd.FileSize/1GB, 2))GB"
        Parent = if ($vhd.VhdType -eq "Differencing") { Split-Path $vhd.ParentPath -Leaf } else { "N/A" }
    }
} | Format-Table -AutoSize
```

**Database Server (Multiple Disk Types):**
```powershell
Get-VM "prod-win-db-01" | Get-VMHardDiskDrive | ForEach-Object {
    $vhd = Get-VHD $_.Path
    [PSCustomObject]@{
        Purpose = if ($_.Name -match "os") { "OS" }
                  elseif ($_.Path -match "db-files") { "Database" }
                  elseif ($_.Path -match "db-logs") { "Logs" }
                  else { "Backup" }
        Type = $vhd.VhdType
        Size = "$([math]::Round($vhd.Size/1GB, 0))GB"
        Used = "$([math]::Round($vhd.FileSize/1GB, 2))GB"
    }
} | Format-Table -AutoSize
```

## 🔐 Security & Authentication

### Windows Integrated Authentication

This example uses **Negotiate authentication** (Kerberos/NTLM):

```hcl
provider "hyperv-internal" {
  endpoint = "http://localhost:5000"

  auth {
    method = "negotiate"  # Windows Integrated Auth
  }
}
```

**How it works:**
1. Terraform calls the HyperV API
2. API impersonates the calling user's credentials
3. Hyper-V operations execute with user's permissions
4. Policy enforcement validates paths against user's group membership

### Policy Enforcement

With `enforce_policy_paths = true`, all operations are validated:

- VM disk paths must be in allowed directories
- Parent VHDX paths must be in approved template locations
- User's group membership determines allowed paths
- Prevents privilege escalation or unauthorized access

### Security Best Practices

✅ **Always use Negotiate auth** in production
✅ **Enable policy enforcement** for compliance
✅ **Use service accounts** with minimal required permissions
✅ **Audit API access** through Windows Event Logs
✅ **Secure parent templates** with read-only permissions
✅ **Enable TPM and Secure Boot** for Gen 2 VMs
✅ **Encrypt sensitive data disks** where required

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Windows Parent Template (Single Source)                     │
│ windows-server-2022-base.vhdx (~15GB)                      │
│ • Windows Server 2022                                       │
│ • Updates & drivers installed                              │
│ • Common software pre-installed                            │
│ • Sysprepped and generalized                               │
└────────────┬────────────────────────────────────────────────┘
             │ (Differencing Relationship)
             ├────────────────┬───────────────┬────────────────┐
             │                │               │                │
             ▼                ▼               ▼                ▼
    ┌────────────────┐ ┌──────────────┐ ┌─────────────┐ ┌─────────────┐
    │ Web Server     │ │ App Server   │ │ DB Server   │ │ VDI Users   │
    │ prod-win-web   │ │ prod-win-app │ │ prod-win-db │ │ (3 VMs)     │
    ├────────────────┤ ├──────────────┤ ├─────────────┤ ├─────────────┤
    │ OS: Diff (~40MB)│ │ OS: Diff    │ │ OS: Diff    │ │ OS: Diff ea │
    │ Data: 50GB Dyn │ │ Bin: 30GB Fix│ │ DB: 200GB   │ │ Each ~40MB  │
    │                │ │ Data:100GB Dy│ │ Log: 50GB   │ │             │
    │                │ │              │ │ Bak: 500GB  │ │             │
    └────────────────┘ └──────────────┘ └─────────────┘ └─────────────┘

    Storage Savings: ~98% for OS disks (7 VMs from 1 template)
```

## 🎓 Use Cases

### 1. VDI Environment
Deploy hundreds of user workstations from a single golden image:
- **Storage**: 90-95% savings for fresh desktops
- **Management**: Update template → recreate user VMs
- **Performance**: Fast boot from shared parent (cached in RAM)

### 2. Dev/Test Environments
Rapid environment provisioning:
- **Speed**: New test environment in seconds
- **Consistency**: All devs start from same baseline
- **Cleanup**: Delete VMs, minimal storage impact

### 3. Multi-Tier Applications
Production workloads with optimal disk configurations:
- **Web tier**: Differencing OS + dynamic data
- **App tier**: Differencing OS + fixed binaries + dynamic data
- **DB tier**: Differencing OS + fixed DB files + dynamic backups

### 4. Disaster Recovery
Quick restoration from templates:
- **Recovery Time**: Minutes instead of hours
- **Storage**: Minimal space for parent backups
- **Testing**: Validate DR procedures without impacting production storage

## ⚙️ Configuration Reference

### Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `endpoint` | string | `http://localhost:5000` | HyperV API endpoint |
| `parent_vhdx_path` | string | `C:/HyperV/VHDX/Users/templates/...` | Parent template path |
| `vm_name_prefix` | string | `prod-win` | VM name prefix |
| `switch_name` | string | `Default Switch` | Hyper-V virtual switch |

### Resources Created

| Resource | Count | Description |
|----------|-------|-------------|
| `hyperv-internal_vm.web_server` | 1 | Web server with IIS |
| `hyperv-internal_vm.app_server` | 1 | Application server |
| `hyperv-internal_vm.db_server` | 1 | Database server (SQL Server ready) |
| `hyperv-internal_vm.vdi_users` | 3 | VDI user workstations |
| `hyperv-internal_vm.dev_workstation` | 1 | Development environment |

## 🔧 Troubleshooting

### Provider Download Issues

**Error:** `Could not retrieve the list of available versions`

**Solution:**
```powershell
# Verify Terraform Registry access
curl https://registry.terraform.io/v1/providers/roosterslab/hyperv-internal

# Check firewall/proxy settings
# Set proxy if needed:
$env:HTTPS_PROXY = "http://proxy:8080"

# Re-initialize
terraform init
```

### Authentication Failures

**Error:** `401 Unauthorized` or `Access denied`

**Solution:**
```powershell
# Verify API is running with Negotiate auth enabled
curl http://localhost:5000/api/v2/whoami --negotiate -u :

# Check user is in Hyper-V Administrators group
net localgroup "Hyper-V Administrators"

# Run PowerShell as Administrator
```

### Parent VHDX Not Found

**Error:** `Parent VHD not found` or `Path not allowed by policy`

**Solution:**
```powershell
# Verify parent exists
Test-Path "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx"

# Check policy configuration
curl http://localhost:5000/api/v2/policy

# Ensure parent path is in allowed ParentVhdxRootsByGroup
```

### Disk Creation Failures

**Error:** `Access denied` creating child VHDX

**Solution:**
```powershell
# Verify destination directory exists and is writable
New-Item -ItemType Directory -Path "C:\HyperV\VHDX\Users\prod-win-web-01" -Force

# Check NTFS permissions
icacls "C:\HyperV\VHDX\Users\prod-win-web-01"

# User must have write permissions
```

### VM Start Failures

**Error:** VM created but won't start

**Solution:**
```powershell
# Check VM state
Get-VM "prod-win-web-01" | Format-List State, Status

# View VM event logs
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 20

# Common issues:
# - Boot disk not marked as bootable
# - Secure Boot template mismatch
# - Network switch not found
```

## 🧹 Cleanup

### Standard Cleanup (Preserves Template)

```powershell
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terrraform-provider-hypervapi-v2-new\examples-public\windows-full-with-differencing

# Destroy all VMs and child disks
terraform destroy
```

Type `yes` when prompted. This will:
- ✅ Stop all running VMs
- ✅ Delete all VMs
- ✅ Delete all child differencing VHDXs
- ✅ Delete all data disks (logs, backups, etc.)
- ✅ **Preserve** the parent template

### Complete Cleanup (Including Template)

```powershell
# First destroy Terraform resources
terraform destroy

# Then manually remove parent template
Remove-Item "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx" -Force
```

### Emergency Cleanup (Manual)

If Terraform cleanup fails:

```powershell
# Force stop and remove all VMs
Get-VM | Where-Object { $_.Name -like "prod-win-*" } | ForEach-Object {
    Stop-VM -Name $_.Name -TurnOff -Force -ErrorAction SilentlyContinue
    Remove-VM -Name $_.Name -Force
}

# Remove all VHDX files
Remove-Item "C:\HyperV\VHDX\Users\prod-win-*" -Recurse -Force
```

## 📚 Next Steps

### 1. Customize for Your Environment

```hcl
# terraform.tfvars
endpoint           = "https://hyperv-api.yourdomain.com:5443"
parent_vhdx_path   = "\\\\fileserver\\templates\\win2022-golden.vhdx"
vm_name_prefix     = "your-prefix"
switch_name        = "Production Network"
```

### 2. Integrate with CI/CD

```yaml
# Example Azure DevOps pipeline
- task: TerraformCLI@0
  inputs:
    command: 'apply'
    workingDirectory: '$(System.DefaultWorkingDirectory)/terraform'
    environmentServiceName: 'HyperV-Production'
```

### 3. Add Monitoring and Alerts

```powershell
# Monitor VM health
$vms = Get-VM | Where-Object { $_.Name -like "prod-win-*" }
foreach ($vm in $vms) {
    if ($vm.State -ne "Running" -and $vm.Name -notlike "*vdi*") {
        Send-MailMessage -To "ops@company.com" `
                         -Subject "VM Down: $($vm.Name)" `
                         -Body "Critical VM is not running!"
    }
}
```

### 4. Implement Backup Strategy

```powershell
# Export parent template regularly
Export-VM -Name "windows-server-2022-base" `
          -Path "\\\\backup-server\\templates" `
          -CaptureLiveState CaptureCrashConsistentState

# Backup critical data disks
$vms = Get-VM "prod-win-db-01"
$vms | Get-VMHardDiskDrive | Where-Object { $_.Path -like "*db-files*" } |
    ForEach-Object {
        Export-VMSnapshot -Name "Daily-Backup" -Path "\\\\backup\\db"
    }
```

### 5. Scale to Production

- **Multiple Templates**: Create specialized templates (Web, App, DB)
- **Automation**: Use Terraform workspaces for dev/staging/prod
- **Monitoring**: Integrate with System Center, Prometheus, or DataDog
- **High Availability**: Use Hyper-V Replica for critical VMs
- **Performance**: Monitor parent VHDX cache hit rates

## 📖 Related Documentation

- [HyperV Provider Registry](https://registry.terraform.io/providers/roosterslab/hyperv-internal)
- [Differencing VHDX Guide](../../DIFFERENCING-VHDX-SUPPORT.md)
- [API Authentication Guide](../../../hyperv-mgmt-api-v2/docs-md/authentication.md)
- [Policy Configuration](../../../hyperv-mgmt-api-v2/docs-md/parent-vhdx-policy-guide.md)
- [Terraform Provider Development](../../docs/development.md)

## ✅ Summary

This example demonstrates enterprise-grade Windows infrastructure deployment with:

- ✅ **Published Provider**: Using official Terraform Registry package
- ✅ **Secure Authentication**: Windows Integrated with impersonation
- ✅ **Storage Efficiency**: 90-98% savings with differencing VHDXs
- ✅ **Policy Compliance**: Enforced path validation
- ✅ **Production Ready**: Multi-tier architecture with mixed disk types
- ✅ **Scalable**: VDI pattern supports hundreds of users
- ✅ **Manageable**: Single template updates propagate to all VMs

**Ready for production deployment!** 🚀
