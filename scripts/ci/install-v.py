#!/usr/bin/env python3
"""Install the pinned V release.

The upstream source bootstrap rebuilds V from the moving `vc` snapshot, which
no longer compiles the pinned version. Use the published release archive.
"""
import os
from pathlib import Path
import hashlib
import platform
import subprocess
import urllib.request
import zipfile

VERSION = '0.5.2'
ARCHIVES = {
    ('Linux', 'x86_64'): ('v_linux.zip',
                          '86caf9e70c3342d48ef19eb4f6c47b709f18c90ae86255520d5c29df6b482e23'),
    ('Windows', 'AMD64'): ('v_windows.zip',
                           '5f1d619b6b04a2b54b4ad21826a25bdcba2acf75a941c8f72fc95672b6b064ca'),
    ('Darwin', 'arm64'): ('v_macos_arm64.zip',
                          'e539a8dc3aeea47267f3cf00c25c4f0a364d8037fb13f5379d2a574a7abac8ee'),
    ('Darwin', 'x86_64'): ('v_macos_x86_64.zip',
                           'de19ef02874aec502f091b75e504e4836da38f627ddf7f7f9ecf6e8cf262f9d0'),
}

ROOT = Path(__file__).resolve().parents[2]
host = (platform.system(), platform.machine())
if host not in ARCHIVES:
    raise SystemExit(f'No pinned V archive for {host}')
name, digest = ARCHIVES[host]
target = ROOT / '.ci'
target.mkdir(parents=True, exist_ok=True)
archive = target / name
executable = target / 'v' / ('v.exe' if os.name == 'nt' else 'v')

if not executable.exists():
    url = f'https://github.com/vlang/v/releases/download/{VERSION}/{name}'
    urllib.request.urlretrieve(url, archive)
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit(f'{name} checksum {actual} does not match {digest}')
    with zipfile.ZipFile(archive) as bundle:
        for entry in bundle.infolist():
            path = bundle.extract(entry, target)
            mode = entry.external_attr >> 16
            if mode and os.name != 'nt':
                os.chmod(path, mode)
    archive.unlink()

subprocess.run([str(executable), 'version'], check=True)
root = executable.parent
if 'GITHUB_PATH' in os.environ:
    with open(os.environ['GITHUB_PATH'], 'a') as output:
        output.write(f'{root}\n')
    with open(os.environ['GITHUB_ENV'], 'a') as output:
        output.write(f'VROOT={root}\n')
