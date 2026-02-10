# Quick Start Guide - 5 Minutes to Deployment

Get your Windows infrastructure running in 5 minutes!

## Prerequisites Checklist

- [ ] Windows Server 2019+ or Windows 10/11 Pro
- [ ] Hyper-V enabled
- [ ] Administrator PowerShell session
- [ ] HyperV Management API running on port 5000
- [ ] Terraform 1.5+ installed
- [ ] Internet connection (to download provider)

## Step 1: Run Setup Script (2 minutes)

```powershell
# Navigate to example directory
cd C:\Users\globql-ws\Documents\projects\hyperv-management-api-dev\terrraform-provider-hypervapi-v2-new\examples-public\windows-full-with-differencing

# Run automated setup
.\setup.ps1 -CreateTemplate
```

**What this does:**
- ✓ Creates necessary directories
- ✓ Creates empty 127GB parent template VHDX
- ✓ Validates prerequisites
- ✓ Creates terraform.tfvars with defaults

## Step 2: Initialize Terraform (30 seconds)

```powershell
terraform init
```

**Expected output:**
```
Downloading roosterslab/hyperv-internal 0.1.0 from Terraform Registry...
Terraform has been successfully initialized!
```

## Step 3: Deploy Infrastructure (2 minutes)

```powershell
# Quick deployment (creates 7 VMs)
terraform apply -auto-approve
```

**What gets deployed:**
- 1 Web Server (2 CPU, 4GB RAM)
- 1 App Server (4 CPU, 8GB RAM)
- 1 DB Server (8 CPU, 16GB RAM)
- 3 VDI User Workstations (2 CPU, 4GB RAM each)
- 1 Dev Workstation (6 CPU, 12GB RAM)

**Total:** 7 VMs using differencing disks = ~98% storage savings! 🎉

## Step 4: Verify Deployment (30 seconds)

```powershell
# Check VMs
Get-VM | Where-Object { $_.Name -like "prod-win-*" } |
    Format-Table Name, State, CPUUsage, @{L="Memory(GB)";E={$_.MemoryAssigned/1GB}}

# Verify storage savings
terraform output deployment_summary
```

## Step 5: Start Using Your VMs!

```powershell
# Connect to web server
vmconnect localhost "prod-win-web-01"

# Connect to database server
vmconnect localhost "prod-win-db-01"

# Start VDI user workstations
Start-VM -Name "prod-win-vdi-user-1"
```

---

## ⚡ Ultra-Quick Testing (Empty Template)

Just want to test the provider quickly?

```powershell
# 1. Setup with empty template
.\setup.ps1 -CreateTemplate

# 2. Deploy
terraform init
terraform apply -auto-approve

# 3. Verify (VMs won't boot without OS, but will be created!)
Get-VM | Where-Object { $_.Name -like "prod-win-*" }

# 4. Cleanup
terraform destroy -auto-approve
```

**Time:** < 3 minutes total

---

## 🚀 Production-Ready Setup (With Windows Server)

For actual production use:

### 1. Create Proper Template (One-Time, ~30 minutes)

```powershell
# Create base VHDX
New-VHD -Path "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx" `
        -SizeBytes 127GB -Dynamic

# Create temporary VM
New-VM -Name "Template-Builder" `
       -Generation 2 `
       -MemoryStartupBytes 4GB `
       -VHDPath "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx"

# Add Windows Server ISO
Add-VMDvdDrive -VMName "Template-Builder" `
               -Path "D:\ISOs\Windows_Server_2022.iso"

# Start VM and install Windows Server
Start-VM -Name "Template-Builder"

# After installation, install updates and software, then:
# Inside the VM: C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown

# Once shut down, remove the temporary VM
Remove-VM -Name "Template-Builder" -Force

# Template is ready!
```

### 2. Deploy Production Infrastructure

```powershell
# Run setup
.\setup.ps1

# Deploy
terraform init
terraform apply

# All VMs will boot with Windows Server!
```

---

## 🔧 Troubleshooting Quick Fixes

### Provider Download Fails
```powershell
# Check internet connection
Test-NetConnection registry.terraform.io -Port 443

# Set proxy if needed
$env:HTTPS_PROXY = "http://proxy:8080"
terraform init
```

### API Not Running
```powershell
# Start API
cd C:\path\to\hyperv-mgmt-api-v2
dotnet run --project src\HyperV.Management.Api\HyperV.Management.Api.csproj

# In another window:
curl http://localhost:5000/api/v2/whoami
```

### Authentication Failed
```powershell
# Verify you're in Hyper-V Administrators group
net localgroup "Hyper-V Administrators"

# Add yourself if needed (requires admin)
net localgroup "Hyper-V Administrators" $env:USERNAME /add
```

### Parent Template Not Found
```powershell
# Verify path
Test-Path "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx"

# Re-run setup if missing
.\setup.ps1 -CreateTemplate
```

---

## 📊 What You Get

### Storage Comparison

| Deployment Method | Storage Used | VMs Created |
|-------------------|--------------|-------------|
| **Traditional** (7 × 127GB) | ~889 GB | 7 |
| **With Differencing** | ~16 GB | 7 |
| **Savings** | **98.2%** | Same! |

### VM Breakdown

| VM Type | Count | Purpose | Auto-Start |
|---------|-------|---------|------------|
| Web Server | 1 | IIS hosting | ✓ Yes |
| App Server | 1 | Business logic | ✓ Yes |
| DB Server | 1 | SQL Server | ✓ Yes |
| VDI Users | 3 | End-user desktops | ✗ No |
| Dev Workstation | 1 | Development | ✓ Yes |

---

## 🧹 Quick Cleanup

```powershell
# Destroy everything
terraform destroy -auto-approve

# Optional: Remove template too
Remove-Item "C:\HyperV\VHDX\Users\templates\windows-server-2022-base.vhdx" -Force
```

---

## 📚 Need More Details?

- **Full documentation**: See `README.md`
- **Configuration options**: See `terraform.tfvars.example`
- **Setup script help**: `Get-Help .\setup.ps1 -Detailed`

---

## 💡 Pro Tips

1. **First-time users**: Start with empty template to test, then build proper template
2. **Storage optimization**: Put parent template on fast SSD for better performance
3. **Network planning**: Create dedicated virtual switches for production/test/dev
4. **Template updates**: Update parent → recreate child disks → all VMs updated
5. **Monitoring**: Use `Get-VM` and `Get-VHD` cmdlets to monitor resource usage

---

## 🎓 Next Steps After Deployment

1. **Customize VMs**: Connect and configure each VM for your workload
2. **Add more VMs**: Duplicate resource blocks in `main.tf`
3. **Integrate monitoring**: Set up health checks and alerts
4. **Backup strategy**: Back up parent template and critical VMs
5. **Scale up**: Deploy to multiple Hyper-V hosts

---

**Questions?** Check the full `README.md` or open an issue on GitHub!

**Ready to deploy?** Run `.\setup.ps1 -CreateTemplate` and get started! 🚀
