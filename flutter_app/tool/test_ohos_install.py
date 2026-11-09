#!/usr/bin/env python3
"""Execute the real installer against a fake hdc, retaining real HAP checks."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

from test_check_ohos_hap import package


def main():
    script = Path(__file__).with_name('ohos_install.sh')
    with tempfile.TemporaryDirectory(prefix='shuying-install-test-') as directory:
        folder = Path(directory)
        hap = folder / 'candidate.hap'
        hap.write_bytes(package().getvalue())
        log = folder / 'calls.jsonl'
        hdc = folder / 'hdc'
        hdc.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['FAKE_HDC_LOG'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:] == ['list', 'targets']:
    print(os.environ.get('FAKE_HDC_TARGETS', 'device-first\\ndevice-second'))
else:
    print(os.environ['FAKE_HDC_OUTPUT'])
    sys.exit(int(os.environ.get('FAKE_HDC_STATUS', '0')))
''')
        hdc.chmod(0o755)

        def run(output, status=0, target=None, path=hap):
            log.write_text('')
            env = dict(os.environ, HDC=str(hdc), FAKE_HDC_LOG=str(log),
                       FAKE_HDC_OUTPUT=output, FAKE_HDC_STATUS=str(status))
            env.pop('HDC_TARGET', None)
            if target is not None:
                env['HDC_TARGET'] = target
            result = subprocess.run(['bash', str(script), str(path)], env=env,
                                    text=True, encoding='utf-8', errors='replace',
                                    capture_output=True, timeout=15)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            return result, calls

        success = 'install bundle successfully.'
        for output, status in [
            ('msg:error: failed to install bundle. code:9568332 '
             'error: install sign info inconsistent.', 0),
            ('connection timed out', 0),
            ('', 0),
            (success, 1),
            (success + '\nerror: connection lost', 0),
            (success + '\n[Fail] device offline', 0),
            (success + '\nconnection timed out', 0),
        ]:
            result, calls = run(output, status)
            assert result.returncode != 0, (output, status, result)
            assert '==> 完成' not in result.stdout
            assert len(calls) == 2

        result, calls = run(success)
        assert result.returncode == 0, result.stderr
        assert '==> 完成' in result.stdout
        assert calls[-1] == ['-t', 'device-first', 'install', '-r', str(hap)]

        result, calls = run(success, target='device-second')
        assert result.returncode == 0, result.stderr
        assert calls[-1][1] == 'device-second'

        result, calls = run(success, target='unconnected-device')
        assert result.returncode != 0
        assert calls == [['list', 'targets']]

        invalid = folder / 'jit.hap'
        invalid.write_bytes(package(jit=True).getvalue())
        result, calls = run(success, path=invalid)
        assert result.returncode != 0
        assert calls == [], 'preflight must reject JIT before calling hdc'
        print('通过：假零退出、失败/不明输出拒绝，明确成功及指定目标通过，AOT 前检保留。')


if __name__ == '__main__':
    main()
