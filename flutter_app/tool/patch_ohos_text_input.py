#!/usr/bin/env python3
"""Repair the missing IME delete handlers in the project's Flutter 3.7 OHOS SDK.

Run --self-test first (read only), then apply before `flutter build app`:
  python3 tool/patch_ohos_text_input.py --sdk ~/flutter_ohos --self-test
  python3 tool/patch_ohos_text_input.py --sdk ~/flutter_ohos
  python3 tool/patch_ohos_text_input.py --sdk ~/flutter_ohos --check

Each original HAR is preserved as flutter.har.before-shuying-ime-fix. The Flutter
build copies its SDK HAR over ohos/har/flutter.har, so patching only that generated
project file would not survive the next build. This script refuses an unfamiliar
upstream implementation; reassess/remove the patch when upgrading Flutter.
"""

import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

MARKER = '// shuying-ime-delete-fix-v1'
EDITING = 'package/src/main/ets/plugin/editing/'

DELETE_METHOD = '''  // shuying-ime-delete-fix-v1
  handleDeleteTextEvent(length: number, left: boolean): void {
    if (!Number.isFinite(length) || length < 1 ||
      this.mSelectionStartCache < 0 || this.mSelectionEndCache < 0) return;
    const text = this.mStringCache;
    let start = Math.max(0, Math.min(text.length,
      Math.min(this.mSelectionStartCache, this.mSelectionEndCache)));
    let end = Math.max(0, Math.min(text.length,
      Math.max(this.mSelectionStartCache, this.mSelectionEndCache)));
    if (start == end) {
      // Honor the requested text span, expanding to Flutter's emoji boundaries.
      // Counting `length` emoji would over-delete when an IME requests two UTF-16
      // units for a single supplementary character.
      if (left) {
        const target = Math.max(0, start - Math.floor(length));
        while (start > target) start = FlutterTextUtils.getOffsetBefore(text, start);
      } else {
        const target = Math.min(text.length, end + Math.floor(length));
        while (end < target) end = FlutterTextUtils.getOffsetAfter(text, end);
      }
    }
    // A supplied selection must not leave half of a surrogate pair behind.
    if (start > 0 && start < text.length &&
      text.charCodeAt(start) >= 0xDC00 && text.charCodeAt(start) <= 0xDFFF &&
      text.charCodeAt(start - 1) >= 0xD800 && text.charCodeAt(start - 1) <= 0xDBFF) start--;
    if (end > 0 && end < text.length &&
      text.charCodeAt(end) >= 0xDC00 && text.charCodeAt(end) <= 0xDFFF &&
      text.charCodeAt(end - 1) >= 0xD800 && text.charCodeAt(end - 1) <= 0xDBFF) end++;
    if (start == end) return;
    const oldComposingStart = this.mComposingStartCache;
    const oldComposingEnd = this.mComposingEndCache;
    if (oldComposingStart >= 0 && oldComposingEnd > oldComposingStart) {
      this.mComposingStartCache = oldComposingStart <= start ? oldComposingStart :
        Math.max(start, oldComposingStart - (end - start));
      this.mComposingEndCache = oldComposingEnd <= start ? oldComposingEnd :
        Math.max(start, oldComposingEnd - (end - start));
      if (this.mComposingStartCache == this.mComposingEndCache) {
        this.mComposingStartCache = -1;
        this.mComposingEndCache = -1;
      }
    }
    this.mStringCache = text.substring(0, start) + text.substring(end);
    this.mSelectionStartCache = start;
    this.mSelectionEndCache = start;
    this.mBatchTextEditingDeltas.add(new TextEditingDelta(text, start, start,
      this.mComposingStartCache, this.mComposingEndCache, start, end, ""));
    this.notifyListenersIfNeeded(true, true,
      oldComposingStart != this.mComposingStartCache || oldComposingEnd != this.mComposingEndCache);
  }

'''


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('Unrecognized OHOS Flutter source; expected exactly one: ' + before[:90])
    return source.replace(before, after, 1)


def patch_sources(files):
    plugin_name = EDITING + 'TextInputPlugin.ets'
    state_name = EDITING + 'ListenableEditingState.ets'
    utils_name = EDITING + 'TextUtils.ets'
    plugin, state = files[plugin_name].decode(), files[state_name].decode()
    utils = files[utils_name].decode()
    if all(MARKER in source for source in (plugin, state, utils)):
        return files
    if any(MARKER in source for source in (plugin, state, utils)) or "on('deleteLeft'" in plugin:
        raise ValueError('Partial patch or changed upstream delete handling; inspect before applying')
    plugin = replace_once(plugin, "      this.inputMethodController.on('sendFunctionKey', this.sendFunctionKeyCallback)",
        "      " + MARKER + "\n"
        "      this.inputMethodController.on('deleteLeft', this.deleteLeftCallback);\n"
        "      this.inputMethodController.on('deleteRight', this.deleteRightCallback);\n"
        "      this.inputMethodController.on('sendFunctionKey', this.sendFunctionKeyCallback)")
    plugin = replace_once(plugin, '  private sendFunctionKeyCallback =', '''  private deleteLeftCallback = (length: number) => {
    this.mEditable.handleDeleteTextEvent(length, true);
  }

  private deleteRightCallback = (length: number) => {
    this.mEditable.handleDeleteTextEvent(length, false);
  }

  private sendFunctionKeyCallback =''')
    plugin = replace_once(plugin, "    this.inputMethodController?.off('insertText', this.insertTextCallback);",
        "    this.inputMethodController?.off('insertText', this.insertTextCallback);\n"
        "    this.inputMethodController?.off('deleteLeft', this.deleteLeftCallback);\n"
        "    this.inputMethodController?.off('deleteRight', this.deleteRightCallback);")
    plugin = replace_once(plugin, '''        editable.getComposingStart(), editable.getComposingEnd())
    }

  }''', '''        editable.getComposingStart(), editable.getComposingEnd())
    }
    this.mTextInputHandler.updateSelection();
  }''')
    plugin = replace_once(plugin, '  clearClient(): void {', '''  updateSelection(): void {
    try {
      this.inputMethodController.changeSelection(this.mEditable.getStringCache(),
        this.mEditable.getSelectionStart(), this.mEditable.getSelectionEnd()).catch((err: Error) => {
          Log.e(TextInputMethodHandlerImpl.TAG, "Failed to update selection: " + JSON.stringify(err));
        });
    } catch (err) {
      Log.e(TextInputMethodHandlerImpl.TAG, "Failed to update selection: " + JSON.stringify(err));
    }
  }

  clearClient(): void {''')
    state = replace_once(state, '  handleInsertTextEvent(text: string): void {',
        DELETE_METHOD + '  handleInsertTextEvent(text: string): void {')
    state = replace_once(state, '    this.setStringCache(state.text);', '''    this.setStringCache(state.text);
    this.setComposingStart(state.hasComposing() ? state.composingStart : -1);
    this.setComposingEnd(state.hasComposing() ? state.composingEnd : -1);''')
    state = replace_once(state, '''    Log.d(TAG, "handleSelectByRange start: " + range.start +" end: " + range.end);''', '''    this.mSelectionStartCache = Math.max(0, Math.min(this.mStringCache.length, range.start));
    this.mSelectionEndCache = Math.max(0, Math.min(this.mStringCache.length, range.end));
    this.mBatchTextEditingDeltas.add(new TextEditingDelta(this.mStringCache,
      this.mSelectionStartCache, this.mSelectionEndCache,
      this.mComposingStartCache, this.mComposingEndCache));
    this.notifyListenersIfNeeded(false, true, false);''')
    utils = replace_once(utils, '''    if (FlutterTextUtils.isKeycapBase(codePoint)) {
      nextCharCount += FlutterTextUtils.charCount(codePoint);
    }
    if (codePoint == COMBINING_ENCLOSING_KEYCAP) {
      codePoint = FlutterTextUtils.codePointBefore(text, nextOffset);
      nextOffset += FlutterTextUtils.charCount(codePoint);
      if (nextOffset < len && FlutterTextUtils.isVariationSelector(codePoint)) {
        let tmpCodePoint: number = FlutterTextUtils.codePointAt(text, nextOffset);
        if (FlutterTextUtils.isKeycapBase(tmpCodePoint)) {
          nextCharCount += FlutterTextUtils.charCount(codePoint) + FlutterTextUtils.charCount(tmpCodePoint);
        }
      } else if (FlutterTextUtils.isKeycapBase(codePoint)) {
        nextCharCount += FlutterTextUtils.charCount(codePoint);
      }
      return offset + nextCharCount;
    }''', '''    // shuying-ime-delete-fix-v1: ordinary digits are not two-unit keycaps.
    if (FlutterTextUtils.isKeycapBase(codePoint)) {
      let keycapOffset = nextOffset;
      if (keycapOffset < len &&
        FlutterTextUtils.isVariationSelector(FlutterTextUtils.codePointAt(text, keycapOffset))) {
        keycapOffset += FlutterTextUtils.charCount(FlutterTextUtils.codePointAt(text, keycapOffset));
      }
      if (keycapOffset < len &&
        FlutterTextUtils.codePointAt(text, keycapOffset) == COMBINING_ENCLOSING_KEYCAP) {
        return keycapOffset + 1;
      }
      return nextOffset;
    }''')
    utils = replace_once(utils, '''          if (FlutterTextUtils.isVariationSelector(codePoint)) {
            nextCharCount += lastSeenVariantSelectorCharCount + FlutterTextUtils.charCount(codePoint);
            break;
          }''', '''          if (FlutterTextUtils.isVariationSelector(codePoint)) {
            nextCharCount += lastSeenVariantSelectorCharCount + FlutterTextUtils.charCount(codePoint);
            if (nextOffset >= len) break;
            codePoint = FlutterTextUtils.codePointAt(text, nextOffset);
            nextOffset += FlutterTextUtils.charCount(codePoint);
          }''')
    return dict(files, **{plugin_name: plugin.encode(), state_name: state.encode(), utils_name: utils.encode()})


def read_har(path):
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        files = {m.name: archive.extractfile(m).read() for m in members if m.isfile()}
    return members, files


def patch_har(path, check=False):
    members, files = read_har(path)
    patched = patch_sources(files)
    changed = patched != files
    print(('NEEDS PATCH ' if check and changed else 'PATCH ' if changed else 'OK ') + str(path))
    if check:
        return not changed
    if not changed:
        return True
    backup = path.with_name(path.name + '.before-shuying-ime-fix')
    if not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix='.har', delete=False) as temp:
        temp_path = Path(temp.name)
    try:
        with tarfile.open(temp_path, 'w:gz') as archive:
            for member in members:
                data = patched.get(member.name)
                if data is not None:
                    member.size = len(data)
                archive.addfile(member, io.BytesIO(data) if data is not None else None)
        temp_path.chmod(path.stat().st_mode)
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)
    return True


def self_test(path):
    _, files = read_har(path)
    files = patch_sources(files)
    assert patch_sources(files) == files, 'Patch must be idempotent'
    sources = {Path(name).stem: data.decode() for name, data in files.items()
               if name in [EDITING + s + '.ets' for s in
                           ('TextInputPlugin', 'ListenableEditingState', 'TextUtils', 'TextEditingDelta')]}
    harness = Path(__file__).with_name('test_ohos_text_input.cjs')
    subprocess.run(['node', str(harness)], input=json.dumps(sources), text=True, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'flutter_ohos')
    parser.add_argument('--check', action='store_true', help='Check only; exit 1 if any HAR needs patching')
    parser.add_argument('--self-test', action='store_true', help='Exercise patched SDK source without writing any HAR')
    args = parser.parse_args()
    archives = sorted((args.sdk / 'bin/cache/artifacts/engine').glob('ohos*/flutter.har'))
    if not archives:
        parser.error('No cached OHOS engine HAR files found under ' + str(args.sdk))
    if args.self_test:
        for archive in archives:
            self_test(archive)
        return
    # Validate every variant before making any change.
    for archive in archives:
        patch_sources(read_har(archive)[1])
    results = [patch_har(archive, args.check) for archive in archives]
    raise SystemExit(0 if all(results) else 1)


if __name__ == '__main__':
    main()
