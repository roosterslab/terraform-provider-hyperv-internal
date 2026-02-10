---
applyTo: "terraform-provider-hypervapi-v2/docs/**"
role: "component"
tags: ["docs","hcl","reference"]
description: "Docs workflow: update HCL reference, VM resource, and data sources with changes."
version: "0.3"
---

# Docs — hypervapiv2

Primary docs
- `docs/README.md` — entrypoint with quick start.
- `docs/HCL-Reference.md` — provider, resources, data sources.
- `docs/Resources-VM.md` — VM resource details (unified disks, lifecycle, power).
- `docs/Data-Sources.md` — `disk_plan`, `path_validate`, `policy`, `whoami`.

Rules
- Keep docs aligned with implemented features (not aspirational).
- Call out limitations (e.g., clone/attach apply pending) and server-owned policy.
- Add links to demos that exercise new features.

