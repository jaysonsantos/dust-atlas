#!/usr/bin/env python3
"""Reject references to build-host libraries in a macOS artifact."""
from pathlib import Path
import subprocess
import sys

contents = Path(sys.argv[1])
for path in [contents / 'MacOS/dust-atlas', contents / 'MacOS/dust', *(contents / 'Frameworks').glob('*.dylib')]:
    for line in subprocess.check_output(['otool', '-L', str(path)], text=True).splitlines()[1:]:
        dependency = line.strip().split(' (')[0]
        if not dependency.startswith(('@', '/usr/lib/', '/System/Library/')):
            raise SystemExit(f'External library in {path}: {dependency}')
