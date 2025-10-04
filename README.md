# sme.sh — Steam Deck installer for steam metadata editor

This repo ships `sme.sh`, a small script that installs, uninstalls, or purges **steam metadata editor** on a Steam Deck. It flips SteamOS read-only state when needed, fixes common pacman keyring errors, installs build tools, then installs the AUR package. It can also remove the package and clean local AUR caches.

## Why this exists

Building AUR packages on SteamOS often fails due to:

* Read-only root
* Broken pacman keyring
* Missing `base-devel`, `debugedit`, or an AUR helper

`sme.sh` handles those cases so you can install **steam metadata editor** cleanly.

## What the script does

* Detects SteamOS read-only state

  * Disables it before package work
  * Restores previous state on exit
* Repairs pacman keyring if broken

  * Recreates and populates `archlinux` and `holo` keyrings when present
* Installs build prerequisites

  * `base-devel`, `debugedit`, `git`, `tk`, `python`
* Uses `paru` if available

  * Falls back to manual `makepkg` build if not
* Installs `steam-metadata-editor-git` from AUR
* Verifies the `steammetadataeditor` binary is on `PATH`
* Supports uninstall and cache purge

## Prerequisites

* Steam Deck with SteamOS
* `sudo` access
* Internet access

## Quick start

You can run it without setting the executable bit:

```bash
bash sme.sh
```

Or make it executable:

```bash
chmod +x sme.sh
./sme.sh
```

### Modes

* `install` (default)
  Install **steam metadata editor** from AUR.
* `uninstall`
  Remove the package.
* `purge`
  Uninstall and delete local AUR build caches for this package.
* `reinstall`
  Uninstall then install.

Examples:

```bash
# install
bash sme.sh

# uninstall
bash sme.sh uninstall

# purge package + local caches
bash sme.sh purge

# reinstall from scratch
bash sme.sh reinstall
```

## What gets purged

Local AUR caches for this package, if they exist:

* `~/.cache/paru/clone/steam-metadata-editor-git`
* `~/.cache/yay/steam-metadata-editor-git`
* `~/.cache/pikaur/build/steam-metadata-editor-git`

## Verify the install

```bash
command -v steammetadataeditor
steammetadataeditor --version 2>/dev/null || true
pacman -Qi steam-metadata-editor-git | sed -n '1,20p'
```

## How it installs under the hood

1. Check SteamOS read-only state with `steamos-readonly status`.
2. Disable read-only if enabled.
3. Try `pacman-key --list-keys`. If it fails:

   * Remove `/etc/pacman.d/gnupg`
   * Run `pacman-key --init`
   * Populate `archlinux` and `holo` keyrings when available
   * Sync `archlinux-keyring` and `holo-keyring` if present
4. Install build deps: `base-devel debugedit git tk python`.
5. If `paru` exists, run:

   ```bash
   paru -S --needed --noconfirm --skipreview steam-metadata-editor-git
   ```

   Else, clone the AUR repo and `makepkg -si --noconfirm`.
6. Confirm `steammetadataeditor` is on `PATH`.
7. Restore the prior read-only state.

## Troubleshooting

* **Keyring errors**: Re-run the script. It rebuilds the keyring if broken.
* **Missing `paru`**: The script will build with `makepkg` automatically.
* **Read-only still enabled**: Run `sudo steamos-readonly disable` first, then retry.
* **Stale build state**: Run `bash sme.sh purge` then `bash sme.sh reinstall`.

## Uninstall manually

```bash
sudo pacman -Rns steam-metadata-editor-git
```

## References

* AUR package: [steam-metadata-editor-git](https://aur.archlinux.org/packages/steam-metadata-editor-git)
* Upstream project: Steam-Metadata-Editor on GitHub (see the upstream link on the AUR page)

## Contributing

* Open an issue with Deck model, SteamOS version, and logs.
* Pull requests welcome for additional helpers or deps.

## License

This project is licensed under the terms of the [MIT License](LICENSE).

## Releases

Prebuilt scripts and tagged versions are available on the
[Releases page](https://github.com/jdros15/SME-Steam-Deck-Installer/releases).

