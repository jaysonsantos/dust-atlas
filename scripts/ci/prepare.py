#!/usr/bin/env python3
"""Prepare the same patched V modules as the Nix development shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
modules = ROOT / '.ci' / 'modules'
modules.mkdir(parents=True, exist_ok=True)
lock = json.loads((ROOT / 'flake.lock').read_text())
for name in ('gui', 'vglyph'):
    source = lock['nodes'][name]['locked']
    target = modules / name
    if target.exists():
        shutil.rmtree(target)
    subprocess.run(['git', 'clone', '--config', 'core.autocrlf=false', '--no-checkout',
                    f"https://github.com/{source['owner']}/{source['repo']}.git",
                    str(target)], check=True)
    subprocess.run(['git', '-C', str(target), 'checkout', '--detach', source['rev']], check=True)
    for patch in sorted((ROOT / 'patches').glob(f'{name}-*.patch')):
        subprocess.run(['git', '-C', str(target), 'apply', '--unidiff-zero', str(patch)], check=True)

vroot = Path(os.environ['VROOT'])
json2 = modules / 'json2'
if json2.exists():
    shutil.rmtree(json2)
shutil.copytree(vroot / 'vlib' / 'x' / 'json2', json2)
flags = f'-path {modules}|@vlib|@vmodules -no-parallel'
if os.name == 'nt':
    flags += ' -cc msvc'
if os.environ.get('RUNNER_OS') == 'macOS':
    flags += ' -d use_bundled_libgc -cflags -DLARGE_CONFIG'
with open(os.environ['GITHUB_ENV'], 'a') as output:
    output.write(f'VFLAGS={flags}\n')
with open(os.environ['GITHUB_PATH'], 'a') as output:
    output.write(str(ROOT / '.ci' / 'dust' / 'bin') + '\n')
