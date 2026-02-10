terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

variable "endpoint" { type = string }

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth { method = "negotiate" }
  enforce_policy_paths = true
  log_http = true
}

# Intentionally use an unsupported extension to demonstrate denial
data "hypervapiv2_path_validate" "neg" {
  path      = "C:/Windows/Temp/sample.iso"
  operation = "create"
  ext       = "iso"
}

output "neg_allowed"      { value = data.hypervapiv2_path_validate.neg.allowed }
output "neg_message"      { value = data.hypervapiv2_path_validate.neg.message }
output "neg_violations"   { value = data.hypervapiv2_path_validate.neg.violations }

