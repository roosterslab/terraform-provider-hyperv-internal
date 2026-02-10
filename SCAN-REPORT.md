# hypervapiv2 — Context Scan Report (2025-10-25)

Purpose: capture current state across API and provider v1, align with `terraform-provider-hypervapi-v2/plan.md`, and list gaps/risks before drafting the new MCP agent docs.

## Sources scanned

- This repo: `hyperv-mgmt-api-v2/` (API server, .NET 8, JEA/policy) — focusing on `src/HyperV.Management.Api/Program.cs` and `src/HyperV.Management.Application/Services/*`.
- API agent docs: `hyperv-mgmt-api-v2/agent/*.instructions.md` (policy/JEA, identity/RBAC, feature add, testing/sanity, OpenAPI alignment).
- Current provider v1: `terraform-provider-hypervapi/` (Go, plugin framework) — provider, resources, data sources, scripts, and `agents/*.instructions.md`.
- v2 design spec: `terraform-provider-hypervapi-v2/plan.md` (intuitive HCL, plan-time helpers, disks model, strict mode).

## v2 design highlights (from plan.md)

- Intuitive primitives and human sizes ("8GB").
- Policy-by-construction: automatic suggestions; explicit paths validated at plan.
- Disk scenarios: new (auto/custom), clone (auto/custom), attach existing; deterministic controller/LUN; `protect` and `auto_attach` flags.
- Plan-time data sources: `disk_plan`, `path_validate`, `vm_plan`, `whoami`, `host_info`, `policy`, `vm_shape`, `images`, `name_check`.
- Provider features: `enforce_policy_paths`, `strict`, `defaults{}`; unified `hypervapiv2_vm` with `disk{}`, `network_interface{}`, `firmware{}`, `security{}`, `lifecycle{}`.
- Demos as tests: per-scenario `demo/<name>/{Run,Test,Destroy}.ps1` + `main.tf`.

## API server — present capabilities

- VM lifecycle (create/update/delete with identity-bound delete tokens and `delete_disks` policy checks).
- Firmware: Secure Boot + first boot app.
- Security: Encryption Support toggle (may be unsupported on some hosts), virtual TPM enable/disable.
- Switch: list/create/delete.
- Adapters: attach/connect.
- Policy inspection: allowed roots/extensions; suggested VHDX path/dir.
- RBAC: Negotiate auth in prod; group-based policy via `ICallerInfo`.
- JEA: ConstrainedLanguage; minimal cmdlets/providers; string projection + C# JSON parse.

## Current provider v1 — present capabilities

- Resources: VM, VM firmware, VM security, VM network adapter, switch.
- Data sources: VMs, switches, VM adapters, policy allowed paths, suggested VHDX path/dir.
- Auth: none/bearer/negotiate (Windows SSPI, optional impersonation).
- Docs: HCL user guide and per-resource/data source pages exist.
- Known behavior: continues TPM when encryption support returns 400; needs state stabilization for host limitations to avoid "inconsistent result after apply".

## Gaps vs v2 plan

Plan-time data sources to add (API+provider):
- disk_plan: suggest compliant path with `reason`, `matched_root`, `warnings`, capacity info.
- path_validate: operation-aware allow/deny with `violations[]`.
- vm_plan: resolve entire VM (cpu/mem normalized; disks with controller/LUN suggestions; network hints; aggregated warnings/errors).
- whoami: identity snapshot (user, groups).
- host_info: capabilities (tpm_supported, encryption_toggle_supported), secure boot templates, vCPU limits, storage roots capacity.
- policy: expanded summary including patterns and quotas.
- vm_shape: named preset sizing.
- images: discover base images (filtering/tagging).
- name_check: validate names with suggestions.

Provider modeling and UX:
- Unified `hypervapiv2_vm` schema with `disk{}` covering create/clone/attach; `placement{}` hints.
- Human size parsing; plan modifiers; strict mode; `enforce_policy_paths`.
- Deterministic controller/LUN; `protect` semantics; limited delete scope to provider-owned VHDX only.

## Proposed API additions (high-level)

- POST /policy/plan-disk → { path, reason, matched_root, normalized_path, writable, free_gb_after, warnings[] }
- POST /policy/validate-path → { allowed, matched_root, normalized_path, violations[], message }
- POST /policy/vm-plan → { resolved{cpu,memory_mb,disks[],network[]}, warnings[], errors[] }
- GET /identity/whoami → { user, domain, sid, groups[] }
- GET /host/info → { tpm_supported, encryption_toggle_supported, secure_boot_templates[], max_vcpu, storage_roots[] }
- GET /policy/effective → { roots[], extensions[], quotas{}, name_patterns{} }
- GET /images → { images[] { path, size_gb, created, tags[], notes } }
- POST /names/validate → { allowed, pattern, suggestions[], message }

Note: Align with existing policy/identity services where possible; keep JEA exposure minimal.

## Risks and considerations

- Host limitations: encryption support toggle not supported on some versions; plan must degrade gracefully; provider state must reflect reality.
- JEA provider visibility and ACLs for FileSystem; ensure plan-time endpoints avoid heavy JEA usage (prefer server-side policy + filesystem checks outside JEA where safe).
- Performance: plan-time data sources should be fast; avoid per-item fan-out.
- Policy drift: ensure plan-time suggestions match apply-time policy checks.

## Demo conventions (target for v2)

- `demo/<scenario>/main.tf` — minimal, reproducible.
- `demo/<scenario>/Run.ps1` — init/apply with dev override; prints endpoints/auth.
- `demo/<scenario>/Test.ps1` — assert with Terraform outputs + API GETs.
- `demo/<scenario>/Destroy.ps1` — destroy + external verification (e.g., disk removed if allowed).

## Suggested sequencing (build-out order)

1) Implement plan-time DS: `disk_plan`, `path_validate`, `policy`, `whoami`.
2) Unified `hypervapiv2_vm` with create/attach (new-auto, new-path, attach-existing); deterministic layout; minimal firmware/security.
3) Expand `vm_plan`, `host_info`, `name_check` and add clone flows.
4) Images discovery; preset shapes; strict mode and enforce policy.
5) Demos for each milestone scenario; CI scripts.

## Decision log anchors to capture during build

- Size normalization rules; controller/LUN defaulting; `protect` semantics.
- What defines "provider-owned" VHDX for delete scope.
- Error model mapping table (HTTP → TF diagnostics) and retry/backoff rules.
