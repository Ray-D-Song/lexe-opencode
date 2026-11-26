#!/bin/sh
set -eu

repo=Ray-D-Song/lexe-opencode

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer is for macOS only." >&2
  exit 1
fi

arch=$(uname -m)
if [ "$arch" = "x86_64" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
  arch=arm64
fi
case "$arch" in
  arm64|aarch64) arch=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m) (only darwin-arm64 is published)" >&2; exit 1 ;;
esac

if [ -n "${OPENCODE_VERSION:-}" ]; then
  case "$OPENCODE_VERSION" in
    lexe-opencode-v*) tag="$OPENCODE_VERSION" ;;
    v*) tag="lexe-opencode-$OPENCODE_VERSION" ;;
    *) tag="lexe-opencode-v$OPENCODE_VERSION" ;;
  esac
else
  tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=20" \
    | grep -o '"tag_name":[[:space:]]*"lexe-opencode-v[^"]*"' \
    | head -n 1 \
    | sed 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/')
  if [ -z "$tag" ]; then
    echo "Failed to resolve latest lexe-opencode release tag" >&2
    exit 1
  fi
fi

install_dir=${OPENCODE_INSTALL_DIR:-"$HOME/.local/bin"}
asset="opencode-darwin-$arch"
base="https://github.com/$repo/releases/download/$tag"
target="$install_dir/loc"

mkdir -p "$install_dir"
tmp=$(mktemp -d "$install_dir/.opencode.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fsSL "$base/$asset" -o "$tmp/$asset"
curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS"
(cd "$tmp" && grep "  $asset$" SHA256SUMS | shasum -a 256 -c -)
chmod 755 "$tmp/$asset"
mv -f "$tmp/$asset" "$target"

path_line="export PATH=\"$install_dir:\$PATH\" # OpenCode (Lexe)"
case "${SHELL##*/}" in
  bash) profile="$HOME/.bashrc" ;;
  zsh) profile="$HOME/.zshrc" ;;
  fish) profile="$HOME/.config/fish/conf.d/opencode.fish"; path_line="set -gx PATH \"$install_dir\" \$PATH # OpenCode (Lexe)" ;;
  *) profile="$HOME/.profile" ;;
esac
mkdir -p "$(dirname "$profile")"
touch "$profile"
grep -Fqx "$path_line" "$profile" || printf '%s\n' "$path_line" >> "$profile"

echo "Installed lexe-opencode ($tag) to $target. Reopen your terminal or run: exec \"\$SHELL\" -l"
