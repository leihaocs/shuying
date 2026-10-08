import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

export default class BackupPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private busy: boolean = false;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) { this.context = context; }
  getUniqueClassName(): string { return 'ShuyingBackup'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.bookmovie.revisit/backup');
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.handle(call, result);
  }
  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'storagePath') { result.success(this.context.filesDir); return; }
    if (this.busy) { result.error('busy', '文件选择尚未完成', null); return; }
    if (call.method !== 'open' && call.method !== 'save') { result.notImplemented(); return; }
    this.busy = true;
    try {
      const document = new picker.DocumentViewPicker(this.context);
      if (call.method === 'save') {
        const options = new picker.DocumentSaveOptions();
        options.newFileNames = [call.argument('name') as string];
        const uris = await document.save(options);
        if (uris.length === 0) { result.success(null); return; }
        const file = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          const bytes = new util.TextEncoder().encodeInto(call.argument('text') as string);
          let offset = 0;
          while (offset < bytes.length) {
            const count = fs.writeSync(file.fd, bytes.slice(offset).buffer);
            if (count <= 0) throw new Error('写入失败');
            offset += count;
          }
          fs.fsyncSync(file.fd);
        } finally { fs.closeSync(file); }
        result.success(true);
      } else {
        const options = new picker.DocumentSelectOptions();
        options.maxSelectNumber = 1;
        const uris = await document.select(options);
        if (uris.length === 0) { result.success(null); return; }
        const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
        try {
          const size = fs.statSync(file.fd).size;
          if (size > 20 * 1024 * 1024) throw new Error('文件超过 20 MB');
          const bytes = new ArrayBuffer(size);
          let offset = 0;
          while (offset < size) {
            const chunk = new ArrayBuffer(size - offset);
            const count = fs.readSync(file.fd, chunk);
            if (count <= 0) throw new Error('文件未完整读取');
            new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), offset);
            offset += count;
          }
          result.success(util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes)));
        } finally { fs.closeSync(file); }
      }
    } catch (_) { result.error('file', '无法处理 JSON 文件，请重试', null); }
    finally { this.busy = false; }
  }
}
