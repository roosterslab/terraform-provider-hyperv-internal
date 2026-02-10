//go:build !windows

package client

import "net/http"

// wrapNegotiateTransport is a stub for non-Windows platforms.
// Since Hyper-V is Windows-only, this provider won't work on other platforms,
// but we provide a stub to allow cross-compilation.
func wrapNegotiateTransport(base http.RoundTripper) http.RoundTripper {
	// On non-Windows platforms, just return the base transport
	// Negotiate authentication is not supported
	return base
}
