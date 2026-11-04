#!/usr/bin/env python3
"""Extract a conversation export into a new private staging directory.

Validate every entry before writing. Never restore archive symlinks, overwrite
an earlier import, or leave a successful-looking partial import after failure.
"""
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import tempfile
import zipfile


def stage(archive, vault):
    root = Path(vault).resolve(strict=True)
    parent = root / '.import-staging'
    if parent.is_symlink():
        raise ValueError('.import-staging must not be a symlink')
    with zipfile.ZipFile(archive) as source:
        names = set()
        for entry in source.infolist():
            path = PurePosixPath(entry.filename)
            if (path.is_absolute() or '..' in path.parts or '\\' in entry.filename
                    or not path.parts or ':' in path.parts[0]
                    or any(ord(c) < 32 for c in entry.filename)):
                raise ValueError('unsafe archive path')
            mode = entry.external_attr >> 16
            if stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError('archive links and special files are not supported')
            normalized = str(path).casefold()
            if normalized in names:
                raise ValueError('duplicate archive path')
            names.add(normalized)
        # Refuse archives larger than the space available, without extracting.
        total = sum(entry.file_size for entry in source.infolist())
        if total > shutil.disk_usage(root).free:
            raise ValueError('insufficient space for the uncompressed export')
        parent.mkdir(mode=0o700, exist_ok=True)
        destination = Path(tempfile.mkdtemp(prefix='claude-', dir=parent))
        try:
            for entry in source.infolist():
                target = destination.joinpath(*PurePosixPath(entry.filename).parts)
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.open(entry) as src, target.open('xb') as dst:
                    shutil.copyfileobj(src, dst)
                target.chmod(0o600)
        except BaseException:
            shutil.rmtree(destination)
            raise
    return destination


if __name__ == '__main__':
    try:
        print(stage(sys.argv[1], sys.argv[2]))
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, IndexError) as exc:
        print(f'Cannot stage export: {exc}', file=sys.stderr)
        sys.exit(1)
