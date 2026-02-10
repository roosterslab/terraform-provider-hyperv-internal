applyTo: "terraform-provider-hypervapi-v2/**"
description: "Define translator role, plan/apply split, idempotency, delete semantics, and error taxonomy for hypervapiv2."
---

# Mental Model and Architecture

## Objectives

- Set the provider’s architecture and reasoning model so features are implemented predictably and safely.
- Make idempotency, policy alignment, and diagnostics first‑class.

## Translator role (thin mapping)

- Provider translates HCL ⇄ API JSON. Business rules stay on the server.
- Authoritative state always comes from a server re‑read after apply.

## Plan‑time vs apply‑time

- Prefer plan‑time data sources to reduce surprises: suggest paths, validate names/paths, pre‑solve VM shapes.
- Apply‑time resources execute minimal, policy‑compliant steps and then re‑read.

## Idempotency and determinism

- Normalize human sizes (e.g., "8GB" → 8192 MB). Use plan modifiers to avoid needless diffs.
- Deterministic disk layout: explicit `controller` + `lun` accepted; auto‑assignment must be stable per disk name.
- Apply twice with no source change → no diff (verify in demos’ Test.ps1).

## Safety rails

- `enforce_policy_paths`: plan fails if explicit disk paths violate policy.
- `strict`: warnings (e.g., low free space) escalate to plan errors.
- `disk.protect`: never delete protected disks even when `delete_disks=true`.

## Delete semantics (scope and intent)

- Deletion requires explicit user intent. Server issues identity‑bound delete tokens.
- Only provider‑owned VHDX may be deleted when `delete_disks=true`; `source_path` attachments are out of scope.

## Error taxonomy (surface clearly)

- 401 Unauthorized → Auth misconfiguration.
- 403 Forbidden → Policy/JEA denial; include reason and endpoint.
- 400 Bad Request → Host limitation (e.g., Encryption Support unsupported). Warn, degrade gracefully, reflect readback.
- 409 Conflict/Busy → Power state or timing; tune `stop_method`/timeouts; retry with bounded backoff.

## Ownership boundaries

- Server policy, JEA exposure, and RBAC rules are owned by the API repo. See `hyperv-mgmt-api-v2/agent/overview.instructions.md` and linked docs.
- This provider only validates at plan and maps operations; it does not grant new capabilities.

## Checks

- Plan‑time DS for paths and VM plans exist and return reasons/warnings.
- Apply reads back authoritative state and converges.
- Delete scope limited and protected by `protect`.
