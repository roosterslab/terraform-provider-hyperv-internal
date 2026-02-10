# hypervapiv2 — MCP Agent Documentation Plan (IGP v0.3 aligned)

Purpose: Define a new, IGP‑aligned instruction graph for the hypervapiv2 provider so an automated agent can execute work end‑to‑end with minimal rework. This plan enumerates nodes (files), their `applyTo` scopes, roles, tags, dependencies, and copy‑ready frontmatter for each. After approval, we’ll materialize the nodes and (optionally) the bootstrap TL;DR/prompt files.

## Design principles

- IGP v0.3 compliance: every node has required frontmatter (`applyTo`, `role`, `tags`, `description`).
- Action‑first leaves: component nodes end with small checklists and golden commands.
- Plan‑time focus: data sources and validations de‑risk applies; strict mode and policy alignment are core.
- One source of truth: API mappings and proposed contracts live in dedicated nodes; demos serve as tests.

## Project realities and constraints (grounding)

- Target stack: Go 1.22, Terraform Plugin Framework, Windows host with Hyper‑V, PowerShell 5.1+ for demos.
- Server: `hyperv-mgmt-api-v2` (.NET 8), JEA/policy enforced; Negotiate auth in production.
- Known host caveat: Encryption Support toggle may return HTTP 400 (unsupported). Provider must warn, proceed to TPM, and reflect readback state.
- Security invariants: no policy bypass; explicit destructive intent; identity‑bound delete tokens; FileSystem provider only as needed; CL‑safe string projections server‑side.

## Instruction graph blueprint (no fixed filenames)

Use IGP v0.3 nodes with required frontmatter. Define nodes by role and scope, not by hardcoded filenames. Roles you’ll need:

- Bootstrap (global): loads TL;DR, merges matching nodes, prints graph + CI gates; `applyTo: "**/*"`.
- Domain/router: routes provider code, demos, and agent docs; narrow `applyTo` globs based on your repo layout.
- Feature hubs: group related scopes (provider internals, plan‑time data sources, resources) and link to component leaves; include `requires: [quality]`.
- Component leaves: implementable checklists for schema/auth, data sources (plan‑time), resources (unified VM and companions), demos/CI, troubleshooting.
- Quality: quick gates (lint, typecheck, tests), referenced by hubs and leaves.
- Recovery (optional): fallback guidance when CI/demos fail.

Frontmatter template (copy into each node and adjust applyTo/tags/children):

```md
---
applyTo: "<glob(s) for this scope>"
role: "bootstrap|domain-index|feature-index|component|quality|recovery"
tags: ["<k1>","<k2>"]
description: "<one‑line imperative summary>"
# optional
children: ["<relative-path-to-child-nodes>"]
requires: ["<relative-path-to-required-nodes>"]
gates: ["lint","typecheck","test"]
version: "0.3"
---
```

TL;DR content (repo‑wide, ≤12 lines):

```
Purpose: Terraform provider for Hyper‑V API v2. Stack: Go 1.22 + TF Plugin Framework + PowerShell demos.
Golden cmds: build go build ./... · test demos ./demo/*/Test.ps1 · lint golangci-lint run
CI must pass: main pipeline with build + two demos.
Rules: thin API mapping, no policy bypass, add tests with behavior changes.
```

## Prompts and MCP config (optional but recommended)

- Prompt: `.github/prompts/bootstrap.prompt.md` — reload context and print matched nodes.
- Chat mode: `.github/chatmodes/bootstrap.chatmode.md` — always run the bootstrap first.
- MCP reference: `mcp/mcp.json` — list allowed servers/tools (read‑only by default).

## File skeletons (copy‑paste previews — tailored examples)

1) Bootstrap steps (content)

```
Do first:
1) Read TL;DR + all matching instructions.
2) Print bullets: stack, golden cmds, CI gate.
3) List matched nodes (ordered) with children/requires.
4) If MCP configured, list tool names.
5) Ask for task if unclear; then proceed.
```

## Mental model and architecture (for agents and humans)

- Translator role: provider maps HCL ←→ API without duplicating server logic; authoritative state comes from server reads.
- Plan‑time vs apply‑time: prefer plan‑time data sources for suggestions and validation; apply‑time resources perform minimal, policy‑aligned changes.
- Idempotency: repeated applies converge; prefer deterministic layouts (controller/LUN) and stable identifiers.
- Policy‑first: validate names and paths up front; never bypass server policy or JEA constraints.
- Error taxonomy: 401 auth, 403 policy/JEA, 400 host limitation, 409 conflict/busy; surface clear diagnostics with endpoint/auth context.
- Delete semantics: destructive actions need explicit intent; only provider‑owned disks are in scope; `protect` overrides; identity‑bound tokens on server.

## Execution workflows (end‑to‑end)

1) Plan‑time data sources workflow
- Define schema for `disk_plan`, `path_validate`, `policy`, `whoami` with normalized outputs (path, reason, warnings, allowed/violations, groups).
- Implement fast reads; avoid per‑item fan‑out; add unit tests for edge cases (disallowed extensions, unknown roots).
- Wire diagnostics to escalate with `strict` and enforce with `enforce_policy_paths`.

2) Unified resource workflow
- Model `vm` with human sizes and disk scenarios (new/clone/attach), deterministic layout, and lifecycle flags.
- Sequence create/update/delete to respect power state and server constraints (e.g., Encryption Support 400 → warn and continue TPM).
- Read back authoritative state; add plan modifiers to avoid spurious diffs; ensure idempotency (apply twice → no diff).

3) Demos and CI workflow
- Create `demo/<scenario>/{main.tf,Run.ps1,Test.ps1,Destroy.ps1}`; Test.ps1 asserts TF outputs, an API probe, and idempotency (refresh‑only + plan exit code).
- Run two core demos in CI (simple new‑auto and plan‑validate‑apply) on a Windows runner with Hyper‑V.

4) API alignment workflow
- Map current server endpoints to provider needs; list gaps; draft proposed endpoints (plan‑disk, validate‑path, vm‑plan, whoami, host‑info, effective policy, images, name‑check) with request/response samples and error shapes.
- Land proposals into the API repo or keep as living spec until implemented; keep provider guarded behind feature flags as needed.

5) Troubleshooting and escalation workflow
- Document common failures with remediation (auth, policy, host limitations, conflicts) and how to increase diagnostics (provider logs, API logs).
- Provide go‑to checks: lint/build/unit first; then single demo locally; then CI.

## Acceptance criteria (green‑before‑done)

- Lint/Typecheck/Test PASS on provider; two demo scenarios PASS (Run/Test/Destroy) on a Windows host with Hyper‑V.
- Idempotency PASS (apply twice → no diff).
- All nodes above exist with valid IGP frontmatter.
- Proposed API contracts drafted and linked from agent docs.

Quality gates to run (examples):
- Lint: `golangci-lint run`
- Build: `go build ./...`
- Unit tests (selected): `go test ./internal/... -run Test`
- Demos: `pwsh -File .\demo\01-simple-vm-new-auto\Run.ps1`, then `Test.ps1`, then `Destroy.ps1`

## Authoring sequence

1) Create TL;DR + bootstrap + domain/feature hubs.
2) Add component leaves: provider schema, datasources, resources, demos, quality.
3) Add troubleshooting and recovery.
4) Author `agent/api-alignment-and-proposed-contracts.instructions.md`.
5) Add prompts/chatmode and (optionally) `mcp/mcp.json` reference.

## Demo scenarios to accompany docs

- 01-simple-vm-new-auto: new OS disk (auto path), Internal switch, stopped VM.
- 02-vm-with-security: Secure Boot on; TPM requested; strict=false behavior.
- 03-vm-disks-mix: new custom path, attach existing, clone auto, protect=true.
- 04-plan-validate-apply: use `disk_plan` + `path_validate` + preconditions.

Each with `{Run,Test,Destroy}.ps1` and clear output assertions.

## Open questions

- Definition of provider‑owned VHDX for delete scope.
- Minimal server support for capacity‑aware `disk_plan` without heavy JEA.
- Diagnostics categories for strict mode at plan‑time.

## Next step

On approval, generate the instruction nodes above (with frontmatter and checklists) under `.github/instructions/`, add TL;DR and prompt, and create the `agent/api-alignment-and-proposed-contracts.instructions.md`. Demos will be stubbed under `demo/` with `main.tf` and PowerShell scripts.

---

## Better, hypervapiv2‑specific examples

Below are richer, repository‑aware examples you can drop into the instruction nodes’ bodies. These supersede the generic IGP previews.

### A) Plan‑time data sources

Checklist additions:
- For `disk_plan` Read, return: `path`, `reason`, `matched_root`, `normalized_path`, `free_gb_after`, `warnings[]`.
- For `path_validate`, return: `allowed`, `violations[]`, `message`; fail plan when `enforce_policy_paths = true`.
- Unit test: given a disallowed extension, `allowed=false` and `violations` contains `extension`.

Golden commands:
- Build: `go build ./...`
- Unit: `go test ./internal/datasources/... -run TestPlanTime`

Repo essentials (to reference in node):
- Code: `internal/datasources/`
- Tests: `internal/datasources/*_test.go`

### B) Unified VM resource

Checklist additions:
- Parse human sizes (e.g., "8GB" → 8192 MB) with validators; reject unknown units.
- Implement disk scenarios (new/clone/attach) with deterministic `controller`+`lun` assignment; error on conflicts.
- Delete scope: only provider‑owned disks are eligible when `lifecycle.delete_disks=true`; `disk.protect=true` overrides.
- Host caveat: if Encryption Support toggle returns 400, emit warning and continue TPM; state reflects read‑back.

Golden commands:
- Lint: `golangci-lint run`
- Build: `go build ./...`
- Demo test: `pwsh -File .\demo\01-simple-vm-new-auto\Test.ps1`

Repo essentials:
- Code: `internal/resources/`
- VM resource entry: `internal/resources/vm` (to be created)

### C) Demos and CI

Checklist additions:
- `Run.ps1` must print provider path override and endpoint; `Destroy.ps1` tolerates missing resources.
- `Test.ps1` validates: Terraform outputs, one API probe (GET /v2/vms), and idempotency (apply twice → no diff).
- CI job runs at least `01-simple-vm-new-auto` and `04-plan-validate-apply`.

PowerShell snippet (Test.ps1 core):
```
$ErrorActionPreference = 'Stop'
terraform output -json | ConvertFrom-Json | Out-Null
terraform apply -refresh-only -auto-approve | Out-String | Write-Host
$plan = terraform plan -detailed-exitcode
if ($LASTEXITCODE -eq 2) { throw 'Non‑idempotent after apply' }
```

Repo essentials:
- Demos root: `demo/`
- Provider dev override (tbd for v2): `dev.tfrc` or inline TF CLI config in `Run.ps1`

### D) Troubleshooting

Quick table:
- 401 Unauthorized → Check `auth` block; Negotiate requires Windows context.
- 403 Forbidden → Policy/JEA denial; update policy pack + JEA VisibleCmdlets.
- 400 Not supported (Encryption Support) → Warning, proceed to TPM; consider disabling `encrypt` on this host.
- 409 Conflict/busy → Adjust `stop_method`/timeouts; retry with backoff.

Repo essentials:
- API logs: `hyperv-mgmt-api-v2/logs/` (when running locally)
- Provider logs: enable TF_LOG or internal diagnostics switch

### E) API alignment and proposed contracts

For each endpoint, include request/response samples and error shapes; e.g., `/policy/plan-disk`:

Request:
```
POST /api/v2/policy/plan-disk
{ "vm_name": "app01", "operation": "create", "purpose": "os", "size_gb": 50, "prefer_root": "D:/HyperV/VMs" }
```

Response 200:
```
{ "path": "D:/HyperV/VMs/app01/os.vhdx", "reason": "best root by free space", "matched_root": "D:/HyperV/VMs", "free_gb_after": 120, "warnings": [] }
```

Response 403:
```
{ "code": "forbidden", "message": "Path violates policy root/extension" }
```

Also include stubs for:
- `/identity/whoami` (GET)
- `/host/info` (GET)
- `/policy/effective` (GET)
- `/policy/vm-plan` (POST)
- `/names/validate` (POST)

### F) Instruction naming guidelines (optional)

- Prefer numeric prefixes to influence read order when scopes overlap.
- Keep names descriptive of scope/role; avoid hard‑coding repository‑specific paths in titles.

### G) Gates & signals to print in Bootstrap

- Stack: Go 1.22, TF Plugin Framework, PowerShell demos.
- Golden commands: `go build ./...`; `golangci-lint run`; `./demo/*/Run.ps1` and `Test.ps1`.
- CI gate: your main pipeline must cover build + at least two demos.

---

## Phased backlog (execution plan tied to scan report)

Phase 1 — Foundations
- Add TL;DR, bootstrap, routers; implement `disk_plan`, `path_validate`, `policy`, `whoami` data sources (fast returns, reasons/warnings).
- Scaffold demos: `01-simple-vm-new-auto`, `04-plan-validate-apply` (minimal success path).

Phase 2 — Unified VM
- Implement `hypervapiv2_vm` with new/attach flows, human sizes, deterministic layout, limited lifecycle delete scope.
- Add `30-demos-and-ci` to run both scenarios in CI; add troubleshooting doc.

Phase 3 — Expansion
- Add `vm_plan`, `host_info`, `name_check`, `images`, clone flows.
- Document proposed endpoints fully and sync with API repo.

Exit criteria
- Plans converge; two demos pass locally and in CI; proposed API docs reviewed/accepted or stubbed on server.
