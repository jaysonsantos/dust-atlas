#!/usr/bin/env python3
"""Collect installed dependency notices without changing source notices."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

output = Path('.ci/notices')
output.mkdir(parents=True, exist_ok=True)

def collect(root, group):
    for source in root.rglob('*'):
        if source.is_file() and source.name.lower().startswith(('license', 'copying', 'copyright')):
            destination = output / group / source.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)

cargo = Path(os.environ.get('CARGO_HOME', Path.home() / '.cargo'))
collect(cargo / 'registry/src', 'rust')
if sys.platform == 'darwin':
    cellar = Path(subprocess.check_output(['brew', '--cellar'], text=True).strip())
    collect(cellar, 'homebrew')
    metadata = subprocess.check_output(['brew', 'info', '--json=v2', '--installed'], text=True)
    (output / 'homebrew-packages.json').write_text(metadata)
elif sys.platform == 'linux':
    collect(Path('/usr/share/doc'), 'linux')
if not list((output / 'rust').rglob('*du-dust*')):
    raise SystemExit('The dust source notice is missing')
