#!/usr/bin/env python3
"""Compare new site manifest against production manifest and write a summary."""
import os
from pathlib import Path
from collections import defaultdict

prod = Path('_prod-manifest.txt').read_text().splitlines()
new  = set(Path('_new-manifest.txt').read_text().splitlines())
prod_set = set(prod)

# Load no-delete list: paths that are intentionally kept on the server
# and should not be treated as "deleted" in the diff.
_no_delete_file = Path(__file__).parent.parent / 'deploy-no-delete.txt'
_no_delete_prefixes = []
if _no_delete_file.exists():
    for _line in _no_delete_file.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith('#'):
            _no_delete_prefixes.append(_line.rstrip('/') + '/')

def _is_protected(path):
    return any(('/' + path + '/').startswith('/' + p) for p in _no_delete_prefixes)

deleted = sorted(f for f in prod_set - new if not _is_protected(f))
added   = sorted(new - prod_set)


def collapse(files, all_files):
    """Replace fully-deleted directories with a single dir/ entry."""
    if not files:
        return []
    file_set = set(files)
    dir_files = defaultdict(set)
    for f in all_files:
        for parent in Path(f).parents:
            s = str(parent)
            if s != '.':
                dir_files[s].add(f)
    covered = set()
    result  = []
    for d in sorted(dir_files, key=lambda x: len(Path(x).parts)):
        in_dir = dir_files[d]
        if in_dir and in_dir <= file_set and not (in_dir & covered):
            result.append(d + '/')
            covered |= in_dir
    for f in sorted(files):
        if f not in covered:
            result.append(f)
    return sorted(result)


lines = []
lines.append('## URL check\n')
if deleted:
    lines.append('### :warning: Deleted files (potential broken URLs)\n')
    lines.append('```\n')
    for line in collapse(deleted, prod):
        lines.append(line + '\n')
    lines.append('```\n')
else:
    lines.append('**No files deleted.** :white_check_mark:\n')
if added:
    lines.append('### New files\n')
    lines.append('```\n')
    for line in added:
        lines.append(line + '\n')
    lines.append('```\n')

content = ''.join(lines)
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as f:
    f.write(content)
with open('_url-check-summary.md', 'w') as f:
    f.write(content)
