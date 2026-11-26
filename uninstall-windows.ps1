$ErrorActionPreference = 'Stop'

$installDir = if ($env:OPENCODE_INSTALL_DIR) { $env:OPENCODE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\OpenCode' }
$installDir = [IO.Path]::GetFullPath($installDir)
$target = Join-Path $installDir 'loc.exe'

if (Test-Path -LiteralPath $target) {
  Remove-Item -Force -LiteralPath $target
  Write-Host "Removed $target"
} else {
  Write-Host "Binary not found at $target"
}

if ((Test-Path -LiteralPath $installDir) -and ((Get-ChildItem -Force -LiteralPath $installDir | Measure-Object).Count -eq 0)) {
  Remove-Item -Force -LiteralPath $installDir
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
  $filtered = ($userPath -split ';' | Where-Object { $_ -and $_ -ne $installDir }) -join ';'
  if ($filtered -ne $userPath) {
    [Environment]::SetEnvironmentVariable('Path', $filtered, 'User')
    Write-Host "Removed $installDir from User PATH"
  }
}

if ($env:OPENCODE_PURGE -eq '1' -or ($args -contains '--purge')) {
  foreach ($dir in @(
    (Join-Path $env:USERPROFILE '.config\opencode'),
    (Join-Path $env:LOCALAPPDATA 'opencode'),
    (Join-Path $env:APPDATA 'opencode')
  )) {
    if (Test-Path -LiteralPath $dir) {
      Remove-Item -Recurse -Force -LiteralPath $dir
    }
  }
  Write-Host 'Purged OpenCode config and data directories.'
} else {
  Write-Host 'Uninstalled OpenCode. Config and data directories were preserved (set $env:OPENCODE_PURGE=1 to remove them).'
}
