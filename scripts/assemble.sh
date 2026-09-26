#!/usr/bin/env bash
# Final site assembly:  <site>/{arch,apt,rpm} already hold the built
# repositories (downloaded artifacts); add the static pages, the
# public key in both encodings, and fill the placeholders in
# index.html.
#
#   LATEST=v0.5.0 PACKAGING_GPG_PRIVATE_KEY=... scripts/assemble.sh _site
set -euo pipefail

site="$(realpath -m "${1:?usage: assemble.sh <site-dir>}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fpr="$(bash "$here/gpg-import.sh")"
mkdir -p "$site/keys"
gpg --batch --armor --export "$fpr" > "$site/keys/unkai-mail.asc"
gpg --batch --export "$fpr" > "$site/keys/unkai-mail.gpg"
echo "$fpr" > "$site/keys/FINGERPRINT"

cp "$here/../site/index.html" "$site/index.html"
touch "$site/.nojekyll"

pretty_fpr="$(echo "$fpr" | sed 's/..../& /g; s/ $//')"
sed -i \
  -e "s|__FINGERPRINT_COMPACT__|${fpr}|g" \
  -e "s|__FINGERPRINT__|${pretty_fpr}|g" \
  -e "s|__LATEST__|${LATEST:-unknown}|g" \
  -e "s|__UPDATED__|$(date -u +%Y-%m-%d)|g" \
  "$site/index.html"

find "$site" -maxdepth 2 | sort
du -sh "$site"
