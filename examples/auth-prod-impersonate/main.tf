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
  type        = string
  description = "Username for explicit authentication (optional)"
  default     = ""
}
variable "password" {
  type        = string
  description = "Password for explicit authentication (optional)"
  sensitive   = true
  default     = ""
}

provider "hypervapiv2" {
  endpoint = var.endpoint
  auth {
    method = "negotiate"   # Windows Integrated Auth (Production API)
    username = var.username
    password = var.password
    # When username/password provided: uses NTLM auth with explicit credentials
    # When omitted: uses current user SSPI (Kerberos/NTLM)
  }
}

data "hypervapiv2_whoami" "me" {}

output "user"   { value = data.hypervapiv2_whoami.me.user }
output "domain" { value = data.hypervapiv2_whoami.me.domain }
output "sid"    { value = data.hypervapiv2_whoami.me.sid }
output "groups" { value = data.hypervapiv2_whoami.me.groups }

