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
final class AppServices: NSObject, UIDocumentPickerDelegate {
  let backup: FlutterMethodChannel
  let purchases: FlutterMethodChannel
  var fileResult: FlutterResult?
  var temporaryURL: URL?
  var updates: Task<Void, Never>?
  let productID = "com.bookmovie.revisit.app.pro.lifetime"

  init(messenger: FlutterBinaryMessenger) {
    backup = FlutterMethodChannel(name: "com.bookmovie.revisit/backup", binaryMessenger: messenger)
    purchases = FlutterMethodChannel(name: "com.bookmovie.revisit/purchases", binaryMessenger: messenger)
    super.init()
    backup.setMethodCallHandler { [weak self] call, result in self?.fileCall(call, result) }
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
    if call.method == "storagePath" {
      do {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        result(directory.path)
      } catch { result(FlutterError(code: "storage", message: error.localizedDescription, details: nil)) }
      return
    }
    guard fileResult == nil else { result(FlutterError(code: "busy", message: "文件选择尚未完成", details: nil)); return }
    let picker: UIDocumentPickerViewController
    do {
      if call.method == "save", let args = call.arguments as? [String: String],
         let text = args["text"], let name = args["name"] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        temporaryURL = url
        picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      } else if call.method == "open" {
        picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
      } else { result(FlutterMethodNotImplemented); return }
      guard let controller = presenter() else { throw NSError(domain: "backup", code: 1) }
      fileResult = result
      picker.delegate = self
      picker.allowsMultipleSelection = false
      controller.present(picker, animated: true)
    } catch { result(FlutterError(code: "file", message: error.localizedDescription, details: nil)); cleanup() }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    defer { cleanup() }
    guard let result = fileResult else { return }
    if temporaryURL != nil { result(true); return }
    guard let url = urls.first else { result(nil); return }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= 20 * 1024 * 1024 else { throw NSError(domain: "backup", code: 2) }
      result(try String(contentsOf: url, encoding: .utf8))
    } catch { result(FlutterError(code: "file", message: "无法读取 JSON 备份", details: nil)) }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    fileResult?(nil); cleanup()
  }

  func cleanup() {
    if let url = temporaryURL { try? FileManager.default.removeItem(at: url) }
    temporaryURL = nil; fileResult = nil
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
