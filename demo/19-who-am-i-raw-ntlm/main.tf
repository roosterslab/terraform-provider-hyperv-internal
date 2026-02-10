terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

variable "endpoint" { type = string }
variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

# Note: This path uses raw NTLM and requires setting env var before running:
#   $env:HYPERVAPI_V2_ALLOW_RAW_NTLM = "1"
provider "hypervapiv2" {
  endpoint = var.endpoint
  auth {
    method   = "negotiate"
    username = var.username
    password = var.password
  }
}

data "hypervapiv2_whoami" "me" {}

output "user"   { value = data.hypervapiv2_whoami.me.user }
output "domain" { value = data.hypervapiv2_whoami.me.domain }
output "sid"    { value = data.hypervapiv2_whoami.me.sid }
output "groups" { value = data.hypervapiv2_whoami.me.groups }
