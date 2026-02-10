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

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # Unified disk block with auto-placement (provider will call PlanDisk)
  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "20GB"
    type    = "dynamic"
  }
}

