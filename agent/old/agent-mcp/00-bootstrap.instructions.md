---
applyTo: "**/*"
role: "bootstrap"
tags: ["graph","bootstrap","global"]
description: "Global bootstrap for agents: load TL;DR, merge matching nodes, print graph + CI gates, then proceed."
gates: ["lint","typecheck","test"]
version: "0.3"
---

# Bootstrap — Session Start

Do first
- Read repo TL;DR and all matching instruction nodes.
- Print bullets: stack, golden commands, CI gates.
- List matched nodes (ordered) with children/requires.
- If MCP is configured, list tool names (no calls).
- Ask for task if unclear; then proceed.

Quick healthcheck (non-blocking)
- Tools: `go version`, `terraform version`, `pwsh -v`.
- API: ensure server is running (default `http://localhost:5006`). If not, run `terraform-provider-hypervapi-v2/scripts/Run-ApiForExample.ps1`.
- Provider dev override: confirm `dev.tfrc` usage in demo scripts and that `terraform-provider-hypervapi-v2/bin/terraform-provider-hypervapiv2.exe` exists after build.

Fast paths
- Run a focused demo suite (disk/power/plan) via `agent-mcp/12-provider-demos.instructions.md`.
- Patch provider schema/logic with `agent-mcp/11-provider-dev.instructions.md` and update docs per `agent-mcp/13-provider-docs.instructions.md`.

Green matrix (quick confidence)
- Disk unified (new/auto): `terraform-provider-hypervapi-v2/demo/13-disk-unified-new-auto/Test.ps1`.
- Delete semantics: `terraform-provider-hypervapi-v2/demo/14-delete-semantics/Test.ps1`.
- Protect override: `terraform-provider-hypervapi-v2/demo/15-protect-vs-delete/Test.ps1`.
- Power controls: `terraform-provider-hypervapi-v2/demo/10-power-stop-timeouts/Test.ps1`.

