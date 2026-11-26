#!/bin/sh
set -eu

install_dir=${OPENCODE_INSTALL_DIR:-"$HOME/.local/bin"}
target="$install_dir/loc"

if [ -e "$target" ] || [ -L "$target" ]; then
  rm -f "$target"
  echo "Removed $target"
else
  echo "Binary not found at $target"
fi

for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.config/fish/conf.d/opencode.fish"; do
  if [ -f "$profile" ] && grep -q '# OpenCode (Lexe)' "$profile"; then
    tmp=$(mktemp)
    grep -v '# OpenCode (Lexe)' "$profile" > "$tmp" || true
    mv -f "$tmp" "$profile"
    echo "Cleaned PATH entry from $profile"
  fi
done

if [ "${OPENCODE_PURGE:-0}" = "1" ] || [ "${1:-}" = "--purge" ]; then
  rm -rf \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/opencode" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/opencode" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
  echo "Purged OpenCode config, data, state, and cache directories."
else
  echo "Uninstalled OpenCode. Config and data directories were preserved (pass --purge or set OPENCODE_PURGE=1 to remove them)."
fi
