---
applyTo: "terraform-provider-hypervapi-v2/**"
role: "quality"
tags: ["quality","lint","build","test"]
description: "Quality gates: lint, build, demo tests; keep changes minimal and idempotent."
gates: ["lint","typecheck","test"]
version: "0.3"
---

# Quality Gates

Run regularly
- Lint: `golangci-lint run` (if configured)
- Build: `go build ./...`
- Unit tests (if present): `go test ./internal/... -run Test`
- Demos: run representative `Run/Test/Destroy` flows.

Expectations
- Idempotency: second apply yields `No changes` where appropriate.
- Diagnostics: actionable errors; never secrets; include endpoint/auth method.
- Scope control: keep diffs focused; update docs and demos alongside code.

