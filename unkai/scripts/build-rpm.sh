#!/usr/bin/env bash
# Build the dnf/zypper repository:
#
#   <out>/*.rpm                  (signed with rpm --addsign)
#   <out>/repodata/…             (createrepo_c; repomd.xml.asc signed)
#   <out>/unkai-mail.repo        (copied from site/rpm)
#
# Needs createrepo_c, rpm-sign and gnupg2 (Fedora container in CI).
#
#   TAGS='["v0.5.0"]' PACKAGING_GPG_PRIVATE_KEY=... unkai/scripts/build-rpm.sh out/unkai/rpm
set -euo pipefail

out="$(realpath -m "${1:?usage: build-rpm.sh <out-dir>}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_repo="${SOURCE_REPO:-firn-labs/unkai-mail}"

fpr="$(bash "$here/../../scripts/gpg-import.sh")"
mkdir -p "$out"

for tag in $(echo "$TAGS" | tr -d '[]"' | tr ',' ' '); do
  [ -n "$tag" ] || continue
  ver="${tag#v}"
  asset="Unkai-Mail-${ver}-1.x86_64.rpm"
  echo "fetching $asset"
  curl -sSfL --retry 3 -o "$out/$asset" \
    "https://github.com/${source_repo}/releases/download/${tag}/${asset}"
done

# Embed a signature in every rpm so gpgcheck=1 passes.  The key has
# no passphrase, so rpm's default `--pinentry-mode error` is fine.
rpmsign --define "_gpg_name $fpr" --addsign "$out"/*.rpm
# Verify with the public key in rpm's own keyring — without the
# import, --checksig reports NOKEY even for a good signature.
gpg --batch --armor --export "$fpr" > "$out/.pubkey.asc"
rpmkeys --import "$out/.pubkey.asc"
rm "$out/.pubkey.asc"
rpm --checksig "$out"/*.rpm

createrepo_c --update "$out"
gpg --batch --yes --default-key "$fpr" --detach-sign --armor "$out/repodata/repomd.xml"
cp "$here/../site/rpm/unkai-mail.repo" "$out/unkai-mail.repo"
find "$out" -type f | sort
