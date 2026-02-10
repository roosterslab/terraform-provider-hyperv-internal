# hypervapiv2 — API proposals (pending)

This file captures the missing API contracts needed to realize `plan.md` for the v2 provider. These are additive to the Hyper‑V Management API v2 and should be implemented server‑side with JEA/policy enforcement.

## New/expanded endpoints

- POST /policy/plan-disk
	- Request: { vm_name, operation: create|clone|attach, purpose, size_gb?, clone_from?, prefer_root?, min_free_gb?, co_locate_with?, ext? }
	- Response: { path, reason, matched_root, normalized_path, writable, free_gb_after, host, warnings[] }
- POST /policy/validate-path
	- Request: { path, operation: create|clone|attach, ext }
	- Response: { allowed, matched_root, normalized_path, message, violations[] }
- POST /policy/vm-plan
	- Request: { vm_name, cpu, memory, disks[], network? }
	- Response: { resolved{ cpu, memory_mb, disks[]{ name, path, mode, controller, lun, reason, warnings[] }, network[]{ switch, mac_suggested } }, warnings[], errors[] }
- GET /identity/whoami
	- Response: { user, domain, sid, groups[] }
- GET /host/info
	- Response: { tpm_supported, encryption_toggle_supported, secure_boot_templates[], max_vcpu, storage_roots[]{ root, total_gb, free_gb }, clustered, host }
- GET /policy/effective
	- Response: { roots[], extensions[], quotas{ root:{ max_gb, used_gb, free_gb } }, name_patterns{ vm, switch }, deny_reasons{} }
- GET /images
	- Query params optional: filter_name, under_root, with_tag
	- Response: { images[]{ path, size_gb, created, tags[], notes } }
- POST /names/validate
	- Request: { kind: vm|switch, name }
	- Response: { allowed, pattern, suggestions[], message }

## Notes

- All endpoints must return detailed errors preserving policy denials and RBAC context. Do not bypass policy; return 403 when violated.
- Prefer lightweight JEA interactions; rely on policy service + filesystem checks outside JEA where safe.
- Align OpenAPI at `hyperv-mgmt-api-v2/api-spec/openapi.yaml` after implementation.

