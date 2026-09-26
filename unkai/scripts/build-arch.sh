#!/usr/bin/env bash
# Build the pacman repository:  <out>/x86_64/{unkai-mail.db,*.pkg.tar.zst,*.sig}
#
# For every tag in $TAGS (JSON array, newest first) the Arch package is
# built from the release .deb with the PKGBUILD template kept in the
# main repo (packaging/aur/unkai-mail-bin), signed with the packaging
# key, and added to a signed repo database.  Must run as a non-root
# user (makepkg insists).
#
#   TAGS='["v0.5.0"]' PACKAGING_GPG_PRIVATE_KEY=... unkai/scripts/build-arch.sh out/unkai/arch
set -euo pipefail

out="$(realpath -m "${1:?usage: build-arch.sh <out-dir>}")/x86_64"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_repo="${SOURCE_REPO:-firn-labs/unkai-mail}"
raw="https://raw.githubusercontent.com/${source_repo}/main/packaging/aur"

fpr="$(bash "$here/../../scripts/gpg-import.sh")"
export GPGKEY="$fpr"
mkdir -p "$out"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/unkai-mail-bin"
if [ -n "${AUR_TEMPLATE_DIR:-}" ]; then
  # Local testing: use a checkout of unkai-mail/packaging/aur instead
  # of fetching from GitHub.
  cp "$AUR_TEMPLATE_DIR/render.sh" "$work/render.sh"
  cp "$AUR_TEMPLATE_DIR/unkai-mail-bin/PKGBUILD" "$work/unkai-mail-bin/PKGBUILD"
else
  curl -sSfL --retry 3 -o "$work/render.sh" "$raw/render.sh"
  curl -sSfL --retry 3 -o "$work/unkai-mail-bin/PKGBUILD" "$raw/unkai-mail-bin/PKGBUILD"
fi

for tag in $(echo "$TAGS" | tr -d '[]"' | tr ',' ' '); do
  [ -n "$tag" ] || continue
  echo "::group::arch $tag"
  bash "$work/render.sh" "$tag" "$work/$tag"
  (
    cd "$work/$tag"
    # -d: runtime deps were validated in the main repo's CI and are
    # not needed to repack a .deb; installing WebKitGTK here would
    # only cost minutes.
    makepkg -d --noconfirm --sign
    mv ./*.pkg.tar.zst ./*.pkg.tar.zst.sig "$out/"
  )
  echo "::endgroup::"
done

cd "$out"
repo-add --sign --key "$fpr" --verify --remove unkai-mail.db.tar.gz ./*.pkg.tar.zst
# repo-add leaves symlinks (unkai-mail.db -> unkai-mail.db.tar.gz);
# Pages serves files, not links — materialise them.
for f in unkai-mail.db unkai-mail.db.sig unkai-mail.files unkai-mail.files.sig; do
  if [ -L "$f" ]; then
    target="$(readlink -f "$f")"
    rm "$f" && cp "$target" "$f"
  fi
done
ls -la "$out"
