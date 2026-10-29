#!/usr/bin/env python3
"""不依赖 SDK 的构建模式/快照回归检查。"""
import io
import json
import zipfile

from check_ohos_hap import check_hap


def package(debug=False, jit=False, engine=b'1' * 32, version_code=6):
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w') as archive:
        archive.writestr('module.json', json.dumps({
            'app': {'bundleName': 'com.bookmovie.revisit.app.hm',
                    'versionName': '1.0.0', 'versionCode': version_code, 'debug': debug},
            'module': {'deviceTypes': ['phone']}}))
        archive.writestr('libs/arm64-v8a/libapp.so',
                         bytes.fromhex('f5f5dcdc') + bytes(16) + b'1' * 32)
        archive.writestr('libs/arm64-v8a/libflutter.so', engine)
        if jit:
            archive.writestr('resources/rawfile/flutter_assets/kernel_blob.bin', b'jit')
    data.seek(0)
    return data


if __name__ == '__main__':
    assert check_hap(package())[0]['buildMode'] == 'release/AOT'
    for blob, reason in [(package(debug=True), 'debug/JIT'),
                         (package(jit=True), 'debug/JIT'),
                         (package(engine=b'2' * 32), '快照'),
                         (package(version_code=7), '版本')]:
        try:
            check_hap(blob)
        except ValueError as error:
            assert reason in str(error)
        else:
            raise AssertionError('错误包未被拒绝')
    app = io.BytesIO()
    with zipfile.ZipFile(app, 'w') as archive:
        archive.writestr('entry.hap', package().getvalue())
    app.seek(0)
    assert check_hap(app)[0]['version'] == '1.0.0(6)'
    print('通过：release HAP/APP 放行，debug/JIT、错快照与误升号拒绝。')
