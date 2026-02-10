applyTo: "terraform-provider-hypervapi-v2/**"
description: "Overview and operating rules for hypervapiv2 provider; quick links, guardrails, and success criteria."
---

# hypervapiv2 — Overview and Operating Rules (MCP‑style)

Purpose: a safe, policy‑aware Terraform provider for the Hyper‑V Management API v2 that manages VM lifecycle with optional disk cleanup, aligned with JEA/policy and production auth.

## Repository essentials

- Provider root: `terraform-provider-hypervapi-v2/` (Go 1.22, Terraform Plugin Framework)
- Design source of truth: `terraform-provider-hypervapi-v2/plan.md`
- Context scan baseline: `terraform-provider-hypervapi-v2/SCAN-REPORT.md`
- Upstream API: `hyperv-mgmt-api-v2/` (.NET 8, JEA/Policy, Negotiate)
- v1 provider (reference patterns): `terraform-provider-hypervapi/agents/*`

## Capabilities

- Plan‑time helpers: `disk_plan`, `path_validate`, `vm_plan`, `policy`, `whoami`, `host_info`, `vm_shape`, `images`, `name_check`.
- Unified resource: `hypervapiv2_vm` with natural sizes, all disk scenarios (new/clone/attach), deterministic controller/LUN, `protect`, lifecycle delete scope.
- Network switch resource: `hypervapiv2_network` (create/delete) — phased.
- Auth methods: none, bearer, negotiate; proxy, timeout, and CA options.

## Non‑negotiable rules

1) No policy bypass. Provider surfaces API denials; it never weakens JEA/policy.
2) Destructive actions require explicit intent. Two‑step delete on server; `delete_disks` limited to provider‑owned VHDX; `disk.protect=true` overrides.
3) Idempotency by design. Repeat applies converge; deterministic controller/LUN; stable state sourced from server readbacks.
4) Thin mapping. Translate HCL ⇄ API; do not duplicate server business logic.
5) Diagnostics. Include endpoint/auth method (never secrets); preserve API error details.

## Success criteria

- Build/Lint/Typecheck/Test: PASS.
- Demos: `demo/<scenario>/{Run,Test,Destroy}.ps1` succeed on a Windows host with Hyper‑V.
- Idempotency: apply twice → no diff; destructive intent honored only when explicitly requested.
- Docs: this instruction graph exists with valid frontmatter; proposed API contracts documented and linked.

## Quick links (what/when)

- Mental model: how the provider thinks — `agent/mental-model-and-architecture.instructions.md` (read first).
- Developer workflow: add features end‑to‑end — `agent/developer-perspective-and-feature-workflow.instructions.md`.
- API alignment & proposals: contracts and gaps — `agent/api-alignment-and-proposed-contracts.instructions.md`.
- Schema & modeling: types, defaults, plan modifiers — `agent/provider-schema-and-modeling.instructions.md`.
- Auth & endpoints: provider config and connectivity — `agent/authentication-and-endpoints.instructions.md`.
- Data sources: plan‑time helpers — `agent/data-sources.instructions.md`.
- VM resource: lifecycle, disks, security — `agent/resource-vm.instructions.md`.
- Testing & sanity: demos as tests — `agent/testing-and-sanity.instructions.md`.
- Build & run: dev cycle and golden commands — `agent/building-and-running.instructions.md`.
- Troubleshooting: error taxonomy and remedies — `agent/troubleshooting.instructions.md`.
- Roadmap & rules: phased delivery and guardrails — `agent/roadmap-and-rules.instructions.md`.
- Versioning & releases: SemVer and packaging — `agent/versioning-and-releases.instructions.md`.

## Ownership boundaries

- API server workflows, JEA exposure, and policy authoring live in `hyperv-mgmt-api-v2/agent/*.instructions.md`. Link to those docs; do not restate them here.
- This provider routes to the API docs for server‑side changes and keeps focus on thin mapping, plan‑time UX, and Terraform semantics.

## Gates (run regularly)

- Lint: golangci‑lint run
- Build: go build ./...
- Unit tests: go test ./internal/... -run Test
- Demos: pwsh -File .\demo\01-simple-vm-new-auto\Run.ps1; Test.ps1; Destroy.ps1

Keep these succinct in repo TL;DR when added.
