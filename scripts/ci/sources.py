#!/usr/bin/env python3
"""Locate repository V sources, without downloaded dependencies or build output."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP = {'bin', 'dist', 'ui-fixture'}


def _walk(directory):
    for entry in sorted(directory.iterdir()):
        if entry.is_dir():
            if entry.name.startswith('.') or entry.name in SKIP:
                continue
            yield from _walk(entry)
        elif entry.suffix == '.v':
            yield entry


def sources():
    """Return every repository .v file, tests included."""
    return [p.relative_to(ROOT) for p in _walk(ROOT)]


def tests():
    """Return every repository _test.v file."""
    return [p for p in sources() if p.name.endswith('_test.v')]
