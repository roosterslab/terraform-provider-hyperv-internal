---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Common failures with clear remedies; increase diagnostics without leaking secrets."
---

# Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| 401 Unauthorized | Auth misconfig | Check `auth` block; for Negotiate ensure Windows session and server SPNs; do not log secrets |
| 403 Forbidden | Policy/JEA denial | Validate path/name via data sources; update policy packs and JEA VisibleCmdlets on server |
| 400 Bad Request (Encryption Support) | Host limitation | Emit warning; proceed to TPM enable if requested; reflect readback state |
| 409 Conflict/Busy | Power or timing | Adjust `stop_method`/timeouts; add limited retries/backoff |
| Plan keeps changing sizes | Normalization mismatch | Normalize human sizes; suppress diffs with plan modifiers |
| Disk deletion unexpected | Scope misunderstanding | Only provider-owned VHDX are eligible; `disk.protect=true` prevents deletion |

## Diagnostics

- Include endpoint and `auth.method` in errors; never print tokens/passwords.
- Enable TF logs or provider diagnostics; redact sensitive data.
- For server issues, consult API logs and their agent docs in `hyperv-mgmt-api-v2/agent/*`.
