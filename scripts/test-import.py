#!/usr/bin/env python3
"""Validate a real desktop conversion and package relationships (standard library)."""
import importlib.util, json, subprocess, tempfile, sys, hashlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
helper = root / 'rust/target/release' / ('one-import.exe' if sys.platform == 'win32' else 'one-import')
fixture = root / 'rust/one-import/tests/fixtures/mit/OneWithFileData.one'
spec = importlib.util.spec_from_file_location('audit', root / 'scripts/audit-package.py')
audit = importlib.util.module_from_spec(spec); spec.loader.exec_module(audit)
with tempfile.TemporaryDirectory() as work:
    output = Path(work) / 'Imported.onbook'
    subprocess.run([str(helper), str(fixture), str(output)], check=True)
    assert audit.check(output) == 1
    report = json.loads((output/'import-report.json').read_text())
    assert report['attachments'] == 1
    media = list((output / 'media').iterdir())
    assert len(media) == 1
    assert hashlib.sha256(media[0].read_bytes()).hexdigest() == '8e99dc44681b8399608f7a181e44d3e41dc36fbacd35a9cfb2d1fc330ac68459'
print('Desktop import package checks pass')
