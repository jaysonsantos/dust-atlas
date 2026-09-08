$ErrorActionPreference = 'Stop'
$root = $env:VCPKG_INSTALLATION_ROOT
if (-not $root) { throw 'VCPKG_INSTALLATION_ROOT is required' }
& "$root/vcpkg.exe" install pango:x64-windows freetype:x64-windows pkgconf:x64-windows
if ($LASTEXITCODE -ne 0) { throw 'vcpkg install failed' }
$prefix = "$root/installed/x64-windows"
"VCPKG_PREFIX=$prefix" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
"PKG_CONFIG_PATH=$prefix/lib/pkgconfig;$prefix/share/pkgconfig" | Out-File -Append -Encoding utf8 $env:GITHUB_ENV
"$prefix/bin" | Out-File -Append -Encoding utf8 $env:GITHUB_PATH
$pkgconf = Get-ChildItem "$root/installed" -Filter pkgconf.exe -Recurse | Select-Object -First 1
if (-not $pkgconf) { throw 'vcpkg did not install pkgconf' }
$shim = Join-Path $env:RUNNER_TEMP 'atlas-pkgconfig'
New-Item -ItemType Directory -Force $shim | Out-Null
@('@echo off', ('"' + $pkgconf.FullName + '" %*')) | Set-Content "$shim/pkg-config.cmd" -Encoding ascii
$shim | Out-File -Append -Encoding utf8 $env:GITHUB_PATH
