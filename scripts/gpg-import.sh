#!/usr/bin/env bash
# Import the packaging key from $PACKAGING_GPG_PRIVATE_KEY into the
# current user's keyring and print its fingerprint.  Sourced by the
# build scripts:  FPR=$(bash scripts/gpg-import.sh)
set -euo pipefail

if [ -z "${PACKAGING_GPG_PRIVATE_KEY:-}" ]; then
  echo "PACKAGING_GPG_PRIVATE_KEY is empty" >&2
  exit 1
fi

# Resolve the home from the passwd entry, not $HOME: `sudo -E -u
# builder` (CI's makepkg user) keeps root's HOME, which the builder
# can't write to.
home="$(getent passwd "$(id -u)" | cut -d: -f6)"
export HOME="${home:-$HOME}"
export GNUPGHOME="${GNUPGHOME:-$HOME/.gnupg}"
mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
# Loopback pinentry: the key has no passphrase, but rpm --addsign and
# makepkg --sign go through gpg-agent and must never block on a tty.
grep -q '^allow-loopback-pinentry' "$GNUPGHOME/gpg-agent.conf" 2>/dev/null \
  || echo 'allow-loopback-pinentry' >> "$GNUPGHOME/gpg-agent.conf"
grep -q '^pinentry-mode loopback' "$GNUPGHOME/gpg.conf" 2>/dev/null \
  || echo 'pinentry-mode loopback' >> "$GNUPGHOME/gpg.conf"

printf '%s\n' "$PACKAGING_GPG_PRIVATE_KEY" | gpg --batch --quiet --import

fpr="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="fpr"{print $10; exit}')"
if [ -z "$fpr" ]; then
  echo "no secret key found after import" >&2
  exit 1
fi
echo "$fpr"
