terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hypervapiv2 = {
      source  = "roosterslab/hyperv-internal"
      version = "0.1.0"
    }
  }
}

# ============================================
# Variables - Configured for Your PC
# ============================================
variable "endpoint" {
  type    = string
  default = "http://localhost:5000"
}

variable "parent_vhdx_path" {
  type    = string
  default = "C:/Temp/HyperV-Test/Templates/parent-demo.vhdx"
}

variable "switch_name" {
  type    = string
  default = "Default Switch"
}

# ============================================
# Provider Configuration
# ============================================
provider "hypervapiv2" {
  endpoint = var.endpoint

  # Windows Integrated Authentication (uses current user)
  auth {
    method = "negotiate"
  }

  timeout_seconds = 300
}

# ============================================
# Demo VM 1: Web Server
# ============================================
resource "hypervapiv2_vm" "demo_web" {
  name       = "demo-web-01"
  generation = 2
  cpu        = 2
  memory     = "2GB"
  power      = "stopped"  # Don't auto-start for demo

  switch_name = var.switch_name

  # Differencing disk from parent
  new_vhd_path = "C:/Temp/HyperV-Test/Demo/demo-web-os.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Demo VM 2: App Server with Multiple Disks
# ============================================
resource "hypervapiv2_vm" "demo_app" {
  name       = "demo-app-01"
  generation = 2
  cpu        = 2
  memory     = "2GB"
  power      = "stopped"

  switch_name = var.switch_name

  # OS disk - differencing
  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    controller  = "SCSI"
    lun         = 0
    path        = "C:/Temp/HyperV-Test/Demo/demo-app-os.vhdx"
    type        = "Differencing"
    parent_path = var.parent_vhdx_path
  }

  # Data disk - dynamic
  disk {
    name       = "data"
    purpose    = "data"
    controller = "SCSI"
    lun        = 1
    path       = "C:/Temp/HyperV-Test/Demo/demo-app-data.vhdx"
    size       = "10GB"
    type       = "Dynamic"
  }

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Demo VM 3: VDI User (Lightweight)
# ============================================
resource "hypervapiv2_vm" "demo_vdi" {
  name       = "demo-vdi-user-01"
  generation = 2
  cpu        = 1
  memory     = "1GB"
  power      = "stopped"

  switch_name = var.switch_name

  # Differencing disk - same parent as others
  new_vhd_path = "C:/Temp/HyperV-Test/Demo/demo-vdi-os.vhdx"
  vhd_type     = "Differencing"
  parent_path  = var.parent_vhdx_path

  firmware {
    secure_boot          = true
    secure_boot_template = "MicrosoftWindows"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# ============================================
# Outputs
# ============================================
output "demo_vms" {
  description = "Deployed demo VMs"
  value = {
    web_server = {
      name  = hypervapiv2_vm.demo_web.name
      id    = hypervapiv2_vm.demo_web.id
      state = hypervapiv2_vm.demo_web.power
    }
    app_server = {
      name  = hypervapiv2_vm.demo_app.name
      id    = hypervapiv2_vm.demo_app.id
      state = hypervapiv2_vm.demo_app.power
    }
    vdi_user = {
      name  = hypervapiv2_vm.demo_vdi.name
      id    = hypervapiv2_vm.demo_vdi.id
      state = hypervapiv2_vm.demo_vdi.power
    }
  }
}

output "storage_info" {
  description = "Storage configuration"
  value = {
    parent_template = var.parent_vhdx_path
    total_vms       = 3
    expected_savings = "~95% storage for empty disks"
    switch_used     = var.switch_name
  }
}
