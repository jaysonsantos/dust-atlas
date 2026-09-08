#!/usr/bin/env python3
"""Check packaged dust, then detect immediate GUI startup failures."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

executable = Path(sys.argv[1]).resolve()
dust = executable.with_name('dust.exe' if sys.platform == 'win32' else 'dust')
with tempfile.TemporaryDirectory(prefix='atlas package ü ') as temporary:
    fixture = Path(temporary) / 'test.txt'
    fixture.write_text('disk space fixture\n' * 1000)
    result = subprocess.check_output(
        [str(dust), '-j', '-P', '-p', '-o', 'b', '--limit-filesystem', '--', temporary], text=True)
    tree = json.loads(result)
    if not tree['children'] or int(tree['size'].rstrip('B')) <= 0:
        raise SystemExit('Packaged dust did not report the fixture')
    if sys.platform == 'win32':
        # Hosted Windows runners do not provide a suitable interactive OpenGL session.
        sys.exit(0)
    with subprocess.Popen([str(executable), temporary], stdout=subprocess.PIPE, stderr=subprocess.PIPE) as app:
        try:
            stdout, stderr = app.communicate(timeout=8)
        except subprocess.TimeoutExpired:
            app.terminate()
            app.communicate(timeout=10)
        else:
            raise SystemExit(f'GUI exited during startup ({app.returncode}): {stderr.decode(errors="replace")}')
