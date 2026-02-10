# Authentication: Negotiate (Windows Integrated) — Comparison and Plan

This document compares how Negotiate/Windows Integrated authentication is implemented in:
- C:\Users\ws-user\Documents\project-2\terraform-provider-hypervapi ("v1")
- C:\Users\ws-user\Documents\projects\hyper-v-experiments\terraform-provider-hypervapi-v2 ("v2")

It highlights what v2 already supports, what is missing compared to v1, and a concrete update plan for v2.

## Summary

- v1 supports:
  - SSPI Negotiate with current user.
  - Non-Windows NTLM negotiator fallback.
  - Explicit impersonation using username/password via LogonUserW + ImpersonateLoggedOnUser, then SSPI.
- v2 supports:
  - SSPI Negotiate with current user (parity with v1).
  - Explicit username/password via NTLM transport (no impersonation) — different behavior from v1.
  - Non-Windows implementation not validated, and no impersonation path exists.

Result: v2 lacks the explicit impersonation capability that v1 has; and the NTLM explicit credentials path may not be compatible with your API’s current WWW-Authenticate flows.

---

## What v1 Does (project-2/terraform-provider-hypervapi)

Files of interest:
- `internal/provider/negotiate_windows.go`: SSPI-based Negotiate for current Windows user
  - Builds SPN `HTTP/<hostname>`; maps `localhost` to machine name.
  - Multi-leg SPNEGO handshake; caches request body; retries with `Authorization: Negotiate <token>`.
- `internal/provider/negotiate_other.go`: Non-Windows fallback to `github.com/Azure/go-ntlmssp` negotiator.
- `internal/provider/negotiate_impersonate_windows.go`: Explicit impersonation path
  - `wrapNegotiateTransportWithImpersonation(base, username, password)`
  - Uses `LogonUserW` (INTERACTIVE, fallback NEW_CREDENTIALS) to obtain token, `ImpersonateLoggedOnUser`, then runs the SSPI Negotiate transport under impersonation.
  - Ensures impersonation is scoped to a single OS thread per request.
- `internal/provider/negotiate_impersonate_other.go`: Non-Windows stub; falls back to non-impersonating transport.

Characteristics:
- When username/password are provided, v1 can impersonate that identity and still do SSPI/Negotiate, aligning with servers that expect `WWW-Authenticate: Negotiate`.
- No GUI prompts; credentials supplied in HCL/vars.

---

## What v2 Does Today (hypervapi-v2)

Files of interest:
- `internal/client/negotiate_windows.go`: SSPI-based Negotiate for current Windows user — same approach as v1.
- `internal/client/client.go`: explicit credentials branch
  - If `auth.method == "negotiate"` and `username` is set, v2 builds an `ntlm.NtlmTransport` from `github.com/vadimi/go-http-ntlm/v2` with Domain/User/Password.
  - Else, falls back to SSPI with current user via `wrapNegotiateTransport`.

Observed behavior during testing:
- SSPI (no username/password): works against API on port 5000.
- Explicit credentials with NTLM transport: request fails with `wrong WWW-Authenticate header` from the server’s Negotiate flow, suggesting a mismatch between server challenge (Negotiate/SPNEGO) and the client path (pure NTLM).

Missing in v2 vs v1:
1. No explicit impersonation path equivalent to `wrapNegotiateTransportWithImpersonation`.
2. Non-Windows behavior not documented/verified for the explicit credential case.
3. Provider docs/examples for explicit creds currently assume NTLM will work; not true for servers that only offer `Negotiate`.

---

## Why This Matters

Your API presents `WWW-Authenticate: Negotiate` and expects SPNEGO (Kerberos or NTLM inside SPNEGO). v1 can satisfy this even with alternate credentials by impersonating and then using SSPI Negotiate. v2, when given username/password, attempts raw NTLM outside of SPNEGO, which can be rejected by the server.

---

## Update Plan for v2

### Goal
Achieve parity with v1 for Windows Integrated authentication:
- Keep SSPI Negotiate for current user.
- Add explicit impersonation support so that provided username/password are used by SSPI/Negotiate, not raw NTLM.
- Maintain non-Windows fallback behavior similar to v1.

### Work Items (Incremental)

1) Add impersonation transport (Windows only)
- Introduce `internal/client/negotiate_impersonate_windows.go` mirroring v1’s `wrapNegotiateTransportWithImpersonation`:
  - Use `LogonUserW` (INTERACTIVE, fallback NEW_CREDENTIALS), `ImpersonateLoggedOnUser`, `RevertToSelf`.
  - Scope impersonation to the request (lock OS thread in RoundTrip).
  - Under impersonation, reuse existing `wrapNegotiateTransport` to perform SSPI/Negotiate.
- Wire it in `internal/client/client.go`:
  - If `auth.method == "negotiate"` and `username != ""`, prefer the impersonation transport instead of pure NTLM.
  - Keep NTLM transport as a controlled fallback behind a feature flag (e.g., `HYPERVAPI_V2_ALLOW_RAW_NTLM=1`).

2) Add non-Windows stub
- Add `internal/client/negotiate_impersonate_other.go` that simply returns `wrapNegotiateTransport(tr)` and documents that explicit impersonation is not supported off Windows.

3) Logging and diagnostics
- In `client.go/do`, include `Www-Authenticate` header in debug logs (already present) and add a concise diagnostic when the negotiate handshake cannot proceed due to missing/unsupported challenges.

4) Examples and docs
- Add an example `examples/auth-prod-impersonate` analogous to v1, using optional `username`/`password` variables.
- Update `docs` with a matrix:
  - Current user (SSPI Negotiate) — supported.
  - Explicit user (Windows impersonation + SSPI Negotiate) — added.
  - Explicit user via raw NTLM — optional/flagged, server-dependent.
- Note security: passwords are sensitive; recommend secret stores/env vars.

5) Testing
- Manual test against API presenting `WWW-Authenticate: Negotiate`:
  - No creds → should succeed (current user).
  - Explicit domain user in `HG_HV_Users` → should succeed with impersonation.
  - Explicit user lacking rights → should 401/403 as appropriate.
- Negative: flip the env flag to force raw NTLM and confirm current 401/`wrong WWW-Authenticate` reproduces.

6) Backward compatibility
- Keep current behavior for users not providing `username`.
- Provide clear error if `username` is present but platform is non-Windows.

### Effort & Risk
- Scope: ~200–300 LOC (Windows impersonation transport + wire-up + docs + example).
- Risks: impersonation requires careful thread-affinity and reliable `RevertToSelf`; mitigation via well-scoped RoundTrip and defers.

---

## How v1 Implements It (Reference)

- Windows SSPI for Negotiate (`negotiate_windows.go`).
- Optional impersonation layer to run SSPI under alternate credentials (`negotiate_impersonate_windows.go`).
- NTLM negotiator on non-Windows (`negotiate_other.go`).
- Non-Windows impersonation stub (`negotiate_impersonate_other.go`).

This approach ensures servers that only advertise `Negotiate` (SPNEGO) still authenticate successfully with explicit credentials on Windows.

---

## What v2 Has/Misses (Checklist)

- [x] SSPI Negotiate (current user) — `internal/client/negotiate_windows.go`
- [x] Debug logging of `Www-Authenticate` — `client.go/do`
- [ ] Explicit impersonation (username/password) — MISSING
- [ ] Non-Windows behavior documented for explicit creds — MISSING
- [ ] Example covering explicit creds with impersonation — MISSING
- [ ] Optional raw NTLM toggle for servers that accept it — MISSING

---

## Next Steps

- Implement items (1)-(2), then publish the example and docs (items 4).
- Validate against your Production API at `http://localhost:5000` (Negotiate).
- If desired, add a provider setting (or env var) to choose between impersonation vs raw NTLM for explicit credentials.
