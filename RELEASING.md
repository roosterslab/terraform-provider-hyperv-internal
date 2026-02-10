# Release Process

This document explains how to create a new release of the Terraform provider.

## Prerequisites

### 1. Set up GitHub Secrets

You need to add your GPG key to GitHub secrets for automated signing:

1. Go to your repository: https://github.com/roosterslab/terraform-provider-hyperv-internal
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**

Add the following secrets:

#### GPG_PRIVATE_KEY
- **Name**: `GPG_PRIVATE_KEY`
- **Value**: Copy the entire contents of `C:\Users\globql-ws\Desktop\terraform-gpg\private-key.asc`
  - Open the file and copy everything including the `-----BEGIN PGP PRIVATE KEY BLOCK-----` and `-----END PGP PRIVATE KEY BLOCK-----` lines

#### PASSPHRASE
- **Name**: `PASSPHRASE`
- **Value**: Leave empty (your GPG key has no passphrase)
  - Just create the secret with an empty value or put a space

### 2. Add GPG Key to GitHub Account

1. Copy the contents of `C:\Users\globql-ws\Desktop\terraform-gpg\public-key.asc`
2. Go to https://github.com/settings/keys
3. Click **New GPG key**
4. Paste the public key and save

## Creating a Release

### Automated Release (Recommended)

1. Make sure all changes are committed and pushed to master
2. Create and push a version tag:
   ```bash
   git tag v0.1.0
   git push roosterslab v0.1.0
   ```
3. GitHub Actions will automatically:
   - Build binaries for all platforms
   - Sign the release with your GPG key
   - Create a GitHub release
   - Upload all artifacts

### Manual Release (If needed)

If you need to release manually:

```bash
# Install goreleaser
go install github.com/goreleaser/goreleaser@latest

# Set GPG fingerprint
export GPG_FINGERPRINT=CD51FE69272072E68169C49A084F310953A8E337

# Create release (dry run)
goreleaser release --snapshot --clean

# Create actual release
goreleaser release --clean
```

## Version Tags

- Use semantic versioning: `v0.1.0`, `v0.2.0`, `v1.0.0`, etc.
- Pre-releases: `v0.1.0-beta.1`, `v0.1.0-rc.1`
- Always prefix with `v`

## Publishing to Terraform Registry

Once you have releases with GPG signatures:

1. Go to https://registry.terraform.io/
2. Sign in with your GitHub account
3. Click **Publish** > **Provider**
4. Select your repository: `roosterslab/terraform-provider-hyperv-internal`
5. The registry will automatically pick up your releases

## Troubleshooting

### "No provider versions found" error

This means:
- No version tags exist, or
- Tags don't follow the `v*` pattern, or
- No GitHub releases exist, or
- Releases aren't GPG signed

### GPG signing fails

Check:
- GitHub secrets are set correctly
- GPG_PRIVATE_KEY contains the full private key
- PASSPHRASE secret exists (even if empty)

### Build fails

Check:
- `go.mod` is up to date: `go mod tidy`
- Code builds locally: `go build .`
- Tests pass: `go test ./...`
