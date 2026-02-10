terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

variable "endpoint" { type = string }
variable "vm_name" { type = string }

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth { method = "negotiate" }
  # Turn on verbose HTTP logs from the provider (shown in Terraform debug logs)
  log_http = true
}

data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 40
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # Pass planned OS disk path/size to API create
  new_vhd_path    = data.hypervapiv2_disk_plan.os.path
  new_vhd_size_gb = 40

  # Pending full disk schema, we emulate minimal fields via the stub VM resource
  # In a future iteration, feed disk path and layout into the unified schema.
}

output "os_disk_path" { value = data.hypervapiv2_disk_plan.os.path }
