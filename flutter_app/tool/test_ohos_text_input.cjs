// Run via patch_ohos_text_input.py --self-test. Executes the actual patched HAR
// classes; only OHOS platform services are stubbed, not the editing algorithms.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const tsPath = process.env.OHOS_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript/lib/typescript.js';
const ts = require(tsPath);
const sources = JSON.parse(fs.readFileSync(0, 'utf8'));

class ArrayList extends Array {
  add(value) { this.push(value); }
  clear() { this.length = 0; }
  isEmpty() { return this.length === 0; }
  remove(value) { const i = this.indexOf(value); if (i >= 0) this.splice(i, 1); }
}
const events = new Map();
let selectionUpdates = 0;
const controller = {
  on(type, callback) { events.set(type, callback); },
  off(type, callback) { if (events.get(type) === callback) events.delete(type); },
  changeSelection() { selectionUpdates++; return Promise.resolve(); },
};
const inputMethod = { getController: () => controller, KeyboardStatus: { HIDE: 0, SHOW: 1 } };
const log = { d() {}, e() {} };
const flutterNapi = {
  unicodeIsEmoji: cp => /\p{Emoji}/u.test(String.fromCodePoint(cp)),
  unicodeIsEmojiModifier: cp => /\p{Emoji_Modifier}/u.test(String.fromCodePoint(cp)),
  unicodeIsEmojiModifierBase: cp => /\p{Emoji_Modifier_Base}/u.test(String.fromCodePoint(cp)),
  unicodeIsVariationSelector: cp => /\p{Variation_Selector}/u.test(String.fromCodePoint(cp)),
  unicodeIsRegionalIndicatorSymbol: cp => /\p{Regional_Indicator}/u.test(String.fromCodePoint(cp)),
};
const classes = {};
function load(name) {
  const code = ts.transpileModule(sources[name], {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText;
  const exports = {};
  function sdkRequire(path) {
    if (path.endsWith('/Log')) return { default: log };
    if (path === '@ohos.util.ArrayList') return { default: ArrayList };
    if (path === '@ohos.inputMethod') return { default: inputMethod };
    if (path.endsWith('/FlutterNapi')) return { default: flutterNapi };
    if (path.endsWith('/TextInputChannel') || path === '@kit.InputKit') return {};
    const dep = path.split('/').at(-1);
    if (classes[dep]) return classes[dep];
    throw new Error(`Unexpected SDK import: ${path}`);
  }
  vm.runInNewContext(`(function(require,exports){${code}\n})`, { console })(sdkRequire, exports);
  classes[name] = exports;
  return exports;
}
load('TextEditingDelta');
load('TextUtils');
const { ListenableEditingState } = load('ListenableEditingState');
const { default: TextInputPlugin } = load('TextInputPlugin');
let checks = 0;
function state(text, base = text.length, extent = base, composingStart = -1, composingEnd = -1) {
  const edit = new ListenableEditingState(null, 1);
  edit.updateTextInputState({ text, selectionStart: base, selectionEnd: extent,
    composingStart, composingEnd, hasSelection: () => base >= 0,
    hasComposing: () => composingStart >= 0 && composingEnd > composingStart });
  return edit;
}
function expectDelete(text, base, extent, count, left, expected, cursor, endCursor = cursor) {
  const edit = state(text, base, extent);
  let changes = 0;
  edit.addEditingStateListener({ didChangeEditingState() { changes++; } });
  edit.handleDeleteTextEvent(count, left);
  assert.equal(edit.getStringCache(), expected);
  assert.equal(edit.getSelectionStart(), cursor);
  assert.equal(edit.getSelectionEnd(), endCursor);
  assert.equal(changes, text === expected ? 0 : 1);
  if (text !== expected) {
    const delta = edit.extractBatchTextEditingDeltas()[0].toJSON();
    assert.equal(text.slice(0, delta.deltaStart) + delta.deltaText + text.slice(delta.deltaEnd), expected);
    assert.equal(delta.selectionBase, cursor);
    assert.equal(delta.selectionExtent, cursor);
  }
  checks++;
}
expectDelete('11111', 5, 5, 1, true, '1111', 4);
expectDelete('11111', 5, 5, 99, true, '', 0);
expectDelete('12345', 3, 3, 2, true, '145', 1);
expectDelete('12345', 1, 1, 2, false, '145', 1);
expectDelete('12345', 1, 1, 1, false, '1345', 1);
expectDelete('abc', 1, 1, 1, false, 'ac', 1);
expectDelete('12345', 4, 1, 1, true, '15', 1);
expectDelete('12345', 1, 4, 1, false, '15', 1);
expectDelete('', 0, 0, 1, true, '', 0);
expectDelete('abc', 0, 0, 1, true, 'abc', 0);
expectDelete('abc', 3, 3, 1, false, 'abc', 3);
for (const count of [0, 0.5, -1, NaN, Infinity]) {
  expectDelete('abc', 3, 3, count, true, 'abc', 3);
  expectDelete('abc', 1, 2, count, true, 'abc', 1, 2);
}
for (const emoji of ['😀', '👍🏽', '👨‍👩‍👧‍👦', '🇨🇳', '1️⃣', '1⃣', '❤️', '👩‍❤️‍💋‍👩']) {
  expectDelete('a' + emoji, 1 + emoji.length, 1 + emoji.length, 1, true, 'a', 1);
  expectDelete('a' + emoji + 'b', 1, 1, 1, false, 'ab', 1);
  expectDelete('a' + emoji, 1 + emoji.length, 1 + emoji.length, emoji.length, true, 'a', 1);
}
expectDelete('a😀b', 2, 3, 1, true, 'ab', 1); // malformed selection inside a surrogate pair
expectDelete('e\u0301', 2, 2, 1, true, 'e', 1); // combining mark does not corrupt its base
expectDelete('中文', 2, 2, 1, true, '中', 1);

let edit = state('abc中文', 1, 1, 3, 5);
assert.equal(edit.getComposingStart(), 3);
edit.handleDeleteTextEvent(1, true);
assert.equal(edit.getComposingStart(), 2);
assert.equal(edit.getComposingEnd(), 4);
edit = state('abc中文', 4, 4, 3, 5);
edit.handleDeleteTextEvent(1, true);
assert.equal(edit.getComposingStart(), 3);
assert.equal(edit.getComposingEnd(), 4);
edit = state('abc中文', 3, 5, 3, 5);
edit.handleDeleteTextEvent(1, true);
assert.equal(edit.getComposingStart(), -1);
assert.equal(edit.getComposingEnd(), -1);
edit = state('12345');
edit.handleSelectByRange({ start: 1, end: 4 });
assert.equal(edit.getSelectionStart(), 1);
assert.equal(edit.getSelectionEnd(), 4);
edit.handleDeleteTextEvent(1, true);
assert.equal(edit.getStringCache(), '15');
checks += 4;
edit = state('abc');
edit.setSelectionStart(-1);
edit.setSelectionEnd(-1);
edit.handleDeleteTextEvent(1, false);
assert.equal(edit.getStringCache(), 'abc');
assert.equal(edit.getSelectionStart(), -1);
assert.equal(edit.getSelectionEnd(), -1);
checks++;

// Check the event registration and channel notification using the actual plugin.
let handler;
const updates = [];
const channel = {
  setTextInputMethodHandler(value) { handler = value; },
  updateEditingState(...args) { updates.push(args); },
};
const plugin = new TextInputPlugin(channel);
handler.setClient(9, null);
handler.listenKeyBoardEvent();
assert.ok(events.has('deleteLeft'));
assert.ok(events.has('deleteRight'));
plugin.getEditingState().handleInsertTextEvent('11111');
events.get('deleteLeft')(1);
assert.equal(updates.at(-1)[1], '1111');
events.get('deleteRight')(1); // end-of-text does nothing
assert.equal(updates.at(-1)[1], '1111');
events.get('selectByRange')({ start: 0, end: 4 });
events.get('deleteLeft')(1);
assert.equal(updates.at(-1)[1], '');
assert.ok(selectionUpdates >= 3);
handler.cancelListenKeyBoardEvent();
assert.equal(events.size, 0);
checks++;
console.log(`OHOS SDK text input: ${checks} behavior checks passed; IME callbacks and deltas verified.`);
