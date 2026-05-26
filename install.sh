#!/usr/bin/env bash
# touchgrass installer — curl | bash safe.
#
#   curl -fsSL https://raw.githubusercontent.com/<you>/touchgrass/main/install.sh | bash
#
# What it does:
#   1. downloads bin/touchgrass into ~/.touchgrass/bin/
#   2. symlinks it onto your PATH (~/.local/bin or /opt/homebrew/bin or ~/bin)
#   3. runs `touchgrass init` to load the launchd sampler
#   4. prints next steps
#
# Idempotent. Safe to re-run. Will NOT touch your data dir or config.

set -euo pipefail

REPO="${TOUCHGRASS_REPO:-senthilnathan/touchgrass}"   # change to your gh user/repo
BRANCH="${TOUCHGRASS_BRANCH:-main}"
SRC_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/bin/touchgrass"

ROOT="$HOME/.touchgrass"
BIN_DIR="$ROOT/bin"
BIN="$BIN_DIR/touchgrass"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
warn()  { printf '\033[33m%s\033[0m\n' "$*"; }

# ── platform check ──────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  red "touchgrass is macOS-only (uses launchd, ioreg, pmset, osascript)."
  exit 1
fi

# ── python check ────────────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  red "python3 not found. install via xcode-select --install or homebrew."
  exit 1
fi

bold "==> installing touchgrass to $BIN"
mkdir -p "$BIN_DIR"

# ── download (or copy from local checkout) ──────────────────────────────────
if [[ -f "./bin/touchgrass" ]]; then
  cp ./bin/touchgrass "$BIN"
  green "    (used local ./bin/touchgrass)"
else
  if ! command -v curl >/dev/null 2>&1; then
    red "curl not found."; exit 1
  fi
  if ! curl -fsSL "$SRC_URL" -o "$BIN"; then
    red "download failed: $SRC_URL"
    exit 1
  fi
fi
chmod +x "$BIN"

# ── pick a PATH dir we can symlink into ─────────────────────────────────────
choose_link_dir() {
  for d in "/opt/homebrew/bin" "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin"; do
    if [[ -d "$d" && -w "$d" ]]; then echo "$d"; return; fi
  done
  # last resort: create ~/.local/bin
  mkdir -p "$HOME/.local/bin"
  echo "$HOME/.local/bin"
}

LINK_DIR="$(choose_link_dir)"
LINK="$LINK_DIR/touchgrass"

if [[ -L "$LINK" ]] || [[ -f "$LINK" ]]; then
  rm -f "$LINK"
fi
ln -s "$BIN" "$LINK"
green "==> linked $LINK -> $BIN"

# warn if LINK_DIR isn't on PATH
case ":$PATH:" in
  *":$LINK_DIR:"*) ;;
  *) warn "==> NOTE: $LINK_DIR is not on your PATH. add this to ~/.zshrc:"
     warn "       export PATH=\"$LINK_DIR:\$PATH\"" ;;
esac

# ── start the background sampler ────────────────────────────────────────────
bold "==> starting background sampler (launchd)"
"$BIN" init || warn "init failed - run 'touchgrass doctor' to diagnose."

# ── done ────────────────────────────────────────────────────────────────────
echo
green "✓ touchgrass installed."
echo
echo "next steps:"
echo "  touchgrass live           # see your AI agents right now"
echo "  touchgrass today          # active vs alive hours"
echo "  touchgrass digest         # weekly markdown report"
echo "  touchgrass shim install   # optional: friction wrapper for claude/opencode/..."
echo "  touchgrass doctor         # self-test (will request notification permission)"
echo
echo "uninstall any time with:"
echo "  touchgrass shim uninstall && touchgrass stop"
echo "  rm \"$LINK\""
echo "  rm  ~/Library/LaunchAgents/com.touchgrass.watch.plist"
echo "  rm -rf $ROOT"
echo
echo "🌱 now go outside."
