import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import fileuri from '@ohos.file.fileuri';
import uniformTypeDescriptor from '@ohos.data.uniformTypeDescriptor';
import systemShare from '@hms.collaboration.systemShare';

export default class BackupPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private purchases: MethodChannel | null = null;
  private share: MethodChannel | null = null;
  private shareController: systemShare.ShareController | null = null;
  private shareDismiss: (() => void) | null = null;
  private busy: boolean = false;
  private pending: MethodResult | null = null;
  private attached: boolean = false;
  private context: common.UIAbilityContext;
  private supportUrl: string = 'https://bookmovie-revisit.cn/support.html';

  constructor(context: common.UIAbilityContext) { this.context = context; }
  getUniqueClassName(): string { return 'ShuyingBackup'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.attached = true;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.bookmovie.revisit/backup');
    this.channel.setMethodCallHandler(this);
    this.purchases = new MethodChannel(binding.getBinaryMessenger(), 'com.bookmovie.revisit/purchases');
    this.purchases.setMethodCallHandler(this);
    this.share = new MethodChannel(binding.getBinaryMessenger(), 'com.bookmovie.revisit/share');
    this.share.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    // 普通切后台不取消选择；仅 engine 明确分离时结束 Flutter 的等待。
    const pending = this.pending;
    this.pending = null;
    this.busy = false;
    this.attached = false;
    pending?.error('file', '文件操作因引擎重建中断，请检查目标文件后重试', null);
    this.channel?.setMethodCallHandler(null);
    this.purchases?.setMethodCallHandler(null);
    this.share?.setMethodCallHandler(null);
    this.clearShareController();
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.handle(call, result);
  }
  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'image') { await this.shareImage(call, result); return; }
    if (call.method === 'seedDemoData') { result.success(false); return; }
    if (call.method === 'supportUrl') { result.success(this.supportUrl); return; }
    if (call.method === 'status') { result.success(false); return; }
    if (call.method === 'product') { result.success({ 'purchasesEnabled': false }); return; }
    if (call.method === 'buy' || call.method === 'restore') {
      result.error('unavailable', '当前版本未开放购买', null); return;
    }
    if (call.method === 'openSupport' || call.method === 'openFiling') {
      try {
        const expected = call.method === 'openFiling' ? 'https://beian.miit.gov.cn/' : this.supportUrl;
        const target = call.method === 'openFiling' ? expected : (call.argument('url') as string | null) ?? expected;
        if (target !== expected) throw new Error('支持地址无效');
        await this.context.startAbility({ action: 'ohos.want.action.viewData', uri: target });
        result.success(true);
      } catch (_) { result.error('support', '无法打开浏览器', null); }
      return;
    }
    if (call.method === 'storagePath') { result.success(this.context.filesDir); return; }
    if (this.busy || this.shareController !== null) { result.error('busy', '文件选择或分享尚未完成', null); return; }
    if (call.method !== 'open' && call.method !== 'save' && call.method !== 'saveBytes') { result.notImplemented(); return; }
    this.busy = true;
    this.pending = result;
    try {
      const document = new picker.DocumentViewPicker(this.context);
      if (call.method === 'save' || call.method === 'saveBytes') {
        const name = call.argument('name') as string;
        if (!this.safeBasename(name)) throw new Error('文件名无效');
        const bytes = call.method === 'saveBytes' ? this.binaryBytes(call) :
          new util.TextEncoder().encodeInto(call.argument('text') as string);
        const options = new picker.DocumentSaveOptions();
        options.newFileNames = [name];
        if (call.method === 'saveBytes') {
          const mime = call.argument('mime') as string;
          if (!this.validBinaryExport(bytes, name, mime)) throw new Error('只支持安全命名的 PNG 或 PDF 文件');
          options.fileSuffixChoices = mime === 'image/png' ? ['PNG|.png'] : ['PDF|.pdf'];
        }
        const uris = await document.save(options);
        if (this.pending !== result || !this.attached) return;
        if (uris.length === 0) { this.finishFile(result); return; }
        await this.writeBytes(uris[0], bytes, result);
        this.finishFile(result, true);
      } else {
        const allowLarge = call.argument('allowLarge') === true;
        const options = new picker.DocumentSelectOptions();
        options.maxSelectNumber = 1;
        const uris = await document.select(options);
        if (this.pending !== result || !this.attached) return;
        if (uris.length === 0) { this.finishFile(result); return; }
        const file = await fs.open(uris[0], fs.OpenMode.READ_ONLY);
        let text: string = '';
        try {
          const size = (await fs.stat(file.fd)).size;
          if (this.pending !== result || !this.attached) return;
          if (!allowLarge && size > 20 * 1024 * 1024) throw new Error('文件超过 20 MB，请先确认大文件导入');
          const bytes = new ArrayBuffer(size);
          let offset = 0;
          while (offset < size) {
            const chunk = new ArrayBuffer(Math.min(65536, size - offset));
            const count = await fs.read(file.fd, chunk);
            if (this.pending !== result || !this.attached) return;
            if (count <= 0) throw new Error('文件未完整读取');
            new Uint8Array(bytes).set(new Uint8Array(chunk, 0, count), offset);
            offset += count;
          }
          text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(bytes));
        } finally { await fs.close(file); }
        this.finishFile(result, text);
      }
    } catch (_) { this.finishFile(result, null, '无法处理文件，请重试；大备份需先确认大文件导入'); }
  }

  private finishFile(result: MethodResult, value: string | boolean | null = null, error: string | null = null): void {
    // 引擎分离后的旧异步续体不能回复两次，也不能解除新请求的互斥。
    if (this.pending !== result) return;
    this.pending = null;
    this.busy = false;
    if (error === null) result.success(value);
    else result.error('file', error, null);
  }

  private safeBasename(name: string): boolean {
    return typeof name === 'string' && name.length > 0 && name.length <= 180 &&
      !name.startsWith('.') && !/[\/\\\u0000-\u001f\u007f]/.test(name);
  }

  private binaryBytes(call: MethodCall): Uint8Array {
    const bytes = call.argument('bytes');
    if (!(bytes instanceof Uint8Array)) throw new Error('未收到二进制文件');
    return bytes;
  }

  private validBinaryExport(bytes: Uint8Array, name: string, mime: string): boolean {
    if (!this.safeBasename(name)) return false;
    const lower = name.toLowerCase();
    if ((mime !== 'image/png' || !lower.endsWith('.png')) &&
      (mime !== 'application/pdf' || !lower.endsWith('.pdf'))) return false;
    const header: number[] = mime === 'image/png' ? [137, 80, 78, 71, 13, 10, 26, 10] : [37, 80, 68, 70, 45];
    if (bytes.length < header.length) return false;
    for (let i = 0; i < header.length; i++) {
      if (bytes[i] !== header[i]) return false;
    }
    return true;
  }

  private async writeBytes(path: string, bytes: Uint8Array, operation: MethodResult, create: boolean = false): Promise<void> {
    if (this.pending !== operation || !this.attached) throw new Error('文件操作已中断');
    const mode = fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | (create ? fs.OpenMode.CREATE : 0);
    const file = await fs.open(path, mode);
    try {
      let offset = 0;
      while (offset < bytes.length) {
        if (this.pending !== operation || !this.attached) throw new Error('文件操作已中断');
        // 每次只复制最多 64 KiB，避免部分写入时反复复制整份剩余报告。
        const chunk = bytes.slice(offset, Math.min(offset + 65536, bytes.length));
        const count = await fs.write(file.fd, chunk.buffer);
        if (count <= 0) throw new Error('写入失败');
        offset += count;
      }
      await fs.fsync(file.fd);
    } finally { await fs.close(file); }
  }

  private async shareImage(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.busy || this.shareController !== null) {
      result.error('busy', '文件选择或分享尚未完成', null); return;
    }
    this.busy = true;
    this.pending = result;
    let imagePath: string = '';
    try {
      const bytes = this.binaryBytes(call);
      if (bytes.length > 8 * 1024 * 1024 || !this.validBinaryExport(bytes, 'review.png', 'image/png')) throw new Error('PNG 图片无效');
      const directory = `${this.context.cacheDir}/review-share`;
      if (!await fs.access(directory)) await fs.mkdir(directory);
      for (const name of await fs.listFile(directory)) {
        if (!name.startsWith('shuying-review-') || !name.endsWith('.png')) continue;
        try {
          const oldPath = `${directory}/${name}`;
          if (Date.now() / 1000 - (await fs.stat(oldPath)).mtime > 24 * 60 * 60) await fs.unlink(oldPath);
        } catch (_) { /* 缓存清理失败不影响当前分享。 */ }
      }
      imagePath = `${directory}/shuying-review-${Date.now()}-${Math.floor(Math.random() * 1000000)}.png`;
      await this.writeBytes(imagePath, bytes, result, true);
      if (this.pending !== result || !this.attached) return;
      // API11 起支持；当前应用最低 API20。URI 避免图片触及分享记录 200KB IPC 上限。
      const data = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PNG,
        uri: fileuri.getUriFromPath(imagePath),
        title: '书影回顾'
      });
      const controller = new systemShare.ShareController(data);
      this.shareController = controller;
      const dismiss = (): void => {
        if (this.shareController === controller) this.clearShareController();
        // 面板关闭时接收方可能仍在读取；PNG 留在缓存，24小时后下次分享时清理。
      };
      this.shareDismiss = dismiss;
      controller.on('dismiss', dismiss);
      await controller.show(this.context, { previewMode: systemShare.SharePreviewMode.DETAIL });
    } catch (_) {
      if (this.pending === result) {
        this.clearShareController();
        this.pending = null;
        this.busy = false;
        result.error('share', '无法打开分享面板，可先保存 PNG 图片', null);
      }
      if (imagePath.length > 0) {
        try { await fs.unlink(imagePath); } catch (_) { /* 保留缓存由系统回收。 */ }
      }
      return;
    }
    // dismiss 只释放控制器，不重复回复 Flutter；展示成功与失败仅走一条回复路径。
    this.finishFile(result);
  }

  private clearShareController(): void {
    const controller = this.shareController;
    const dismiss = this.shareDismiss;
    this.shareController = null;
    this.shareDismiss = null;
    if (controller !== null && dismiss !== null) {
      try { controller.off('dismiss', dismiss); } catch (_) { /* 关闭中的面板不阻塞通道释放。 */ }
    }
  }
}
