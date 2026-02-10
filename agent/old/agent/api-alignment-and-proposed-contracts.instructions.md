---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Align provider with API v2 and draft proposed contracts where gaps exist; keep provider thin and policy-aligned."
---

# API Alignment and Proposed Contracts

This node maps provider needs to API endpoints and drafts proposals for missing capabilities. Keep server-side details in the API repo (`hyperv-mgmt-api-v2/agent/*`).

## Principles

- Do not copy server logic. Ask the API for suggestions/validation; apply only minimal, policy-compliant actions.
- Prefer GET/POST shapes that return normalized fields and human-readable `reason`/`warnings`.

## Current mappings (representative)

- Disk create/clone/attach → POST `/vhdx/create` · `/vhdx/clone` · `/vm/attach-vhd`
- NIC ops → POST `/vm/nic`
- Firmware → POST `/vm/firmware`
- Security → POST `/vm/security`
- Power → POST `/vm/power`
- Switch → POST `/vswitch`

Cross-check against `hyperv-mgmt-api-v2/src/HyperV.Management.Api/Program.cs` and its agent docs.

## Proposed endpoints (from SCAN-REPORT.md)

1) POST `/policy/plan-disk`
- Request: `{ vm_name, operation: "create|clone|attach", purpose, size_gb?, clone_from?, prefer_root?, min_free_gb?, co_locate_with?, ext? }`
- 200: `{ path, reason, matched_root, normalized_path, writable, free_gb_after, host, warnings: [] }`
- 403: `{ code: "forbidden", message, violations: [] }`

2) POST `/policy/validate-path`
- Request: `{ path, operation: "create|clone|attach", ext }`
- 200: `{ allowed, matched_root, normalized_path, message, violations: [] }`

3) POST `/policy/vm-plan`
- Request: `{ vm_name, cpu, memory, disks: [...], network: [...] }`
- 200: `{ resolved: { cpu, memory_mb, disks: [{ name, path, mode, controller, lun, reason, warnings: [] }], network: [{ switch, mac_suggested }] }, warnings: [], errors: [] }`

4) GET `/identity/whoami`
- 200: `{ user, domain, sid, groups: [] }`

5) GET `/host/info`
- 200: `{ tpm_supported, encryption_toggle_supported, secure_boot_templates: [], max_vcpu, storage_roots: [{ root,total_gb,free_gb }], clustered, host }`

6) GET `/policy/effective`
- 200: `{ roots: [], extensions: [], quotas: { root: { max_gb, used_gb, free_gb } }, name_patterns: { vm, switch }, deny_reasons: {} }`

7) GET `/images`
- 200: `{ images: [{ path, size_gb, created, tags: [], notes }] }`

8) POST `/names/validate`
- Request: `{ kind: "vm|switch", name }`
- 200: `{ allowed, pattern, suggestions: [], message }`

## Error model (surface in provider)

- 401 Unauthorized → Fix `auth` block / credentials.
- 403 Policy/JEA denial → Outside roots, disallowed cmdlet, RBAC.
- 409 Conflict/busy → Tune `stop_method`/timeouts.
- 400 Host limitation → E.g., cannot toggle Encryption Support; provider warns, continues with TPM if requested.

## Change process

- Draft or update request/response in this file.
- Open an issue/PR in the API repo; update their agent docs (ownership lives there).
- Keep provider guarded (feature flag, or error with clear message) until API ships.
