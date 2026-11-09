import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// 权益只来自商店验证，不写入 JSON 备份，也不通过本地开关解锁。
class ProStore extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = MethodChannel('com.bookmovie.revisit/purchases');
  bool isPro = false;
  // iOS 保留恢复购买入口，其余渠道经原生能力确认后再显示。
  bool purchasesEnabled = defaultTargetPlatform == TargetPlatform.iOS;
  bool sandbox = false;
  bool busy = false;
  String? price;
  String? message;
  bool _disposed = false;
  final bool Function()? _hasConsent;
  final Listenable? _consentChanges;
  bool _consentGranted = true;
  int _consentEpoch = 0;
  int _operation = 0;
  int _entitlementRevision = 0;

  ProStore({bool Function()? hasConsent, Listenable? consentChanges})
      : _hasConsent = hasConsent,
        _consentChanges = consentChanges {
    _consentGranted = _hasConsent?.call() ?? true;
    _consentChanges?.addListener(_consentChanged);
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (_allowed && call.method == 'changed' && call.arguments is bool) {
        _entitlementRevision++;
        isPro = call.arguments as bool;
        message = isPro ? _unlockedMessage : null;
        _notify();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!_allowed || busy) return;
    final operation = ++_operation;
    busy = true;
    _notify();
    try {
      await _readEntitlement('status');
      if (!_current(operation)) return;
      final product = await channel
          .invokeMapMethod<String, dynamic>('product')
          .timeout(const Duration(seconds: 15));
      if (!_current(operation)) return;
      purchasesEnabled = product?['purchasesEnabled'] != false;
      sandbox = product?['sandbox'] == true;
      price = purchasesEnabled ? (product?['price'] as String?) : null;
      final storeMessage = product?['message'];
      message = storeMessage is String && storeMessage.isNotEmpty
          ? storeMessage
          : !purchasesEnabled
              ? null
              : price == null
                  ? '购买暂不可用，请稍后重试。基础功能与备份始终免费。'
                  : null;
    } catch (_) {
      if (!_current(operation)) return;
      price = null;
      message = '购买服务暂不可用，请稍后重试。基础功能与备份始终免费。';
    } finally {
      _finish(operation);
    }
  }

  Future<void> buy() async {
    if (!_allowed || !purchasesEnabled || busy || price == null) return;
    final operation = ++_operation;
    final consentEpoch = _consentEpoch;
    busy = true;
    _notify();
    try {
      // 等待结束只释放界面；原生交易仍可迟到交付，不能将其当成付款失败。
      final state =
          await channel.invokeMethod<String>('buy').then((state) async {
        if (_allowed && consentEpoch == _consentEpoch) {
          await _readEntitlement('status');
        }
        return state;
      }).timeout(const Duration(minutes: 2));
      if (!_current(operation)) return;
      message = state == 'pending'
          ? '付款待确认，确认后自动解锁。'
          : state == 'cancelled'
              ? '已取消购买。'
              : isPro
                  ? _unlockedMessage
                  : '购买未确认，请重试或恢复购买。';
    } catch (_) {
      if (!_current(operation)) return;
      message = isPro ? _unlockedMessage : '付款结果尚未确认，请稍后刷新商店状态或恢复购买，避免重复付款。';
    } finally {
      _finish(operation);
    }
  }

  Future<void> restore() async {
    if (!_allowed || !purchasesEnabled || busy) return;
    final operation = ++_operation;
    busy = true;
    _notify();
    try {
      await _readEntitlement('restore');
      if (!_current(operation)) return;
      message = isPro
          ? sandbox
              ? '本次沙盒测试权益有效。'
              : '购买已恢复。'
          : '当前商店账号没有可恢复的 Pro 购买。';
    } catch (error) {
      if (!_current(operation)) return;
      message = sandbox &&
              error is PlatformException &&
              error.code == 'sandbox_restore_unavailable'
          ? '华为沙盒不返回已确认发货的买断订单。需在后台清除测试购买历史后重新测试；正式购买不受此沙盒限制。'
          : isPro
              ? _unlockedMessage
              : '恢复结果尚未确认，请检查网络和商店账号后重试。';
    } finally {
      _finish(operation);
    }
  }

  bool get _allowed => !_disposed && _consentGranted;
  String get _unlockedMessage => sandbox ? '本次沙盒测试已解锁。' : 'Pro 已解锁。';
  bool _current(int operation) => _allowed && operation == _operation;

  Future<void> _readEntitlement(String method) {
    final epoch = _consentEpoch;
    final revision = ++_entitlementRevision;
    // then 保留在 timeout 之前：迟到的已验证结果仍可恢复权益；更新的
    // 商店事件或查询优先，旧响应不能覆盖刚完成的购买或退款。
    return channel.invokeMethod<bool>(method).then((value) {
      if (_allowed &&
          epoch == _consentEpoch &&
          revision == _entitlementRevision) {
        isPro = value ?? false;
        if (isPro) message = _unlockedMessage;
        _notify();
      }
    }).timeout(const Duration(seconds: 15));
  }

  void _consentChanged() {
    final consent = _hasConsent?.call() ?? true;
    if (consent == _consentGranted) return;
    _consentGranted = consent;
    _consentEpoch++;
    _operation++;
    busy = false;
    // AppStore 的通知也可能发生在构建期间，不同步通知另一个 Provider。
    scheduleMicrotask(() {
      if (_allowed) {
        refresh();
      } else {
        _notify();
      }
    });
  }

  void _finish(int operation) {
    if (!_current(operation)) return;
    busy = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _consentChanges?.removeListener(_consentChanged);
    channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
