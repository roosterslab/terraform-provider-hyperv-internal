terraform {
  required_providers {
    hypervapiv2 = {
      source = "vinitsiriya/hypervapiv2"
      version = "0.0.0"
    }
  }
}

variable "endpoint" { type = string }
variable "username" {
  type    = string
  default = ""
}
variable "password" {
  type    = string
  default = ""
}
variable "vm_name"  { type = string }
variable "base_vhdx_path" {
  type        = string
  description = "Path to the base VHDX to clone from (must exist)"
  default     = "C:/HyperV/VHDX/Users/templates/windows-base.vhdx"
}

provider "hypervapiv2" {
  endpoint = var.endpoint
  # Production: Windows Integrated Authentication (current user or explicit credentials)
  auth {
    method   = "negotiate"
    username = var.username
    password = var.password
  }
  enforce_policy_paths = true
}

# Plan OS disk path (clone)
data "hypervapiv2_disk_plan" "os" {
  vm_name    = var.vm_name
  operation  = "clone"
  purpose    = "os"
  clone_from = var.base_vhdx_path
}

resource "hypervapiv2_vm" "win" {
  name       = var.vm_name
  cpu        = 4
  memory     = "4GB"
  power      = "stopped"
  switch_name = "Default Switch"

  # Clone OS disk from base, use planned path
  disk {
    name       = "os"
    purpose    = "os"
    boot       = true
    controller = "SCSI"
    lun        = 0
    path       = data.hypervapiv2_disk_plan.os.path
    clone_from = var.base_vhdx_path
  }

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  security {
    tpm     = true
    encrypt = false
  }

  vm_lifecycle { delete_disks = true }
}

output "os_disk_path"      { value = data.hypervapiv2_disk_plan.os.path }
output "policy_roots"      { value = data.hypervapiv2_policy.current.roots }
output "policy_extensions" { value = data.hypervapiv2_policy.current.extensions }
output "base_vhdx"         { value = var.base_vhdx_path }

# Useful policy snapshot
data "hypervapiv2_policy" "current" {}
