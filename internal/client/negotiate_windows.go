//go:build windows

package client

import (
	"bytes"
	"encoding/base64"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/alexbrainman/sspi/negotiate"
)

// wrapNegotiateTransport returns a RoundTripper that performs HTTP Negotiate (Kerberos/NTLM) using
// the current Windows user credentials via SSPI. It falls back to the provided base transport for
// non-authenticated requests or when the server does not challenge with Negotiate.
func wrapNegotiateTransport(base http.RoundTripper) http.RoundTripper {
	return &sspiNegTransport{base: base}
}

type sspiNegTransport struct {
	base http.RoundTripper
}

func (t *sspiNegTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// Ensure we can resend the body if challenged
	var cachedBody []byte
	if req.Body != nil && req.GetBody == nil {
		// Read and cache body
		b, _ := io.ReadAll(req.Body)
		_ = req.Body.Close()
		cachedBody = append([]byte(nil), b...)
		req.Body = io.NopCloser(bytes.NewReader(cachedBody))
		req.GetBody = func() (io.ReadCloser, error) {
			return io.NopCloser(bytes.NewReader(cachedBody)), nil
		}
		req.ContentLength = int64(len(cachedBody))
	}

	// First attempt: send as-is
	resp, err := t.base.RoundTrip(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusUnauthorized {
		return resp, nil
	}
	// Check if server supports Negotiate
	negotiateOffered := false
	var inToken []byte
	for _, v := range resp.Header.Values("Www-Authenticate") {
		vv := strings.TrimSpace(v)
		if strings.HasPrefix(strings.ToLower(vv), "negotiate") {
			negotiateOffered = true
			parts := strings.SplitN(vv, " ", 2)
			if len(parts) == 2 {
				tok, _ := base64.StdEncoding.DecodeString(strings.TrimSpace(parts[1]))
				if len(tok) > 0 {
					inToken = tok
				}
			}
			break
		}
	}
	if !negotiateOffered {
		return resp, nil
	}
	// Close 401 body before retrying
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()

	// Create SSPI Negotiate client context for current user to target SPN HTTP/hostname
	spnHost := req.URL.Hostname()
	if spnHost == "localhost" || spnHost == "127.0.0.1" || spnHost == "::1" {
		if hn, err := os.Hostname(); err == nil && hn != "" {
			spnHost = hn
		}
	}
	spn := "HTTP/" + spnHost
	cred, err := negotiate.AcquireCurrentUserCredentials()
	if err != nil {
		return nil, err
	}
	defer cred.Release()
	ctx, out0, err := negotiate.NewClientContext(cred, spn)
	if err != nil {
		return nil, err
	}
	defer ctx.Release()

	// Up to a few steps handshake (start with no input token)
	// First leg: send initial token from context creation
	for i := 0; i < 5; i++ {
		var outToken []byte
		var done bool
		if i == 0 {
			outToken = out0
		} else {
			done, outToken, err = ctx.Update(inToken)
			if err != nil {
				return nil, err
			}
		}
		// Clone the original request for this attempt
		r2 := req.Clone(req.Context())
		if r2.GetBody != nil {
			rc, _ := r2.GetBody()
			r2.Body = rc
		}
		r2.Header = cloneHeader(req.Header)
		r2.Header.Set("Authorization", "Negotiate "+base64.StdEncoding.EncodeToString(outToken))

		resp, err = t.base.RoundTrip(r2)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode != http.StatusUnauthorized {
			return resp, nil
		}
		// Extract server token and continue if provided
		var nextIn []byte
		for _, v := range resp.Header.Values("Www-Authenticate") {
			vv := strings.TrimSpace(v)
			if strings.HasPrefix(strings.ToLower(vv), "negotiate ") {
				tokB64 := strings.TrimSpace(strings.TrimPrefix(vv, "Negotiate "))
				tok, _ := base64.StdEncoding.DecodeString(tokB64)
				if len(tok) > 0 {
					nextIn = tok
				}
				break
			}
		}
		// Close 401 body before retry
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()

		if done && nextIn == nil {
			// Context indicates done, but server still 401 without token; break to avoid loop
			break
		}
		inToken = nextIn
	}
	return resp, nil
}

func cloneHeader(h http.Header) http.Header {
	h2 := make(http.Header, len(h))
	for k, vv := range h {
		v2 := make([]string, len(vv))
		copy(v2, vv)
		h2[k] = v2
	}
	return h2
}