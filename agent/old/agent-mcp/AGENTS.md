# Agents Guide for hypervapiv2

Scope
- Agent entrypoint for this repo (Copilot Chat, CLI agents, others). Keep runs safe, fast, and aligned with IGP.

Key Truths
- Source of truth: `terraform-provider-hypervapi-v2/plan.md`.
- Server owns policy: identity/RBAC/path rules enforced by API. Provider must not bypass or duplicate.
- Thin mapping: map HCL → API; avoid reimplementing server logic in the provider.
- Demos are tests: Each `demo/<scenario>` ships `Run.ps1 / Test.ps1 / Destroy.ps1`.

Bootstrap Checklist (2 minutes)
- Read instruction nodes (use `agent-mcp/00-bootstrap.instructions.md`).
- Verify tools: `go version`, `terraform version`, `pwsh -v`.
- Start API if needed: `terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1` (default `http://localhost:5006`).
- Build provider: `pushd terraform-provider-hypervapi-v2; go build ./...; popd`.
- Confirm dev override: demos write `dev.tfrc` to point Terraform to `terraform-provider-hypervapi-v2/bin`.

Golden Commands
- Build: `pushd terraform-provider-hypervapi-v2; go build ./...; popd`
- Lint (if configured): `golangci-lint run`
- Run demo: `pwsh -File terraform-provider-hypervapi-v2/demo/01-simple-vm-new-auto/Run.ps1`
- Test demo: `pwsh -File terraform-provider-hypervapi-v2/demo/01-simple-vm-new-auto/Test.ps1`

Fast Paths
- Green matrix (quick confidence):
  - Disk unified: `demo/13-disk-unified-new-auto/Test.ps1`
  - Delete semantics: `demo/14-delete-semantics/Test.ps1`
  - Protect override: `demo/15-protect-vs-delete/Test.ps1`
  - Power controls: `demo/10-power-stop-timeouts/Test.ps1`
- Provider dev: `agent-mcp/11-provider-dev.instructions.md`
- Demos runbook: `agent-mcp/12-provider-demos.instructions.md`
- Docs workflow: `agent-mcp/13-provider-docs.instructions.md`

Operating Rules
- Idempotency: Multiple applies converge; avoid unintended replacements.
- Destructive intent: Delete is two-step on server. Honor `vm_lifecycle.delete_disks`; never delete `disk.protect=true`.
- Diagnostics: Surface server messages; never log secrets. Include endpoint/auth method in warnings when helpful.
- Policy/auth: Do not perform local enforcement; rely on API responses.

Failure Triage
- Transport: check endpoint reachability, auth method, and timeouts.
- Policy denials: treat 4xx as user feedback; copy error body (trim if large).
- Transient 500/timeout on create: attempt adopt-by-name; warn and continue.
- Idempotency drift: prefer read/refresh; avoid unnecessary replaces.

Success Criteria
- Build/test/demos pass locally.
- Docs updated alongside code.
- Clear warnings when adopting state after transient server errors.

