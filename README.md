# unkai-packages

Linux package repositories for [Unkai Mail](https://github.com/firn-labs/unkai-mail),
served from GitHub Pages at **https://firn-labs.github.io/unkai-packages/**
(that page is also the user-facing install guide).

| Path | Format | Consumers |
|---|---|---|
| `arch/x86_64/` | pacman repository (`unkai-mail.db`, signed `.pkg.tar.zst`) | Arch, CachyOS, Manjaro, EndeavourOS |
| `apt/` | APT repository (`dists/stable`, `pool/`, signed `InRelease`) | Debian, Ubuntu, Mint, Pop!_OS |
| `rpm/` | dnf/zypper repository (`repodata/`, signed rpms + `repomd.xml.asc`) | Fedora, RHEL, Alma, Rocky, openSUSE |
| `keys/` | the packaging key (`unkai-mail.asc`, `unkai-mail.gpg`, `FINGERPRINT`) | all of the above |

Part of [unkai-mail#600](https://github.com/firn-labs/unkai-mail/issues/600)
(chunk [#603](https://github.com/firn-labs/unkai-mail/issues/603)).

## How it works

`.github/workflows/build-site.yml` rebuilds the **entire site from scratch**
on every run and deploys it with `actions/deploy-pages` — nothing is
committed to this repo, so it never grows and any bad deploy is fixed by
re-running.

1. `versions` lists the newest `KEEP` (3) published, non-prerelease
   releases of `firn-labs/unkai-mail`.
2. `arch` (archlinux container) builds the Arch package for each release
   from its `.deb` using the PKGBUILD in `unkai-mail/packaging/aur`,
   signs it, and runs `repo-add --sign`.
3. `apt` downloads the `.deb`s, runs `apt-ftparchive`, signs `Release`
   → `InRelease` + `Release.gpg`.
4. `rpm` (fedora container) downloads the `.rpm`s, `rpm --addsign`s them,
   runs `createrepo_c`, signs `repomd.xml`.
5. `deploy` assembles everything with `site/index.html` and the public key
   and publishes to Pages.

Triggers: `repository_dispatch` (sent by `unkai-mail`'s `packages.yml`
when a release is **published** — never on the tag push, releases are
drafts until then), `workflow_dispatch`, and a daily cron as a safety net.

Scripts live in `scripts/` and run unchanged locally — see below.

## One-time setup

### 1. Packaging key

One OpenPGP key signs all three repositories. It must have **no
passphrase** (it only ever lives in the repo secret and in the team
password store; a passphrase would just be a second secret).

```sh
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "Firn Labs Packaging <packages@firn-labs.com>" ed25519 sign never
FPR=$(gpg --list-secret-keys --with-colons "Firn Labs Packaging" | awk -F: '$1=="fpr"{print $10; exit}')
gpg --armor --export-secret-keys "$FPR" > packaging-key.asc     # → secret + password store, then delete the file
gpg --armor --export "$FPR" > packaging-key.pub.asc             # public half, for reference
echo "$FPR"
```

`never` = no expiry. If you prefer an expiring key, remember to rotate
it in the secret before it lapses — expired keys make every user's
`apt update` fail.

### 2. Secrets

| Where | Name | Value |
|---|---|---|
| this repo | `PACKAGING_GPG_PRIVATE_KEY` | contents of `packaging-key.asc` |
| `firn-labs/unkai-mail` | `PACKAGES_DISPATCH_TOKEN` | fine-grained PAT, repository access: `unkai-packages` only, permission *Contents: Read and write* (needed for `repository_dispatch`) |

### 3. GitHub Pages

Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.
(Already set via API when the repo was created; verify.)

### 4. First deploy

Actions → *Build & deploy package repositories* → *Run workflow*.
Afterwards https://firn-labs.github.io/unkai-packages/ shows the
fingerprint and the install snippets. Paste the fingerprint into
`unkai-mail/docs/INSTALL.md` (search for `FINGERPRINT`).

## Local dry-run (Docker)

Generate a throwaway key, then run each builder in its native container.
`TAGS` is a JSON array, newest first.

```sh
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key "test <t@example.invalid>" ed25519 sign never
export PACKAGING_GPG_PRIVATE_KEY="$(gpg --armor --export-secret-keys t@example.invalid)"
export TAGS='["v0.5.0"]'

# pacman (AUR_TEMPLATE_DIR points at a checkout of unkai-mail/packaging/aur)
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -e AUR_TEMPLATE_DIR=/aur \
  -v "$PWD:/w" -v "$PWD/../unkai-mail/packaging/aur:/aur:ro" archlinux:base-devel bash -c '
  pacman -Syu --noconfirm --needed sudo git curl >/dev/null && useradd -m b &&
  cp -r /w /tmp/w && chown -R b /tmp/w && cd /tmp/w && sudo -E -H -u b bash scripts/build-arch.sh out/arch'

# apt
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -v "$PWD:/w" ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq apt-utils gnupg curl >/dev/null &&
  cd /w && bash scripts/build-apt.sh /tmp/out/apt'

# rpm
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -v "$PWD:/w" fedora:latest bash -c '
  dnf install -y -q createrepo_c rpm-sign gnupg2 curl && cd /w && bash scripts/build-rpm.sh /tmp/out/rpm'
```

## Size budget

GitHub Pages sites should stay under 1 GB. One release is roughly
23 MB (`.deb`) + 23 MB (`.rpm`) + 19 MB (Arch) ≈ 65 MB, so `KEEP=3`
uses about 200 MB. Raise `KEEP` in the workflow if you want more
versions available for downgrades.
