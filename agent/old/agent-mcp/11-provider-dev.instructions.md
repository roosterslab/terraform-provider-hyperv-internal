---
applyTo: "terraform-provider-hypervapi-v2/**"
role: "component"
tags: ["dev","go","terraform","provider"]
description: "Developer workflow for provider code: build, wire schema, map HCL→API, run targeted demos."
requires: ["./50-quality.instructions.md"]
version: "0.3"
---

# Provider Dev — Workflow

Golden commands
- Build: `pushd terraform-provider-hypervapi-v2; go build ./...; popd`
- Lint (if configured): `golangci-lint run`

Steps
1) Align schema with plan.md; keep mapping thin (HCL→client→API).
2) Do not add local policy gates; rely on API responses.
3) Update demos alongside code; prefer minimal surface changes.
4) Validate with smallest relevant demo Test.ps1.
5) Update docs in `terraform-provider-hypervapi-v2/docs/*`.

Diagnostics
- Include endpoint/auth method in provider warnings; never secrets.
- Preserve API error bodies (truncated when large) for clarity.

