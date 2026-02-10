# Auth Update Plan (hypervapi-v2)

This plan brings `terraform-provider-hypervapi-v2` to parity with `terraform-provider-hypervapi` for Windows Integrated authentication (Negotiate) and explicit-credential usage.

## Goals
- Support SSPI Negotiate for current user (already works).
- Add explicit credential support via Windows impersonation + SSPI (not raw NTLM) so servers that advertise only `WWW-Authenticate: Negotiate` succeed.
- Keep optional raw NTLM as a guarded fallback for environments where the API allows it.

## Tasks

1. Windows Impersonation Transport
- Add `internal/client/negotiate_impersonate_windows.go` implementing:
  - `wrapNegotiateTransportWithImpersonation(base *http.Transport, username, password string) http.RoundTripper`.
  - Use `LogonUserW` (INTERACTIVE, fallback NEW_CREDENTIALS), `ImpersonateLoggedOnUser`, `RevertToSelf`.
  - Lock OS thread during RoundTrip; call existing `wrapNegotiateTransport` under impersonation.

2. Non-Windows Stub
- Add `internal/client/negotiate_impersonate_other.go`:
  - Return `wrapNegotiateTransport(base)`; document that explicit impersonation is unsupported off Windows.

3. Wire-up in `internal/client/client.go`
- In `New(cfg)`, when `cfg.Auth.Method == "negotiate"` and `cfg.Auth.Username != ""`:
  - Prefer `wrapNegotiateTransportWithImpersonation(tr, cfg.Auth.Username, cfg.Auth.Password)`.
  - Gate the current raw NTLM path behind env var `HYPERVAPI_V2_ALLOW_RAW_NTLM=1` or a hidden config, for opt-in only.

4. Diagnostics
- Improve error when server does not present an acceptable `Www-Authenticate` header; log it at debug and surface a concise user error.

5. Examples
- Add `examples/auth-prod-impersonate` in v2 mirroring v1: optional `username`/`password` vars; default empty to use current user.

6. Documentation
- Add docs (done in this PR):
  - `docs/Auth-Negotiate-Comparison.md`: what v1 does vs v2, gaps, rationale.
  - Update `docs/README.md` to link to the new page and example.

## Acceptance Tests (Manual)
- API at `http://localhost:5000` (Negotiate):
  - No creds: `data.hypervapiv2_whoami` returns current user.
  - Explicit domain user in `HG_HV_Users`: whoami returns that user.
  - Explicit user with wrong password: auth fails cleanly.
  - Non-Windows runner: explicit creds ignored (documented), current user path behaves as before.

## Risks & Mitigations
- Thread-affinity for impersonation: mitigated by `runtime.LockOSThread()` and defers.
- Token leakage: ensure `RevertToSelf()` in all branches; use `defer` robustly.
- Behavior drift: default path unchanged for users who do not supply `username`.

## Rollout
- Land code + example; ship pre-release.
- Enable raw NTLM fallback only upon explicit request via env.
- Gather feedback; consider promoting the toggle to a provider setting if needed.
