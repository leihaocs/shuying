import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 权益只来自商店验证，不写入 JSON 备份，也不通过本地开关解锁。
class ProStore extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = MethodChannel('com.bookmovie.revisit/purchases');
  bool isPro = false;
  bool busy = false;
  String? price;
  String? message;
  bool _disposed = false;

  ProStore() {
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && call.arguments is bool) {
        isPro = call.arguments as bool;
        _notify();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      isPro = await channel.invokeMethod<bool>('status') ?? false;
      final product = await channel.invokeMapMethod<String, dynamic>('product');
      price = product?['price'] as String?;
      message = price == null ? '购买暂不可用，请稍后重试。基础功能与备份始终免费。' : null;
    } catch (_) {
      price = null;
      message = '购买服务暂不可用，请稍后重试。基础功能与备份始终免费。';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> buy() async {
    if (busy || price == null) return;
    busy = true;
    _notify();
    try {
      final state = await channel.invokeMethod<String>('buy');
      isPro = await channel.invokeMethod<bool>('status') ?? false;
      message = state == 'pending'
          ? '付款待确认，确认后自动解锁。'
          : state == 'cancelled'
              ? '已取消购买。'
              : isPro
                  ? 'Pro 已解锁。'
                  : '购买未确认，请重试或恢复购买。';
    } catch (_) {
      message = '购买未完成，请重试或恢复购买。';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      isPro = await channel.invokeMethod<bool>('restore') ?? false;
      message = isPro ? '购买已恢复。' : '当前商店账号没有可恢复的 Pro 购买。';
    } catch (_) {
      message = '恢复失败，请检查网络和商店账号后重试。';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
