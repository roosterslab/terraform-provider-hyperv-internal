# Who Am I Examples (hypervapiv2)

This folder contains minimal examples to exercise authentication paths.

Examples:
- `current-user-sspi/` — Uses SSPI Negotiate with the current Windows user.
- `explicit-impersonation/` — Uses username/password on Windows via impersonation + SSPI Negotiate.
- `raw-ntlm-fallback/` — Optional path using raw NTLM (enable with env var); server must accept it.

All examples output identity fields from `data "hypervapiv2_whoami"`.
