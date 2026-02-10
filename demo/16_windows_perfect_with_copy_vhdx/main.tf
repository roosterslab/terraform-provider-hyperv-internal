terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

variable "endpoint" { type = string }
variable "vm_name"  { type = string }
variable "username" {
  type    = string
  default = ""
}
variable "password" {
  type    = string
  default = ""
}
variable "base_vhdx_path" {
  type        = string
  description = "Path to the base VHDX file to clone from (must exist)"
  default     = "C:/HyperV/VHDX/Users/templates/windows-base.vhdx"
}

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth {
    method   = "negotiate"
    username = var.username
    password = var.password
  }
  enforce_policy_paths = true
  log_http = true
}

# Policy snapshot
data "hypervapiv2_policy" "current" {}

# Plan OS disk by cloning from base VHDX
data "hypervapiv2_disk_plan" "os" {
  vm_name    = var.vm_name
  operation  = "clone"
  purpose    = "os"
  clone_from = var.base_vhdx_path
}

# Validate planned path explicitly
data "hypervapiv2_path_validate" "os" {
  path      = data.hypervapiv2_disk_plan.os.path
  operation = "create"
  ext       = "vhdx"
}

resource "hypervapiv2_vm" "win" {
  name   = var.vm_name
  cpu    = 4
  memory = "4GB"
  power  = "stopped"
  stop_method          = "graceful"
  wait_timeout_seconds = 120
  generation           = 2
  switch_name          = "Default Switch"

  # unified disk block (clone with custom path)
  disk {
    name       = "os"
    purpose    = "os"
    boot       = true
    clone_from = var.base_vhdx_path
    path       = data.hypervapiv2_disk_plan.os.path
    controller = "SCSI"
    lun        = 0
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

output "policy_roots"      { value = data.hypervapiv2_policy.current.roots }
output "policy_extensions" { value = data.hypervapiv2_policy.current.extensions }
output "os_disk_path"      { value = data.hypervapiv2_disk_plan.os.path }
output "path_allowed"      { value = data.hypervapiv2_path_validate.os.allowed }
output "base_vhdx"         { value = var.base_vhdx_path }
output "secure_boot"       { value = hypervapiv2_vm.win.firmware.secure_boot }
output "secure_boot_template" { value = hypervapiv2_vm.win.firmware.secure_boot_template }
output "tpm_enabled"       { value = hypervapiv2_vm.win.security.tpm }
output "encrypt_enabled"   { value = hypervapiv2_vm.win.security.encrypt }
