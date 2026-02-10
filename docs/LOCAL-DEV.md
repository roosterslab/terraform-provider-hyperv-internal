# Local Development: Provider + Example

This doc shows the standard way to run the examples with a locally built provider binary, without copying the binary into the example folder.

## Prerequisites
- Go toolchain installed (for building the provider)
- .NET SDK installed (for building/running the API)
- Terraform CLI installed (64-bit recommended; 32-bit supported)

## Build the provider
```powershell
cd "C:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2"
go build -o .\bin\terraform-provider-hypervapiv2.exe .\main.go
```

Optional: build 32-bit for `windows_386` consumers
```powershell
set GOARCH=386; go build -o .\bin\terraform-provider-hypervapiv2_32.exe .\main.go
$env:GOARCH="amd64"  # restore if needed
```

## Point Terraform to the local provider (dev override)
Create `%APPDATA%\terraform.rc` with a `dev_overrides` that targets the provider `bin` directory.

```hcl
provider_installation {
  dev_overrides {
    "vinitsiriya/hypervapiv2" = "C:\\Users\\ws-user\\Documents\\projects\\hyper-v-experiments\\terraform-provider-hypervapi-v2\\bin"
  }
  direct {}
}
```

Notes
- Prefer using `%APPDATA%\terraform.rc` to avoid per-project overrides.
- Make sure no `TF_CLI_CONFIG_FILE` is pointing to another `.terraformrc`.

Quick task
```powershell
task terraform:provider:dev-override
```

## (Alternative) Install into Terraform plugin cache
If you prefer not to use dev overrides, you can place versioned binaries into Terraform's plugin cache so a pinned version is found offline.

```powershell
$pluginsRoot = Join-Path $env:APPDATA 'terraform.d\plugins\registry.terraform.io\vinitsiriya\hypervapiv2\0.0.0'
New-Item -ItemType Directory -Force -Path (Join-Path $pluginsRoot 'windows_amd64') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $pluginsRoot 'windows_386') | Out-Null
Copy-Item .\bin\terraform-provider-hypervapiv2.exe (Join-Path $pluginsRoot 'windows_amd64\terraform-provider-hypervapiv2_v0.0.0.exe') -Force
if (Test-Path .\bin\terraform-provider-hypervapiv2_32.exe) {
  Copy-Item .\bin\terraform-provider-hypervapiv2_32.exe (Join-Path $pluginsRoot 'windows_386\terraform-provider-hypervapiv2_v0.0.0.exe') -Force
}
```

Quick task
```powershell
task terraform:provider:cache-install
```

Then, in the example `main.tf`, pin:
```hcl
terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = "0.0.0"
    }
  }
}
```

## Run the API for the example
Use the provided script to start the API with the correct config:
```powershell
cd "C:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\scripts"
./Run-ApiForExample.ps1 -Action start
```

Quick tasks
```powershell
task api:start:example
task api:stop:example
```

To stop:
```powershell
./Run-ApiForExample.ps1 -Action stop
```

## Run the example (windows_os_demo)
```powershell
cd "C:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2\examples\windows_os_demo"
# Clean local state/cache if switching methods
if (Test-Path .terraform) { Remove-Item .terraform -Recurse -Force }
if (Test-Path .terraform.lock.hcl) { Remove-Item .terraform.lock.hcl -Force }

# Plan
terraform plan -var="endpoint=http://localhost:5006" -var="vm_name=test-vm"

# Apply
terraform apply -auto-approve -var="endpoint=http://localhost:5006" -var="vm_name=test-vm"
```

Outputs include the planned OS disk path and policy roots/extensions when policy enforcement is on.

## JEA setup via Policy CLI
Install the RoleCapability and register the `HyperV-API` endpoint (admin):
```powershell
dotnet run --project ..\..\hyperv-mgmt-api-v2\src\HyperV.Management.PolicyCli -- install-jea
dotnet run --project ..\..\hyperv-mgmt-api-v2\src\HyperV.Management.PolicyCli -- setup-jea --name HyperV-API --group 'BUILTIN\Administrators'
```

Quick task
```powershell
task jea:setup
```

## 32-bit considerations
- If Terraform CLI is 32-bit, it will resolve the `windows_386` provider build when available (cache method), or you can keep using the dev override pointing to a folder that contains only the 32-bit binary.
- On 64-bit systems, prefer 64-bit Terraform and the `windows_amd64` provider build.
