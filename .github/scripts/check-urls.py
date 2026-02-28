#!/usr/bin/env python3
"""Compare new site manifest against production manifest and write a summary."""
import os
from pathlib import Path
from collections import defaultdict

prod = Path('_prod-manifest.txt').read_text().splitlines()
new  = set(Path('_new-manifest.txt').read_text().splitlines())
prod_set = set(prod)

deleted = sorted(prod_set - new)
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


with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as out:
    out.write('## URL check\n')
    if deleted:
        out.write('### :warning: Deleted files (potential broken URLs)\n')
        out.write('```\n')
        for line in collapse(deleted, prod):
            out.write(line + '\n')
        out.write('```\n')
    else:
        out.write('**No files deleted.** :white_check_mark:\n')
    if added:
        out.write('### New files\n')
        out.write('```\n')
        for line in added:
            out.write(line + '\n')
        out.write('```\n')
