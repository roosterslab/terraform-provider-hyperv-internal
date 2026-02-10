---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Build the provider, run demos locally with a dev override, and keep golden commands handy."
---

# Building and Running

## Build

- Use Go 1.22
- Build all: `go build ./...`

## Lint/Typecheck

- Lint: `golangci-lint run`
- Unit tests: `go test ./internal/... -run Test`

## Demos (local)

- `pwsh -File .\demo\01-simple-vm-new-auto\Run.ps1`
- `pwsh -File .\demo\01-simple-vm-new-auto\Test.ps1`
- `pwsh -File .\demo\01-simple-vm-new-auto\Destroy.ps1`

Notes:
- `Run.ps1` should configure a dev override akin to v1 (`dev.tfrc`) pointing to `bin/terraform-provider-hypervapiv2.exe`.
- Ensure Hyper‑V role is enabled and the API server is reachable with your chosen `auth` method.

## CI (target)

- Main pipeline must build + run at least two demos end‑to‑end.
