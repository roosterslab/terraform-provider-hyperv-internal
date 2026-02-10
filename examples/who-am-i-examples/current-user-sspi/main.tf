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
  auth { method = "negotiate" } # current user SSPI
}

data "hypervapiv2_whoami" "me" {}

output "user"   { value = data.hypervapiv2_whoami.me.user }
output "domain" { value = data.hypervapiv2_whoami.me.domain }
output "sid"    { value = data.hypervapiv2_whoami.me.sid }
output "groups" { value = data.hypervapiv2_whoami.me.groups }
