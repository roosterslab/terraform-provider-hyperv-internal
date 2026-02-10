terraform {
  required_providers {
    hypervapiv2 = {
      source = "local/vinitsiriya/hypervapiv2"
      version = "0.0.1"
    }
  }
}

variable "endpoint" {
  type    = string
  default = "http://localhost:5000"
}

variable "vm_name" {
  type    = string
  default = "win-demo-full"
}

variable "parent_vhdx_path" {
  type        = string
  description = "Path to the parent Windows VHDX template (must exist)"
  default     = "C:/HyperV/VHDX/Users/Templates/windows-base.vhdx"
}

variable "cpu_count" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "switch_name" {
  type    = string
  default = "Default Switch"
}

provider "hypervapiv2" {
  endpoint = var.endpoint
}

# Create Windows VM with differencing disk from parent template
resource "hypervapiv2_vm" "windows_full" {
  name       = var.vm_name
  generation = 2
  cpu_count  = var.cpu_count
  memory_mb  = var.memory_mb

  # Create differencing VHDX from parent template
  new_vhd_path = "C:/HyperV/VHDX/Users/Demo/${var.vm_name}-os.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  switch_name = var.switch_name

  # Enable SecureBoot for Windows
  enable_secure_boot = true

  # Enable TPM for Windows 11
  enable_tpm = true

  # Start the VM after creation
  auto_start = false

  vm_lifecycle {
    delete_disks = true
  }
}

# Optional: Add additional data disk (dynamic)
resource "hypervapiv2_vm_disk" "data_disk" {
  vm_name      = hypervapiv2_vm.windows_full.name
  attach_path  = "C:/HyperV/VHDX/Users/Demo/${var.vm_name}-data.vhdx"
  new_vhd_size_gb = 100
  vhd_type     = "Dynamic"
  read_only    = false
}

output "vm_name" {
  value = hypervapiv2_vm.windows_full.name
}

output "vm_id" {
  value = hypervapiv2_vm.windows_full.id
}

output "os_disk_path" {
  value = "C:/HyperV/VHDX/Users/Demo/${var.vm_name}-os.vhdx"
}

output "parent_template" {
  value = var.parent_vhdx_path
}

output "data_disk_path" {
  value = "C:/HyperV/VHDX/Users/Demo/${var.vm_name}-data.vhdx"
}

output "summary" {
  value = {
    vm_name         = var.vm_name
    cpu             = var.cpu_count
    memory_mb       = var.memory_mb
    os_disk_type    = "Differencing"
    parent_template = var.parent_vhdx_path
    data_disk_type  = "Dynamic"
    data_disk_size  = "100GB"
  }
}
