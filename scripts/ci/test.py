#!/usr/bin/env python3
"""Run project tests without traversing downloaded V modules."""
import os
import subprocess

import sources

os.environ['VJOBS'] = '1'
subprocess.run(['v', 'test', *[str(p) for p in sources.tests()]], check=True)
