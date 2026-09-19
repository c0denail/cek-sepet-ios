#!/usr/bin/env python3
"""Run the sibling Go API's real handlers with its test memory store. No .env copied."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
backends = [p for p in root.parent.iterdir() if (p / 'go.mod').exists()]
if len(backends) != 1:
    raise SystemExit('Expected one sibling Go backend directory.')
with tempfile.TemporaryDirectory(prefix='ceksepet-ios-api-') as temporary:
    target = Path(temporary)
    backend = backends[0]
    for name in ('go.mod', 'go.sum'):
        shutil.copy2(backend / name, target / name)
    shutil.copytree(backend / 'internal', target / 'internal')
    shutil.copy2(root / 'TestSupport/ios_fixture_test.go', target / 'internal/httpapi/ios_fixture_test.go')
    environment = os.environ.copy()
    environment['CEKSEPET_IOS_FIXTURE'] = '1'
    environment.pop('MONGODB_TEST_URI', None)
    process = subprocess.Popen(['go', 'test', '-v', '-run', '^TestIOSFixtureServer$', '-count=1', '-timeout=2h', './internal/httpapi'], cwd=target, env=environment, start_new_session=True)
    try:
        process.wait()
    except KeyboardInterrupt:
        import signal
        os.killpg(process.pid, signal.SIGTERM)
        process.wait()
