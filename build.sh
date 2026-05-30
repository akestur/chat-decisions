#!/usr/bin/env bash
# Build chat-decisions.plugin from source.
# Run from anywhere; resolves paths relative to the script's location.

set -e
cd "$(dirname "$0")"

python3 << 'EOF'
import zipfile, os

OUT = 'chat-decisions.plugin'
SKIP_FILES = {'.DS_Store', 'README.md', 'LICENSE', '.gitignore', 'build.sh'}
SKIP_DIRS = {'.git', '__pycache__', '.vscode', '.idea'}

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f in SKIP_FILES or f.endswith('.plugin') or f.endswith('.skill'):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, '.')
            arc = os.path.join('chat-decisions', rel)
            z.write(full, arc)
            print(f'  added: {arc}')

size = os.path.getsize(OUT)
print(f'\nBuilt {OUT} ({size} bytes)')
EOF
