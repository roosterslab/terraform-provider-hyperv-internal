---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "SemVer guidance, dev builds, packaging, and changelog expectations for the provider."
---

# Versioning and Releases

## Versioning

- SemVer: bump MINOR for new data sources/attributes; PATCH for fixes; MAJOR for breaking changes (avoid).
- Keep changes additive when possible; deprecate before removing.

## Dev builds

- Build to `bin/` and use a dev override in demos (similar to v1 `dev.tfrc`).
- `Run.ps1` should wire the local binary to Terraform CLI.

## Packaging and publish

- Align with Terraform Registry naming once stable (e.g., `vinitsiriya/hypervapiv2`).
- Ship release notes with highlights, upgrade notes, and links to demos/instructions.

## Changelog

- For every release, document:
  - Added/Changed/Fixed
  - Behavior changes (plan modifiers, defaults)
  - Any new or changed API dependencies (link to server PRs)
