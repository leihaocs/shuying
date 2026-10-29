#!/usr/bin/env python3
"""核对实际业务构建模式，避免把调试签名误当成 debug/JIT 业务包。"""
import argparse
import io
import json
import re
import zipfile


def check_hap(package, version_name='1.0.0', version_code=6):
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        if 'module.json' not in names:
            haps = [name for name in names if name.endswith('.hap')]
            if not haps:
                raise ValueError('包中没有 HAP')
            return [result for name in haps for result in check_hap(
                io.BytesIO(archive.read(name)), version_name, version_code)]
        metadata = json.loads(archive.read('module.json'))
        app = metadata['app']
        if (app['bundleName'], app['versionName'], app['versionCode']) != (
                'com.bookmovie.revisit.app.hm', version_name, version_code):
            raise ValueError('包名或实际版本与当前候选不一致')
        if metadata['module']['deviceTypes'] != ['phone']:
            raise ValueError('设备类型必须为 phone')
        libraries = [name for name in names if name.endswith('/libapp.so')]
        if app.get('debug', False) or not libraries or any(name.endswith((
                '/kernel_blob.bin', '/vm_snapshot_data', '/isolate_snapshot_data'))
                for name in names):
            raise ValueError('拒绝 debug/JIT 业务包；请用 release.sh ohos-test 构建')
        versions = set()
        for name in libraries:
            data = archive.read(name)
            header = data.find(bytes.fromhex('f5f5dcdc'))
            version = data[header + 20:header + 52] if header >= 0 else b''
            engine = archive.read(name.rsplit('/', 1)[0] + '/libflutter.so')
            if not re.fullmatch(b'[0-9a-f]{32}', version) or version not in engine:
                raise ValueError('Dart 业务快照与 Flutter 引擎版本不匹配')
            versions.add(version.decode())
        return [{'version': f'{version_name}({version_code})',
                 'buildMode': 'release/AOT', 'snapshotVersions': sorted(versions)}]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package')
    parser.add_argument('version_name', nargs='?', default='1.0.0')
    parser.add_argument('version_code', nargs='?', type=int, default=6)
    args = parser.parse_args()
    try:
        result = check_hap(args.package, args.version_name, args.version_code)
    except (ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f'鸿蒙包检查失败：{error}\n')
    print('鸿蒙包检查通过：' + json.dumps(result, ensure_ascii=False))
