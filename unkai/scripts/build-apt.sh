#!/usr/bin/env bash
# Build the APT repository:
#
#   <out>/pool/main/u/unkai-mail/*.deb
#   <out>/dists/stable/main/binary-amd64/Packages(.gz)
#   <out>/dists/stable/{Release,Release.gpg,InRelease}
#
# Standard (non-flat) layout, one suite `stable`, one component
# `main`, arch amd64.  Signed with the packaging key so
# `signed-by=` works.  apt picks the highest version when several
# are in the pool.
#
#   TAGS='["v0.5.0"]' PACKAGING_GPG_PRIVATE_KEY=... unkai/scripts/build-apt.sh out/unkai/apt
set -euo pipefail

out="$(realpath -m "${1:?usage: build-apt.sh <out-dir>}")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_repo="${SOURCE_REPO:-firn-labs/unkai-mail}"

# GitHub job containers run with HOME=/github/home while the key is
# imported into the passwd home; pin one keyring for gpg AND rpmsign.
export GNUPGHOME="${GNUPGHOME:-$(getent passwd "$(id -u)" | cut -d: -f6)/.gnupg}"
fpr="$(bash "$here/../../scripts/gpg-import.sh")"
pool="$out/pool/main/u/unkai-mail"
bin="$out/dists/stable/main/binary-amd64"
mkdir -p "$pool" "$bin"

for tag in $(echo "$TAGS" | tr -d '[]"' | tr ',' ' '); do
  [ -n "$tag" ] || continue
  ver="${tag#v}"
  asset="Unkai-Mail_${ver}_amd64.deb"
  echo "fetching $asset"
  curl -sSfL --retry 3 -o "$pool/$asset" \
    "https://github.com/${source_repo}/releases/download/${tag}/${asset}"
done

cd "$out"
apt-ftparchive --arch amd64 packages pool > "$bin/Packages"
gzip -k -9 -f "$bin/Packages"

cat > "$out/.release.conf" <<EOF
APT::FTPArchive::Release {
  Origin "Firn Labs";
  Label "Unkai Mail";
  Suite "stable";
  Codename "stable";
  Architectures "amd64";
  Components "main";
  Description "Unkai Mail — native mail client with deep Nextcloud integration";
};
EOF
apt-ftparchive -c "$out/.release.conf" release dists/stable > dists/stable/Release
rm "$out/.release.conf"

gpg --batch --yes --default-key "$fpr" -abs -o dists/stable/Release.gpg dists/stable/Release
gpg --batch --yes --default-key "$fpr" --clearsign -o dists/stable/InRelease dists/stable/Release
find "$out" -type f | sort
