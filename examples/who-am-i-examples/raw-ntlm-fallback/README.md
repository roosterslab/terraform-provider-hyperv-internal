# Raw NTLM Fallback Example

Use only if your API accepts raw NTLM. Before running, set:

```powershell
$env:HYPERVAPI_V2_ALLOW_RAW_NTLM = "1"
```

Then:

```powershell
terraform plan -var-file="terraform.tfvars"
```

Prefer `explicit-impersonation/` for servers that advertise `WWW-Authenticate: Negotiate`.
