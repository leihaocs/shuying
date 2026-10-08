import 'package:flutter/services.dart';

/// 三端使用原生文档选择器，不申请全盘存储权限。
class BackupFiles {
  static const channel = MethodChannel('com.bookmovie.revisit/backup');

  static Future<bool> save(String text) async {
    final date = DateTime.now().toIso8601String().replaceAll(':', '-');
    return await channel.invokeMethod<bool>('save', {
          'text': text,
          'name': 'shuying-$date.json',
        }) ??
        false;
  }

  static Future<String?> open() => channel.invokeMethod<String>('open');
}
