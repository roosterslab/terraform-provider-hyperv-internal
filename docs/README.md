# hypervapiv2 Provider Docs

Purpose: Terraform provider for Hyper-V Management API v2. Thin mapping, server-enforced policy, intuitive HCL, and demos-as-tests.

Start Here
- HCL Reference: `terraform-provider-hypervapi-v2/docs/HCL-Reference.md`
- VM Resource details: `terraform-provider-hypervapi-v2/docs/Resources-VM.md`
- Data Sources: `terraform-provider-hypervapi-v2/docs/Data-Sources.md`
- Design: `terraform-provider-hypervapi-v2/plan.md`
- Authentication:
  - Comparison and gaps: `terraform-provider-hypervapi-v2/docs/Auth-Negotiate-Comparison.md`
  - Update plan: `terraform-provider-hypervapi-v2/docs/Auth-Update-Plan.md`

Quick Start
```hcl
terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

provider "hypervapiv2" {
  endpoint = "http://localhost:5006"
  auth { method = "negotiate" }
}

# Suggest path per server policy
data "hypervapiv2_disk_plan" "os" {
  vm_name   = "demo"
  operation = "create"
  purpose   = "os"
  size_gb   = 20
}

resource "hypervapiv2_vm" "vm" {
  name   = "demo"
  cpu    = 2
  memory = "2GB"
  power  = "stopped"

  # Unified disk; provider will auto-place if no path
  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    size    = "20GB"
  }
}
```

Conventions
- Policy/auth are enforced by the API server; provider does not enforce locally.
- Demos under `demo/*` include Run/Test/Destroy PowerShell helpers.

Production Examples
- `examples/windows_os_demo`: Creates a Windows VM by cloning a base VHDX in Production (Negotiate) mode using `hypervapiv2_disk_plan` for policy-aware placement. Includes `Run.ps1`, `Test.ps1`, and `Destroy.ps1`.
- `examples/windows_os_demo_impersonate`: Same as above, but executes Terraform under specified Windows credentials (see `Run.ps1 -Username/-Password`).
- `examples/who-am-i-examples/*`: Minimal identity probes:
  - `current-user-sspi` — SSPI Negotiate with current user
  - `explicit-impersonation` — Username/password via Windows impersonation + SSPI (preferred)
  - `raw-ntlm-fallback` — Optional; requires `$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = "1"`

Numbered Demos (who-am-i)
- `demo/17-who-am-i-current-user-sspi`
- `demo/18-who-am-i-impersonation`
- `demo/19-who-am-i-raw-ntlm`
