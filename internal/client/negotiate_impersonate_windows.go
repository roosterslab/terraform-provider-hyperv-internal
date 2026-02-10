//go:build windows

package client

import (
    "net/http"
    "strings"
    "unsafe"
    "syscall"
    "runtime"

    "golang.org/x/sys/windows"
)

// wrapNegotiateTransportWithImpersonation creates a RoundTripper that impersonates the provided
// Windows user for the duration of the HTTP request and then performs Negotiate using SSPI with the
// current (impersonated) token. If password is empty, requests will likely fail to logon.
func wrapNegotiateTransportWithImpersonation(base *http.Transport, username, password string) http.RoundTripper {
    dom, user := splitDomainUser(username)
    return &impersonateTransport{base: base, domain: dom, username: user, password: password}
}

type impersonateTransport struct {
    base     *http.Transport
    domain   string
    username string
    password string
}

func (t *impersonateTransport) RoundTrip(req *http.Request) (*http.Response, error) {
    // Ensure impersonation applies to a single OS thread for the duration of RoundTrip
    runtime.LockOSThread()
    defer runtime.UnlockOSThread()
    // Logon user to obtain a primary token
    var token windows.Token
    u := t.username
    d := t.domain
    // Prefer INTERACTIVE logon for local HTTP Negotiate, fallback to NEW_CREDENTIALS
    const LOGON32_LOGON_INTERACTIVE = 2
    const LOGON32_LOGON_NEW_CREDENTIALS = 9
    const LOGON32_PROVIDER_DEFAULT = 0
    tok, err := logonUserW(u, d, t.password, LOGON32_LOGON_INTERACTIVE, LOGON32_PROVIDER_DEFAULT)
    if err != nil {
        // Fallback: use NEW_CREDENTIALS for remote/network scenarios
        tok, err = logonUserW(u, d, t.password, LOGON32_LOGON_NEW_CREDENTIALS, LOGON32_PROVIDER_DEFAULT)
    }
    if err != nil {
        return nil, err
    }
    token = tok
    defer token.Close()

    // Impersonate for the lifetime of this request
    if err := impersonateLoggedOnUser(token); err != nil { return nil, err }
    defer revertToSelf()

    // With impersonation active, the SSPI Negotiate transport will use the impersonated identity
    rt := wrapNegotiateTransport(t.base)
    return rt.RoundTrip(req)
}

func splitDomainUser(input string) (domain, user string) {
    s := input
    if i := strings.Index(s, "\\"); i > 0 {
        return s[:i], s[i+1:]
    }
    return "", s
}

var (
    advapi32                    = windows.NewLazySystemDLL("advapi32.dll")
    procLogonUserW              = advapi32.NewProc("LogonUserW")
    procImpersonateLoggedOnUser = advapi32.NewProc("ImpersonateLoggedOnUser")
    procRevertToSelf            = advapi32.NewProc("RevertToSelf")
)

func logonUserW(username, domain, password string, logonType, provider uint32) (windows.Token, error) {
    var token windows.Token
    u := windows.StringToUTF16Ptr(username)
    d := (*uint16)(nil)
    if domain != "" { d = windows.StringToUTF16Ptr(domain) }
    p := windows.StringToUTF16Ptr(password)
    r1, _, e1 := procLogonUserW.Call(
        uintptr(unsafe.Pointer(u)),
        uintptr(unsafe.Pointer(d)),
        uintptr(unsafe.Pointer(p)),
        uintptr(logonType),
        uintptr(provider),
        uintptr(unsafe.Pointer(&token)),
    )
    if r1 == 0 {
        if e1 != nil { return 0, e1 }
        return 0, syscall.EINVAL
    }
    return token, nil
}

func impersonateLoggedOnUser(token windows.Token) error {
    r1, _, e1 := procImpersonateLoggedOnUser.Call(uintptr(token))
    if r1 == 0 {
        if e1 != nil { return e1 }
        return syscall.EINVAL
    }
    return nil
}

func revertToSelf() error {
    r1, _, e1 := procRevertToSelf.Call()
    if r1 == 0 {
        if e1 != nil { return e1 }
        return syscall.EINVAL
    }
    return nil
}
