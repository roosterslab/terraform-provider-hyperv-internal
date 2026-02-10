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
}

data "hypervapiv2_whoami" "me" {}

data "hypervapiv2_policy" "effective" {}

output "user" { value = data.hypervapiv2_whoami.me.user }
output "domain" { value = data.hypervapiv2_whoami.me.domain }
output "roots" { value = data.hypervapiv2_policy.effective.roots }
