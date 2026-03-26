#!/usr/bin/env bash
# Steam Deck installer/uninstaller for Steam Metadata Editor (AUR)
# Modes: install (default), uninstall, purge, reinstall
# - Handles SteamOS read-only root
# - Repairs pacman keyring if broken
# - Installs build deps and uses paru if available, else makepkg
# - Uninstall removes the AUR package; purge also cleans local AUR caches

set -euo pipefail

MODE="${1:-install}"

usage() {
  cat <<'EOF'
Usage: sme.sh [install|uninstall|purge|reinstall]

install    Install Steam Metadata Editor from AUR (default)
uninstall  Remove the steam-metadata-editor-git package
purge      Uninstall and remove local AUR build caches for this package
reinstall  Uninstall then install

Examples:
  ./sme.sh
  ./sme.sh uninstall
  ./sme.sh purge
  ./sme.sh reinstall
EOF
}

case "$MODE" in
  install|uninstall|purge|reinstall) ;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown mode: $MODE"; usage; exit 2;;
esac

# Must be run as root (via sudo); capture the original non-root caller
if [ "$(id -u)" -ne 0 ]; then
  echo "[error] this script must be run with sudo" >&2
  exit 1
fi
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
  echo "[error] could not determine the invoking non-root user (SUDO_USER is unset or root)" >&2
  echo "        run as: sudo ./sme.sh" >&2
  exit 1
fi
REAL_USER="$SUDO_USER"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

need() { command -v "$1" >/dev/null 2>&1; }
need_as_user() { sudo -u "$REAL_USER" bash -c "command -v '$1'" >/dev/null 2>&1; }

# Track SteamOS read-only state if available
ro_tool=""
if need steamos-readonly; then ro_tool="steamos-readonly"; fi

initial_ro="unknown"
if [ -n "$ro_tool" ]; then
  if steamos-readonly status 2>/dev/null | grep -qi "enabled"; then
    initial_ro="enabled"
    steamos-readonly disable
  else
    initial_ro="disabled"
  fi
fi

restore_ro() {
  if [ "$initial_ro" = "enabled" ] && [ -n "$ro_tool" ]; then
    steamos-readonly enable || true
  fi
}
trap restore_ro EXIT

is_installed() { pacman -Qi steam-metadata-editor-git >/dev/null 2>&1; }

fix_keyring_if_needed() {
  if ! pacman-key --list-keys >/dev/null 2>&1; then
    echo "[keyring] repairing pacman keyring"
    rm -rf /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate archlinux || true
    if [ -f /usr/share/pacman/keyrings/holo.gpg ]; then
      pacman-key --populate holo || true
    fi
    pacman -Sy --noconfirm archlinux-keyring || true
    if pacman -Si holo-keyring >/dev/null 2>&1; then
      pacman -Sy --noconfirm holo-keyring || true
    fi
  fi
}

install_pkg() {
  fix_keyring_if_needed
  echo "[deps] installing base-devel, debugedit, git, tk, python"
  pacman -Sy --needed --noconfirm base-devel debugedit git tk python

  # Remove orphaned /opt/sme files from any prior manual install so pacman
  # doesn't hit "exists in filesystem" conflicts during the AUR install
  if [ -d /opt/sme ]; then
    echo "[cleanup] removing orphaned /opt/sme from previous manual install"
    rm -rf /opt/sme
  fi

  # AUR helpers and makepkg cannot run as root -- drop to the real user
  if need_as_user paru; then
    echo "[aur] installing via paru as $REAL_USER"
    sudo -u "$REAL_USER" paru -S --needed --noconfirm --skipreview steam-metadata-editor-git
  else
    echo "[aur] installing manually via makepkg as $REAL_USER"
    workdir="$(sudo -u "$REAL_USER" mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT
    sudo -u "$REAL_USER" git clone https://aur.archlinux.org/steam-metadata-editor-git.git "$workdir/steam-metadata-editor-git"
    cd "$workdir/steam-metadata-editor-git"
    sudo -u "$REAL_USER" makepkg -si --noconfirm
  fi

  if ! command -v steammetadataeditor >/dev/null 2>&1; then
    echo "[verify] installed but 'steammetadataeditor' not found in PATH" >&2
    exit 1
  fi
  echo "[done] Steam Metadata Editor installed"
}

uninstall_pkg() {
  if is_installed; then
    echo "[remove] uninstalling steam-metadata-editor-git"
    pacman -Rns --noconfirm steam-metadata-editor-git
  else
    echo "[remove] package not installed; skipping"
  fi
}

purge_caches() {
  echo "[purge] removing local AUR build caches for this package"
  rm -rf "${REAL_HOME}/.cache/paru/clone/steam-metadata-editor-git" 2>/dev/null || true
  rm -rf "${REAL_HOME}/.cache/yay/steam-metadata-editor-git" 2>/dev/null || true
  rm -rf "${REAL_HOME}/.cache/pikaur/build/steam-metadata-editor-git" 2>/dev/null || true
}

case "$MODE" in
  install)    install_pkg ;;
  uninstall)  uninstall_pkg ;;
  purge)      uninstall_pkg; purge_caches ;;
  reinstall)  uninstall_pkg; install_pkg ;;
esac
