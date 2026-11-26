$ErrorActionPreference = 'Stop'
$repo = 'Ray-D-Song/lexe-opencode'

$arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
  'X64' { 'x64' }
  'Arm64' { 'arm64' }
  default { throw "Unsupported architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" }
}

if ($env:OPENCODE_VERSION) {
  if ($env:OPENCODE_VERSION -like 'lexe-opencode-v*') {
    $tag = $env:OPENCODE_VERSION
  } elseif ($env:OPENCODE_VERSION -like 'v*') {
    $tag = "lexe-opencode-$($env:OPENCODE_VERSION)"
  } else {
    $tag = "lexe-opencode-v$($env:OPENCODE_VERSION)"
  }
} else {
  $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases?per_page=20" |
    Where-Object { -not $_.draft -and $_.tag_name -like 'lexe-opencode-v*' } |
    Select-Object -First 1
  if (-not $release) {
    throw 'Failed to resolve latest lexe-opencode release tag'
  }
  $tag = $release.tag_name
}

$installDir = if ($env:OPENCODE_INSTALL_DIR) { $env:OPENCODE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\OpenCode' }
$installDir = [IO.Path]::GetFullPath($installDir)
$asset = "opencode-windows-$arch.exe"
$base = "https://github.com/$repo/releases/download/$tag"
$target = Join-Path $installDir 'opencode.exe'

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
$staged = Join-Path $installDir ".opencode.$PID.exe"
$sums = Join-Path $installDir ".opencode.$PID.SHA256SUMS"
try {
  Invoke-WebRequest "$base/$asset" -OutFile $staged
  Invoke-WebRequest "$base/SHA256SUMS" -OutFile $sums
  $expected = ((Get-Content -LiteralPath $sums | Where-Object { $_ -match "  $([regex]::Escape($asset))$" }) -split '\s+')[0]
  if (-not $expected -or (Get-FileHash -Algorithm SHA256 -LiteralPath $staged).Hash -ne $expected.ToUpperInvariant()) {
    throw 'SHA256 verification failed'
  }
  Move-Item -Force -LiteralPath $staged -Destination $target
} finally {
  Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $staged, $sums
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';' | Where-Object { $_ -eq $installDir }).Count -eq 0) {
  [Environment]::SetEnvironmentVariable('Path', (($userPath.TrimEnd(';') + ';' + $installDir).TrimStart(';')), 'User')
}
if (($env:Path -split ';' | Where-Object { $_ -eq $installDir }).Count -eq 0) {
  $env:Path = "$env:Path;$installDir"
}

Write-Host "Installed OpenCode ($tag) to $target. Open a new PowerShell session to use opencode."
