# Unkai Mail

Repositories built from the releases of
[firn-labs/unkai-mail](https://github.com/firn-labs/unkai-mail), served at
https://firn-labs.github.io/packages/unkai/.

| Format | Path | Package | Notes |
|---|---|---|---|
| pacman | `arch/x86_64/` | `unkai-mail-bin` | built from the release `.deb` with `unkai-mail/packaging/aur` (fetched from `main`); `makepkg --sign` + `repo-add --sign` |
| apt | `apt/` | `unkai-mail` | the release `.deb` as-is; `apt-ftparchive`, suite `stable`, component `main`, amd64 |
| dnf / zypper | `rpm/` | `unkai-mail` | the release `.rpm`, `rpmsign --addsign`; `createrepo_c`; `unkai-mail.repo` |

Release assets are named `Unkai-Mail_<ver>_amd64.deb` and
`Unkai-Mail-<ver>-1.x86_64.rpm` — the scripts derive them from the tag.

Triggered by `unkai-mail/.github/workflows/packages.yml` on
`release: published`. The user-facing install guide lives in
`unkai-mail/docs/INSTALL.md`; the page here mirrors its Linux sections.

Tracking issue: [unkai-mail#600](https://github.com/firn-labs/unkai-mail/issues/600),
chunk [#603](https://github.com/firn-labs/unkai-mail/issues/603).
