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
  log_http = true
}

data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 10
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 1
  memory = "2GB"
  power  = "stopped"

  new_vhd_path    = data.hypervapiv2_disk_plan.os.path
  new_vhd_size_gb = 10

  vm_lifecycle { delete_disks = true }
}

output "os_disk_path" { value = data.hypervapiv2_disk_plan.os.path }

