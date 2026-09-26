#!/usr/bin/env bash
# Final site assembly.  <site>/<project>/{arch,apt,rpm} already hold the
# built repositories (downloaded artifacts); this adds
#
#   <site>/index.html            landing page (site/index.html)
#   <site>/keys/                 the Firn Labs packaging key, both encodings
#   <site>/<project>/index.html  each project's install page
#                                (<project>/site/index.html, placeholders filled)
#
# Placeholders: __FINGERPRINT__ (space-grouped), __FINGERPRINT_COMPACT__,
# __UPDATED__ (today, UTC), and per project __LATEST_<PROJECT>__ from the
# environment (e.g. LATEST_UNKAI=v0.5.0).
#
#   LATEST_UNKAI=v0.5.0 PACKAGING_GPG_PRIVATE_KEY=... scripts/assemble.sh _site
set -euo pipefail

site="$(realpath -m "${1:?usage: assemble.sh <site-dir>}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/.."

fpr="$(bash "$here/gpg-import.sh")"
mkdir -p "$site/keys"
gpg --batch --armor --export "$fpr" > "$site/keys/firn-labs.asc"
gpg --batch --export "$fpr" > "$site/keys/firn-labs.gpg"
echo "$fpr" > "$site/keys/FINGERPRINT"
touch "$site/.nojekyll"

pretty_fpr="$(echo "$fpr" | sed 's/..../& /g; s/ $//')"
render() {
  local src="$1" dst="$2"
  cp "$src" "$dst"
  sed -i \
    -e "s|__FINGERPRINT_COMPACT__|${fpr}|g" \
    -e "s|__FINGERPRINT__|${pretty_fpr}|g" \
    -e "s|__UPDATED__|$(date -u +%Y-%m-%d)|g" \
    "$dst"
  # __LATEST_UNKAI__ ← $LATEST_UNKAI, and so on for every project.
  for var in $(compgen -v | grep '^LATEST_' || true); do
    sed -i "s|__${var}__|${!var}|g" "$dst"
  done
}

render "$root/site/index.html" "$site/index.html"
for page in "$root"/*/site/index.html; do
  project="$(basename "$(dirname "$(dirname "$page")")")"
  mkdir -p "$site/$project"
  render "$page" "$site/$project/index.html"
done

find "$site" -maxdepth 2 | sort
du -sh "$site"
