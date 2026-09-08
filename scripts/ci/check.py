#!/usr/bin/env python3
"""Check only repository source, not downloaded dependencies."""
from pathlib import Path
import subprocess

files = sorted(str(p) for p in Path('.').glob('*.v')) + ['scripts/build.vsh']
subprocess.run(['v', 'fmt', '-verify', *files], check=True)
subprocess.run(['git', 'diff', '--check'], check=True)
for path in Path('scripts').rglob('*.py'):
    compile(path.read_text(), str(path), 'exec')
