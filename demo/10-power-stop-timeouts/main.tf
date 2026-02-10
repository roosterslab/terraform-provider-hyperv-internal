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
  size_gb   = 20
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"
  stop_method          = "graceful"
  wait_timeout_seconds = 120

  new_vhd_path    = data.hypervapiv2_disk_plan.os.path
  new_vhd_size_gb = 20
}

output "os_disk_path" { value = data.hypervapiv2_disk_plan.os.path }
