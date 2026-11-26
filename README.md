# lexe-opencode

A fork of [OpenCode](https://github.com/anomalyco/opencode) compiled and distributed as standalone executables using [Lexe](https://github.com/Ray-D-Song/lexe).

The CLI is installed as `loc` so it can coexist cleanly with upstream `opencode`.

## Install

```shell
# macOS (Apple Silicon)
curl -fsSL https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/install-macos.sh | sh

# Linux (x64 / arm64, glibc)
curl -fsSL https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/install-linux.sh | sh
```

```powershell
# Windows PowerShell (x64 / arm64)
irm https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/install-windows.ps1 | iex
```

After installation, run:

```shell
loc --version
loc
```

### Options

- `OPENCODE_VERSION`: Install a specific release version or tag (for example `2.4.1-lexe.0.1.6` or `lexe-opencode-v2.4.1-lexe.0.1.6`). Defaults to the latest published `lexe-opencode-v*` release.
- `OPENCODE_INSTALL_DIR`: Override the installation directory (defaults to `$HOME/.local/bin` on macOS/Linux and `%LOCALAPPDATA%\Programs\OpenCode` on Windows).

### Supported Platforms

| Platform | Asset |
| --- | --- |
| macOS (Apple Silicon) | `opencode-darwin-arm64` |
| Linux (x64, glibc) | `opencode-linux-x64` |
| Linux (arm64, glibc) | `opencode-linux-arm64` |
| Windows (x64) | `opencode-windows-x64.exe` |
| Windows (arm64) | `opencode-windows-arm64.exe` |

## Uninstall

```shell
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/uninstall.sh | sh

# macOS / Linux (also remove config, data, state, and cache)
curl -fsSL https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/uninstall.sh | sh -s -- --purge
```

```powershell
# Windows PowerShell
irm https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/uninstall-windows.ps1 | iex

# Windows PowerShell (also remove config and data)
$env:OPENCODE_PURGE='1'; irm https://raw.githubusercontent.com/Ray-D-Song/lexe-opencode/dev/uninstall-windows.ps1 | iex
```

## Upstream & License

This project is forked from [anomalyco/opencode](https://github.com/anomalyco/opencode) and packaged with [Ray-D-Song/lexe](https://github.com/Ray-D-Song/lexe). See [LICENSE](LICENSE) for license details.
