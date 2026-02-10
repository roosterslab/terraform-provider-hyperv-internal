terraform {
  required_providers {
    hypervapiv2 = {
      source  = "local/vinitsiriya/hypervapiv2"
      version = "0.0.1"
    }
  }
}

# Variables for customization
variable "endpoint" {
  type        = string
  description = "API endpoint URL"
  default     = "http://localhost:5000"
}

variable "parent_vhdx_path" {
  type        = string
  description = "Path to the parent/template VHDX"
  default     = "C:/Temp/HyperV-Test/Templates/parent-dynamic.vhdx"
}

variable "vm_name_prefix" {
  type        = string
  description = "Prefix for VM names"
  default     = "demo-diff"
}

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth {
    method = "none"  # For local testing
  }
}

# ============================================
# Example 1: Simple Differencing Disk
# ============================================
resource "hypervapiv2_vm" "simple_differencing" {
  name       = "${var.vm_name_prefix}-simple"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  # Create differencing disk from parent template
  new_vhd_path = "C:/Temp/HyperV-Test/Demo/simple-child.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Example 2: VDI-Style Multiple VMs from Same Parent
# ============================================
resource "hypervapiv2_vm" "vdi_users" {
  count = 3

  name       = "${var.vm_name_prefix}-vdi-user-${count.index + 1}"
  generation = 2
  cpu        = 2
  memory     = "4GB"

  # Each user gets their own differencing disk
  new_vhd_path = "C:/Temp/HyperV-Test/Demo/VDI/user-${count.index + 1}.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Example 3: Using disk{} Block with Differencing
# ============================================
resource "hypervapiv2_vm" "advanced_differencing" {
  name       = "${var.vm_name_prefix}-advanced"
  generation = 2
  cpu        = 4
  memory     = "8GB"

  # OS disk - differencing from template
  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    path        = "C:/Temp/HyperV-Test/Demo/advanced-os.vhdx"
    type        = "Differencing"
    parent_path = var.parent_vhdx_path
  }

  # Data disk - traditional dynamic disk
  disk {
    name    = "data"
    purpose = "data"
    path    = "C:/Temp/HyperV-Test/Demo/advanced-data.vhdx"
    size    = "20GB"
    type    = "Dynamic"
  }

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Example 4: Mixed Disk Types
# ============================================
resource "hypervapiv2_vm" "mixed_types" {
  name       = "${var.vm_name_prefix}-mixed"
  generation = 2
  cpu        = 2
  memory     = "4GB"

  # OS disk - differencing (fast provisioning)
  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    path        = "C:/Temp/HyperV-Test/Demo/mixed-os.vhdx"
    type        = "Differencing"
    parent_path = var.parent_vhdx_path
  }

  # Database disk - fixed (predictable performance)
  disk {
    name    = "database"
    purpose = "data"
    path    = "C:/Temp/HyperV-Test/Demo/mixed-db.vhdx"
    size    = "50GB"
    type    = "Fixed"
  }

  # Logs disk - dynamic (grows as needed)
  disk {
    name    = "logs"
    purpose = "data"
    path    = "C:/Temp/HyperV-Test/Demo/mixed-logs.vhdx"
    size    = "10GB"
    type    = "Dynamic"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Example 5: Development Environment
# ============================================
resource "hypervapiv2_vm" "dev_environment" {
  name       = "${var.vm_name_prefix}-dev"
  generation = 2
  cpu        = 4
  memory     = "8GB"
  power      = "running"  # Auto-start

  switch_name = "Default Switch"

  # Clone from dev template with all tools pre-installed
  new_vhd_path = "C:/Temp/HyperV-Test/Demo/dev-workspace.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Outputs
# ============================================
output "simple_vm" {
  description = "Simple differencing disk VM"
  value = {
    id   = hypervapiv2_vm.simple_differencing.id
    name = hypervapiv2_vm.simple_differencing.name
  }
}

output "vdi_vms" {
  description = "VDI user VMs (3 from same parent)"
  value = [
    for vm in hypervapiv2_vm.vdi_users : {
      id   = vm.id
      name = vm.name
    }
  ]
}

output "advanced_vm" {
  description = "Advanced VM with multiple disk types"
  value = {
    id   = hypervapiv2_vm.advanced_differencing.id
    name = hypervapiv2_vm.advanced_differencing.name
  }
}

output "mixed_vm" {
  description = "VM with mixed disk types (Differencing, Fixed, Dynamic)"
  value = {
    id   = hypervapiv2_vm.mixed_types.id
    name = hypervapiv2_vm.mixed_types.name
  }
}

output "dev_vm" {
  description = "Development environment VM"
  value = {
    id   = hypervapiv2_vm.dev_environment.id
    name = hypervapiv2_vm.dev_environment.name
  }
}

output "summary" {
  description = "Deployment summary"
  value = {
    total_vms       = 1 + 3 + 1 + 1 + 1  # 7 VMs total
    vdi_users       = 3
    parent_template = var.parent_vhdx_path
    expected_savings = "~90% storage for empty disks"
  }
}
