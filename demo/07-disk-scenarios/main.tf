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
variable "base_vhdx_path" {
  type        = string
  description = "Path to the base VHDX file to clone from (must exist)"
  default     = "C:/HyperV/VHDX/Users/templates/example-base.vhdx"
}
variable "attach_vm_name" {
  type    = string
  default = null
}
variable "attach_source_path" {
  type    = string
  default = null
}

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth { method = "negotiate" }
  enforce_policy_paths = true
  log_http = true
}

# Clone (auto path) — used by disk{} clone_from scenario
data "hypervapiv2_disk_plan" "clone_auto" {
  vm_name    = var.vm_name
  operation  = "clone"
  purpose    = "os"
  clone_from = var.base_vhdx_path
}

# New disk auto path planning
data "hypervapiv2_disk_plan" "new_auto" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 20
}

# Validate new auto path
data "hypervapiv2_path_validate" "new_auto" {
  path      = data.hypervapiv2_disk_plan.new_auto.path
  operation = "create"
  ext       = "vhdx"
}

# Attach plan (for optional attach scenario)
data "hypervapiv2_disk_plan" "attach_plan" {
  count      = var.attach_source_path != null ? 1 : 0
  vm_name    = var.attach_vm_name != null ? var.attach_vm_name : var.vm_name
  operation  = "attach"
  purpose    = "os"
  size_gb    = 20  # Not used for attach, but required
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # Demonstrate clone scenario for OS disk; provider will clone then create VM
  disk {
    name       = "os"
    purpose    = "os"
    boot       = true
    path       = data.hypervapiv2_disk_plan.clone_auto.path
    clone_from = var.base_vhdx_path
  }
}

output "clone_auto_path" { value = data.hypervapiv2_disk_plan.clone_auto.path }
output "new_auto_path" { value = data.hypervapiv2_disk_plan.new_auto.path }
output "new_auto_allowed" { value = data.hypervapiv2_path_validate.new_auto.allowed }
output "attach_plan_reason" { value = null }

# Optional: Attach-from-existing scenario (OS disk attach)
# Provide both variables attach_vm_name and attach_source_path to enable
resource "hypervapiv2_vm" "vm_attach" {
  count  = var.attach_vm_name != null && var.attach_source_path != null ? 1 : 0
  name   = var.attach_vm_name != null ? var.attach_vm_name : ""
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # Create VM without new disk; then attach existing VHDX as OS disk
  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    source_path = var.attach_source_path
    read_only   = false
  }
}
