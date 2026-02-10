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

# Plan OS disk path for verification
data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 16
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "16GB"
    type    = "dynamic"
  }

  vm_lifecycle { delete_disks = true }
}

output "os_disk_path" { value = data.hypervapiv2_disk_plan.os.path }

