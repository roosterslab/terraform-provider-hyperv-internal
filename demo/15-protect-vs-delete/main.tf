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

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth { method = "negotiate" }
  enforce_policy_paths = true
}

data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 10
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # OS disk (applied)
  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "10GB"
    type    = "dynamic"
  }

  # Protected data disk (ignored by apply for now, but present in state to trigger provider behavior)
  disk {
    name    = "data"
    purpose = "data"
    size    = "10GB"
    protect = true
  }

  vm_lifecycle { delete_disks = true }
}

output "os_disk_path" { value = data.hypervapiv2_disk_plan.os.path }

