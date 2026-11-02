#!/usr/bin/env bash
# Verifica arquivos rastreados e não ignorados sem exibir seu conteúdo.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import subprocess
import sys
root = Path(sys.argv[1])
files = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-co', '--exclude-standard', '-z']).split(b'\0')
failed = []
patterns = [
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
    r'tskey-[A-Za-z0-9-]{10,}',
    r'gh[pousr]_[A-Za-z0-9]{30,}',
    r'sk-[A-Za-z0-9]{20,}',
    r'\b100\.(?:6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.\d+\.\d+\b',
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
]
count = 0
for entry in files:
    if not entry:
        continue
    path = root / entry.decode()
    if not path.is_file():
        continue
    count += 1
    name = path.name
    if name.endswith('.tfvars') or 'tfstate' in name or name == 'hosts.yml' or name.startswith('.env'):
        failed.append(str(path.relative_to(root)) + ': forbidden file')
    text = path.read_text(errors='replace').replace('100.100.100.100', '')
    if any(re.search(pattern, text) for pattern in patterns):
        failed.append(str(path.relative_to(root)) + ': possible secret or real overlay IP')
if not count:
    sys.exit('INCONCLUSIVE: no files inspected')
if failed:
    print('\n'.join(failed))
    sys.exit(1)
print(f'PASS: safety gate ({count} files)')
PY
