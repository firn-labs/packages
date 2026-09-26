# firn-labs/packages

Signed Linux package repositories for Firn Labs software, served from
GitHub Pages at **https://firn-labs.github.io/packages/** (that page is
also the user-facing install guide).

| Project | pacman | apt | dnf / zypper | Source of the packages |
|---|---|---|---|---|
| [Unkai Mail](unkai/) | `unkai/arch/x86_64/` | `unkai/apt/` | `unkai/rpm/` | [firn-labs/unkai-mail](https://github.com/firn-labs/unkai-mail) releases |

`keys/` holds the one Firn Labs packaging key that signs every
repository (`firn-labs.asc`, `firn-labs.gpg`, `FINGERPRINT`).

## Layout

```
.github/workflows/build-site.yml   one workflow, one job group per project
scripts/gpg-import.sh              shared: import the packaging key, print its fingerprint
scripts/assemble.sh                shared: landing page, keys/, every project's index page
site/index.html                    landing page (lists the projects)
unkai/                             ← one folder per project
  README.md                        project-specific notes
  scripts/build-arch.sh            pacman repo from the release .deb (via the PKGBUILD in unkai-mail)
  scripts/build-apt.sh             APT repo (apt-ftparchive, signed InRelease)
  scripts/build-rpm.sh             dnf repo (rpmsign + createrepo_c, signed repomd.xml)
  site/index.html                  install page → /unkai/
  site/rpm/unkai-mail.repo         dnf repo file
```

## How it works

`build-site.yml` rebuilds the **entire site from scratch** on every run
and deploys it with `actions/deploy-pages` — nothing is committed to
this repo, so it never grows and any bad deploy is fixed by re-running.

Per project: resolve the newest `KEEP` (3) published, non-prerelease
releases → build the three repositories from the release assets, sign
them → `deploy` assembles everything with the landing page and the
public key and publishes to Pages.

Triggers: `repository_dispatch` (`release-published`, sent by each
project's release workflow when a release is **published** — never on
the tag push, releases are drafts until then), `workflow_dispatch`, and
a daily cron as a safety net.

## Adding a project

1. Create `<project>/` with `scripts/build-*.sh` (copy Unkai's and change
   `SOURCE_REPO` + asset names), `site/index.html` (install page) and any
   repo files.
2. Copy the `unkai-*` jobs in `build-site.yml`, rename, and add the
   artifact downloads + a `LATEST_<PROJECT>` env in `deploy`.
3. Add a card to `site/index.html` and a row to the table above.
4. In the project's repo, add a `packages.yml` that sends the
   `repository_dispatch` (see `unkai-mail/.github/workflows/packages.yml`).

## One-time setup

### 1. Packaging key

One OpenPGP key signs all repositories. It must have **no passphrase**
(it only ever lives in the repo secret and in the team password store;
a passphrase would just be a second secret).

```sh
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "Firn Labs Packaging <packages@firn-labs.com>" ed25519 sign never
FPR=$(gpg --list-secret-keys --with-colons "Firn Labs Packaging" | awk -F: '$1=="fpr"{print $10; exit}')
gpg --armor --export-secret-keys "$FPR" > packaging-key.asc     # → secret + password store, then delete the file
echo "$FPR"
```

`never` = no expiry. If you prefer an expiring key, rotate it in the
secret before it lapses — an expired key makes every user's `apt update`
fail.

### 2. Secrets

| Where | Name | Value |
|---|---|---|
| this repo | `PACKAGING_GPG_PRIVATE_KEY` | contents of `packaging-key.asc` |
| each project repo | `PACKAGES_DISPATCH_TOKEN` | fine-grained PAT, repository access: `packages` only, permission *Contents: Read and write* (what `repository_dispatch` needs) |

### 3. GitHub Pages

Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.

### 4. First deploy

Actions → *Build & deploy package repositories* → *Run workflow*.
Afterwards https://firn-labs.github.io/packages/ shows the fingerprint;
paste it into each project's install docs (for Unkai:
`unkai-mail/docs/INSTALL.md`, search for `FINGERPRINT`).

## Local dry-run (Docker)

Generate a throwaway key **inside a container** (Git Bash's gpg-agent
does not work), then run each builder in its native image. `TAGS` is a
JSON array, newest first.

```sh
docker run --rm -v "$PWD:/w" ubuntu:24.04 bash -c 'apt-get update -qq >/dev/null && apt-get install -y -qq gnupg >/dev/null 2>&1;
  gpg --batch --pinentry-mode loopback --passphrase "" --quick-generate-key "test <t@example.invalid>" ed25519 sign never 2>/dev/null;
  gpg --armor --export-secret-keys t@example.invalid > /w/testkey.asc'
export PACKAGING_GPG_PRIVATE_KEY="$(cat testkey.asc)"
export TAGS='["v0.5.0"]'

# pacman (AUR_TEMPLATE_DIR = a checkout of unkai-mail/packaging/aur; omit to fetch from GitHub main)
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -e AUR_TEMPLATE_DIR=/aur \
  -v "$PWD:/w:ro" -v "$PWD/../unkai-mail/packaging/aur:/aur:ro" archlinux:base-devel bash -c '
  pacman -Syu --noconfirm --needed sudo git curl >/dev/null && useradd -m b &&
  cp -r /w /tmp/w && chown -R b /tmp/w && cd /tmp/w && sudo -E -H -u b bash unkai/scripts/build-arch.sh out/unkai/arch'

# apt
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -v "$PWD:/w:ro" ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq apt-utils gnupg curl ca-certificates >/dev/null &&
  cd /w && bash unkai/scripts/build-apt.sh /tmp/out/unkai/apt'

# rpm
docker run --rm -e TAGS -e PACKAGING_GPG_PRIVATE_KEY -v "$PWD:/w:ro" fedora:latest bash -c '
  dnf install -y -q createrepo_c rpm-sign gnupg2 curl && cd /w && bash unkai/scripts/build-rpm.sh /tmp/out/unkai/rpm'
```

(On Git Bash prefix `docker` with `MSYS_NO_PATHCONV=1` so the mount
paths survive.)

## Size budget

GitHub Pages sites should stay under 1 GB. One Unkai release is roughly
23 MB (`.deb`) + 23 MB (`.rpm`) + 19 MB (Arch) ≈ 65 MB, so `KEEP=3` uses
about 200 MB. Watch this as projects are added; lower `KEEP` or split
projects onto their own Pages site if it gets tight.
