//go:build !windows

package client

import "net/http"

// Non-Windows stub: explicit impersonation is not supported. We fall back to the
// regular negotiate transport which will use whatever credentials are available
// (typically SSPI-equivalent or NTLM negotiator as supported on platform).
func wrapNegotiateTransportWithImpersonation(base *http.Transport, username, password string) http.RoundTripper {
    return wrapNegotiateTransport(base)
}
