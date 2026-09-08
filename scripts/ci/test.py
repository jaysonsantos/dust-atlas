#!/usr/bin/env python3
"""Run project tests without traversing downloaded V modules."""
import os
from pathlib import Path
import subprocess

os.environ['VJOBS'] = '1'
subprocess.run(['v', 'test', *sorted(str(p) for p in Path('.').glob('*_test.v'))], check=True)
