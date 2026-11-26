#!/bin/sh
set -eu

repo=Ray-D-Song/lexe-opencode

if [ "$(uname -s)" != "Linux" ]; then
  echo "This installer is for Linux only." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [ -f /etc/alpine-release ] || (command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl); then
  echo "Unsupported libc: only glibc Linux builds are published for lexe-opencode." >&2
  exit 1
fi

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
asset="opencode-linux-$arch"
base="https://github.com/$repo/releases/download/$tag"
target="$install_dir/opencode"

mkdir -p "$install_dir"
tmp=$(mktemp -d "$install_dir/.opencode.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

curl -fsSL "$base/$asset" -o "$tmp/$asset"
curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS"
(cd "$tmp" && grep "  $asset$" SHA256SUMS | sha256sum -c -)
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

echo "Installed OpenCode ($tag) to $target. Reopen your terminal or run: exec \"\$SHELL\" -l"
