terraform {
  required_providers {
    hypervapiv2 = {
      source  = "local/vinitsiriya/hypervapiv2"
      version = "0.0.1"
    }
  }
}

provider "hypervapiv2" {
  endpoint = "http://localhost:5000"
  auth {
    method = "none"
  }
}

# Test 1: Create VM with differencing disk (Dynamic parent)
resource "hypervapiv2_vm" "test_differencing_dynamic" {
  name       = "tf-diff-test-01"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  # Differencing disk from dynamic parent
  new_vhd_path   = "C:\\Temp\\HyperV-Test\\Diff\\child-dynamic.vhdx"
  vhd_type       = "Differencing"
  parent_path    = "C:\\Temp\\HyperV-Test\\Templates\\parent-dynamic.vhdx"

  vm_lifecycle {
    delete_disks = true
  }
}

# Test 2: Create VM with fixed disk (for comparison)
resource "hypervapiv2_vm" "test_fixed" {
  name       = "tf-fixed-test-01"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  new_vhd_path    = "C:\\Temp\\HyperV-Test\\Fixed\\disk-fixed.vhdx"
  new_vhd_size_gb = 10
  vhd_type        = "Fixed"

  vm_lifecycle {
    delete_disks = true
  }
}

# Test 3: Create VM with dynamic disk (default - backward compatibility)
resource "hypervapiv2_vm" "test_dynamic" {
  name       = "tf-dynamic-test-01"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  new_vhd_path    = "C:\\Temp\\HyperV-Test\\Dynamic\\disk-dynamic.vhdx"
  new_vhd_size_gb = 10
  # vhd_type omitted - should default to Dynamic

  vm_lifecycle {
    delete_disks = true
  }
}

# Test 4: Create VM using disk{} block with differencing disk
resource "hypervapiv2_vm" "test_disk_block_differencing" {
  name       = "tf-diff-test-02"
  generation = 2
  cpu        = 2
  memory     = "2GB"

  disk {
    name        = "os"
    purpose     = "os"
    boot        = true
    path        = "C:\\Temp\\HyperV-Test\\Diff\\child-block.vhdx"
    type        = "Differencing"
    parent_path = "C:\\Temp\\HyperV-Test\\Templates\\parent-dynamic.vhdx"
  }

  vm_lifecycle {
    delete_disks = true
  }
}

# Output VM details
output "differencing_vm_1" {
  value = {
    id   = hypervapiv2_vm.test_differencing_dynamic.id
    name = hypervapiv2_vm.test_differencing_dynamic.name
  }
}

output "differencing_vm_2" {
  value = {
    id   = hypervapiv2_vm.test_disk_block_differencing.id
    name = hypervapiv2_vm.test_disk_block_differencing.name
  }
}

output "fixed_vm" {
  value = {
    id   = hypervapiv2_vm.test_fixed.id
    name = hypervapiv2_vm.test_fixed.name
  }
}

output "dynamic_vm" {
  value = {
    id   = hypervapiv2_vm.test_dynamic.id
    name = hypervapiv2_vm.test_dynamic.name
  }
}
