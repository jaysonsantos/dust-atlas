$ErrorActionPreference = 'Stop'
$dest = 'dist/Dust Atlas'
New-Item -ItemType Directory -Force "$dest/licenses" | Out-Null
Copy-Item bin/dust-atlas.exe $dest
Copy-Item assets/fonts-windows.conf "$dest/fonts.conf"
Copy-Item .ci/dust/bin/dust.exe $dest
Copy-Item "$env:VCPKG_PREFIX/bin/*.dll" $dest
Copy-Item LICENSE,THIRD_PARTY.md $dest
Copy-Item licenses/*.txt "$dest/licenses"
Copy-Item -Recurse .ci/notices "$dest/licenses"
Get-ChildItem "$env:VCPKG_PREFIX/share" -Filter copyright -Recurse | ForEach-Object {
    Copy-Item $_.FullName "$dest/licenses/$($_.Directory.Name).txt"
}
# Include the MSVC runtime beside the executable for machines without Visual Studio.
$crt = Get-ChildItem "$env:VCToolsRedistDir/x64" -Directory -Filter '*.CRT' | Select-Object -First 1
if (-not $crt) { throw 'MSVC runtime directory is missing' }
Copy-Item "$($crt.FullName)/*.dll" $dest
v run scripts/ci/smoke.vsh "$dest/dust-atlas.exe"
if ($LASTEXITCODE -ne 0) { throw 'Packaged dust check failed' }
Compress-Archive -Path $dest -DestinationPath dist/Dust-Atlas-windows-x64.zip -Force
