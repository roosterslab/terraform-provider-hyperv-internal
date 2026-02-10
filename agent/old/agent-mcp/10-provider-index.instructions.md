---
applyTo: "terraform-provider-hypervapi-v2/**"
role: "domain-index"
tags: ["provider","terraform","go","hyper-v"]
description: "Index for hypervapiv2 provider work: links dev, demos, docs, and quality nodes."
children: [
  "./11-provider-dev.instructions.md",
  "./12-provider-demos.instructions.md",
  "./13-provider-docs.instructions.md",
  "./50-quality.instructions.md"
]
version: "0.3"
---

# Provider Index — hypervapiv2

Truths
- Source of truth: terraform-provider-hypervapi-v2/plan.md
- Server enforces policy and identity; provider must not locally enforce.
- Thin mapping: map HCL → API; do not duplicate server logic.

Navigate using children.

