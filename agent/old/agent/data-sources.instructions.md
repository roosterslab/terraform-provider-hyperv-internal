---
applyTo: "terraform-provider-hypervapi-v2/**"
description: "Implement plan-time data sources with normalized outputs and actionable reasons/warnings."
---

# Data Sources — Plan-time helpers

Implement these first to make plans predictable and policy-clean. Map 1:1 to API endpoints.

## 1) `hypervapiv2_disk_plan`

Input:
- `vm_name`, `operation` (create|clone|attach), `purpose` (os|data|ephemeral)
- For create: `size_gb`; for clone: `clone_from`
- Hints: `prefer_root`, `min_free_gb`, `co_locate_with`, `ext`

Outputs:
- `path`, `reason`, `matched_root`, `normalized_path`, `writable`, `free_gb_after`, `host`, `warnings[]`

## 2) `hypervapiv2_path_validate`

Input: `path`, `operation`, `ext`
Output: `allowed` (bool), `matched_root`, `normalized_path`, `message`, `violations[]`

Behavior:
- When provider `enforce_policy_paths=true`, fail plan if `allowed=false` (via precondition or plan modifier logic).

## 3) `hypervapiv2_vm_plan`

Input: `vm_name`, `cpu`, `memory`, `disks=[...]`, `network{}`
Output: `resolved{ cpu, memory_mb, disks[], network[] }`, `warnings[]`, `errors[]`

## 4) `hypervapiv2_policy`

Output: `roots[]`, `extensions[]`, `quotas{}`, `name_patterns{}`, `deny_reasons{}`

## 5) `hypervapiv2_whoami`

Output: `user`, `domain`, `sid`, `groups[]`

## 6) `hypervapiv2_host_info`

Output: `tpm_supported`, `encryption_toggle_supported`, `secure_boot_templates[]`, `max_vcpu`, `storage_roots[]`, `clustered`, `host`

## 7) `hypervapiv2_vm_shape`

Input: `name`; Output: `cpu`, `memory`, `disk_default?`

## 8) `hypervapiv2_images`

Filters: `filter_name`, `under_root`, `with_tag`
Output: `images[] { path, size_gb, created, tags[], notes }`

## 9) `hypervapiv2_name_check`

Input: `kind` (vm|switch), `name`
Output: `allowed`, `message`, `pattern`, `suggestions[]`

## Tests and edges

- Disallowed extensions → `path_validate.allowed=false` with `violations` containing `extension`.
- Low free space → `disk_plan.warnings` present; with `strict=true`, plans must fail.
- Unknown shape name → data source returns error; document list of available shapes if API exposes it.
