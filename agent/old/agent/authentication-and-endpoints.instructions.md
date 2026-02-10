---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "How to configure endpoints and authentication (none, bearer, negotiate), with proxy/timeout/TLS considerations."
---

# Authentication and Endpoints

## Provider config

- `endpoint`: e.g., `http://127.0.0.1:5006`
- `auth` block:
  - `method = "negotiate" | "bearer" | "none"`
  - `username`, `password` for basic/NTLM flows when needed (avoid storing secrets in state; prefer environment or OS session for Negotiate).
- `proxy`: URL or `null`.
- `timeout_seconds`: default 60; tune for power operations.
- TLS/CA: support custom CAs if HTTPS is used; expose a provider option (tbd) and document risks.

## Notes

- Negotiate: requires Windows context; works best when the API runs under a domain account and RBAC/policy is group-based.
- Bearer: pass token via Authorization header; avoid logging token; redact diagnostics.
- None: for dev only; do not use in production.

## Dev override

- Use a local CLI config (e.g., `dev.tfrc` like v1) in `Run.ps1` to point Terraform to the locally built provider binary in `bin/`.
- `Run.ps1` should print which binary and endpoint are used.

## Diagnostics

- Always include endpoint and `auth.method` in provider errors; never print credentials or tokens.
