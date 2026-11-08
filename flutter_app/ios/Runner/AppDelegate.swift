import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  var appServices: AppServices?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    appServices?.detach()
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShuyingAppServices") {
      appServices = AppServices(messenger: registrar.messenger())
    }
  }
}

// 系统文件选择与 StoreKit 共用 Flutter 通道；不引入跨端依赖。
import UniformTypeIdentifiers
import StoreKit

@MainActor
final class AppServices: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  let backup: FlutterMethodChannel
  let purchases: FlutterMethodChannel
  let share: FlutterMethodChannel
  var fileResult: FlutterResult?
  var temporaryURL: URL?
  var temporaryDirectory: URL?
  var allowLargeRead = false
  var sharing = false
  private let fileIO = DispatchQueue(label: "com.bookmovie.revisit.file-io", qos: .userInitiated)
  private var fileToken: UUID?
  private weak var filePicker: UIDocumentPickerViewController?
  private var shareToken: UUID?
  private var shareResult: FlutterResult?
  private var shareDirectory: URL?
  private weak var shareController: UIActivityViewController?
  var updates: Task<Void, Never>?
  let productID = "com.bookmovie.revisit.app.pro.lifetime"
  let supportURL = "https://leihaocs.github.io/shuying/support.html"

  init(messenger: FlutterBinaryMessenger) {
    backup = FlutterMethodChannel(name: "com.bookmovie.revisit/backup", binaryMessenger: messenger)
    purchases = FlutterMethodChannel(name: "com.bookmovie.revisit/purchases", binaryMessenger: messenger)
    share = FlutterMethodChannel(name: "com.bookmovie.revisit/share", binaryMessenger: messenger)
    super.init()
    backup.setMethodCallHandler { [weak self] call, result in self?.fileCall(call, result) }
    share.setMethodCallHandler { [weak self] call, result in self?.shareCall(call, result) }
    purchases.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      Task { await self.purchaseCall(call, result) }
    }
    updates = Task { [weak self] in
      for await event in Transaction.updates {
        guard let self else { return }
        if case .verified(let transaction) = event, transaction.productID == self.productID {
          let state = await self.entitled()
          self.purchases.invokeMethod("changed", arguments: state)
          await transaction.finish()
        }
      }
    }
  }

  deinit { updates?.cancel() }

  func presenter() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  func fileCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "seedDemoData" { result(true); return }
    if call.method == "supportUrl" { result(supportURL); return }
    if call.method == "openSupport" || call.method == "openFiling" {
      let expected = call.method == "openFiling" ? "https://beian.miit.gov.cn/" : supportURL
      let target = call.method == "openFiling" ? expected : (call.arguments as? [String: String])?["url"] ?? expected
      guard target == expected, let url = URL(string: target) else {
        result(FlutterError(code: "support", message: "支持地址无效", details: nil)); return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      return
    }
    if call.method == "storagePath" {
      do {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        result(directory.path)
      } catch { result(FlutterError(code: "storage", message: error.localizedDescription, details: nil)) }
      return
    }
    guard fileResult == nil && !sharing else { result(FlutterError(code: "busy", message: "文件选择或分享尚未完成", details: nil)); return }
    if call.method == "open" {
      let token = beginFile(result)
      allowLargeRead = (call.arguments as? [String: Any])?["allowLarge"] as? Bool == true
      presentPicker(UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true), token: token)
    } else if call.method == "save", let args = call.arguments as? [String: String],
              let text = args["text"], let name = args["name"], safeBasename(name) {
      prepareExport(name: name, result: result) { url in
        try text.write(to: url, atomically: true, encoding: .utf8)
      }
    } else if call.method == "saveBytes" {
      guard let args = call.arguments as? [String: Any],
            let typed = args["bytes"] as? FlutterStandardTypedData,
            let name = args["name"] as? String,
            let mime = args["mime"] as? String,
            validBinaryExport(typed.data, name: name, mime: mime) else {
        result(FlutterError(code: "file", message: "只支持安全命名的 PNG 或 PDF 文件", details: nil)); return
      }
      let data = typed.data
      prepareExport(name: name, result: result) { url in try data.write(to: url, options: .atomic) }
    } else if call.method == "save" {
      result(FlutterError(code: "file", message: "备份文本或文件名无效", details: nil))
    } else { result(FlutterMethodNotImplemented) }
  }

  func beginFile(_ result: @escaping FlutterResult) -> UUID {
    let token = UUID()
    fileToken = token; fileResult = result
    return token
  }

  func prepareExport(name: String, result: @escaping FlutterResult,
                     write: @escaping (URL) throws -> Void) {
    let token = beginFile(result)
    fileIO.async { [weak self] in
      do {
        let url = try Self.exportURL(name)
        do { try write(url) }
        catch { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()); throw error }
        Task { @MainActor [weak self] in
          guard let self, self.fileToken == token else {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent()); return
          }
          self.temporaryURL = url
          self.temporaryDirectory = url.deletingLastPathComponent()
          self.presentPicker(UIDocumentPickerViewController(forExporting: [url], asCopy: true), token: token)
        }
      } catch {
        Task { @MainActor [weak self] in self?.finishFile(error: "无法准备导出文件，请重试", token: token) }
      }
    }
  }

  func presentPicker(_ picker: UIDocumentPickerViewController, token: UUID) {
    guard fileToken == token else { return }
    guard let controller = presenter(), controller.viewIfLoaded?.window != nil,
          !controller.isBeingDismissed, !controller.isBeingPresented else {
      finishFile(error: "无法打开文件选择器，请返回应用后重试", token: token); return
    }
    filePicker = picker
    picker.delegate = self
    picker.allowsMultipleSelection = false
    anchorPopover(picker, in: controller)
    controller.present(picker, animated: true)
    picker.presentationController?.delegate = self
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard filePicker === controller, let token = fileToken else { return }
    filePicker = nil
    guard let url = urls.first else { finishFile(token: token); return }
    if temporaryURL != nil { finishFile(value: true, token: token); return }
    let large = allowLargeRead
    // 文件提供方可能来自 iCloud；安全作用域、读取与解码都在串行后台队列完成。
    fileIO.async { [weak self] in
      do {
        let text = try Self.readBackup(url, allowLarge: large)
        Task { @MainActor [weak self] in self?.finishFile(value: text, token: token) }
      } catch {
        Task { @MainActor [weak self] in self?.finishFile(error: "无法读取 JSON 备份；大备份需先确认大文件导入", token: token) }
      }
    }
  }

  nonisolated static func readBackup(_ url: URL, allowLarge: Bool) throws -> String {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard allowLarge || size <= 20 * 1024 * 1024 else { throw NSError(domain: "backup", code: 2) }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var bytes = Data()
    while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
      guard allowLarge || bytes.count + chunk.count <= 20 * 1024 * 1024 else {
        throw NSError(domain: "backup", code: 2)
      }
      bytes.append(chunk)
    }
    guard let text = String(data: bytes, encoding: .utf8) else { throw NSError(domain: "backup", code: 4) }
    return text
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard filePicker === controller, let token = fileToken else { return }
    finishFile(token: token)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if let picker = filePicker, presentationController.presentedViewController === picker,
       let token = fileToken { finishFile(token: token) }
    if let activity = shareController, presentationController.presentedViewController === activity,
       let token = shareToken { finishShare(token: token) }
  }

  func finishFile(value: Any? = nil, error: String? = nil, token: UUID) {
    guard fileToken == token else { return }
    let result = fileResult
    cleanup()
    if let error { result?(FlutterError(code: "file", message: error, details: nil)) }
    else { result?(value) }
  }

  func cleanup() {
    let directory = temporaryDirectory
    temporaryURL = nil; temporaryDirectory = nil; fileResult = nil
    fileToken = nil; filePicker = nil; allowLargeRead = false
    if let directory { fileIO.async { try? FileManager.default.removeItem(at: directory) } }
  }

  func detach() {
    let picker = filePicker
    let activity = shareController
    if let token = fileToken { finishFile(error: "文件操作因引擎重建中断，请检查目标文件后重试", token: token) }
    if let token = shareToken { finishShare(error: "分享因引擎重建中断，请重试", token: token) }
    picker?.dismiss(animated: false)
    activity?.dismiss(animated: false)
    backup.setMethodCallHandler(nil); share.setMethodCallHandler(nil); purchases.setMethodCallHandler(nil)
    updates?.cancel()
  }

  func safeBasename(_ name: String) -> Bool {
    !name.isEmpty && name.count <= 180 && !name.hasPrefix(".") &&
      !name.contains("/") && !name.contains("\\") &&
      !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
  }

  func validBinaryExport(_ bytes: Data, name: String, mime: String) -> Bool {
    guard safeBasename(name) else { return false }
    if mime == "image/png" {
      return name.lowercased().hasSuffix(".png") && bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
    }
    if mime == "application/pdf" {
      return name.lowercased().hasSuffix(".pdf") && bytes.starts(with: Array("%PDF-".utf8))
    }
    return false
  }

  nonisolated static func exportURL(_ name: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("shuying-export-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(name)
  }

  func anchorPopover(_ child: UIViewController, in controller: UIViewController) {
    if let popover = child.popoverPresentationController {
      popover.sourceView = controller.view
      popover.sourceRect = CGRect(x: controller.view.bounds.midX,
        y: controller.view.bounds.midY, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
  }

  func shareCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "image" else { result(FlutterMethodNotImplemented); return }
    guard !sharing && fileResult == nil else {
      result(FlutterError(code: "busy", message: "文件选择或分享尚未完成", details: nil)); return
    }
    guard let args = call.arguments as? [String: Any],
          let typed = args["bytes"] as? FlutterStandardTypedData,
          typed.data.count <= 8 * 1024 * 1024,
          validBinaryExport(typed.data, name: "review.png", mime: "image/png") else {
      result(FlutterError(code: "share", message: "无法生成分享图片", details: nil)); return
    }
    let token = UUID()
    shareToken = token; shareResult = result; sharing = true
    let data = typed.data
    fileIO.async { [weak self] in
      do {
        let url = try Self.exportURL("shuying-review.png")
        do { try data.write(to: url, options: .atomic) }
        catch { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()); throw error }
        Task { @MainActor [weak self] in
          guard let self, self.shareToken == token else {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent()); return
          }
          self.shareDirectory = url.deletingLastPathComponent()
          guard let controller = self.presenter(), controller.viewIfLoaded?.window != nil,
                !controller.isBeingDismissed, !controller.isBeingPresented else {
            self.finishShare(error: "无法打开分享面板，请返回应用后重试", token: token); return
          }
          let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
          self.shareController = activity
          self.anchorPopover(activity, in: controller)
          activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
            Task { @MainActor [weak self] in self?.finishShare(token: token) }
          }
          controller.present(activity, animated: true) { [weak self] in
            guard let self, self.shareToken == token else { return }
            let callback = self.shareResult
            self.shareResult = nil
            callback?(nil)
          }
          activity.presentationController?.delegate = self
        }
      } catch {
        Task { @MainActor [weak self] in self?.finishShare(error: "无法打开分享面板，可先保存图片", token: token) }
      }
    }
  }

  func finishShare(error: String? = nil, token: UUID) {
    guard shareToken == token else { return }
    let result = shareResult
    let directory = shareDirectory
    shareToken = nil; shareResult = nil; shareDirectory = nil; shareController = nil; sharing = false
    if let directory { fileIO.async { try? FileManager.default.removeItem(at: directory) } }
    if let error { result?(FlutterError(code: "share", message: error, details: nil)) }
    else { result?(nil) }
  }

  func entitled() async -> Bool {
    for await event in Transaction.currentEntitlements {
      if case .verified(let transaction) = event,
         transaction.productID == productID, transaction.revocationDate == nil {
        return true
      }
    }
    return false
  }

  func purchaseCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async {
    do {
      switch call.method {
      case "status": result(await entitled())
      case "product":
        guard let product = try await Product.products(for: [productID]).first else {
          result(nil); return
        }
        result(["id": product.id, "price": product.displayPrice])
      case "buy":
        guard let product = try await Product.products(for: [productID]).first else {
          throw NSError(domain: "purchase", code: 1, userInfo: [NSLocalizedDescriptionKey: "商品暂不可用"])
        }
        switch try await product.purchase() {
        case .success(let verification):
          guard case .verified(let transaction) = verification,
                transaction.productID == productID, transaction.revocationDate == nil else {
            throw NSError(domain: "purchase", code: 2, userInfo: [NSLocalizedDescriptionKey: "购买验证未通过"])
          }
          let active = await entitled()
          purchases.invokeMethod("changed", arguments: active)
          await transaction.finish()
          result(active ? "purchased" : "unavailable")
        case .pending: result("pending")
        case .userCancelled: result("cancelled")
        @unknown default: result("unavailable")
        }
      case "restore":
        try await AppStore.sync()
        result(await entitled())
      default: result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "purchase", message: error.localizedDescription, details: nil)) }
  }
}
