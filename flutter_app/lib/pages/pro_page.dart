import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pro_store.dart';
import '../widgets/bits.dart';
import 'year_review_page.dart';

class ProPage extends StatefulWidget {
  const ProPage({super.key});
  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<ProStore>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('书影温故 Pro')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(pro.isPro ? '你的年度书影档案已解锁' : '让每一次阅读与观影都有回顾',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        // Column is not const in the older HarmonyOS Flutter SDK.
        // ignore: prefer_const_constructors
        CardBox(
            // ignore: prefer_const_constructors
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
              Text('普通版 · 免费'),
              SizedBox(height: 8),
              Text('不限量书籍与电影、多轮记录、基础统计、明暗主题、JSON 文件导出和合并导入。'),
              SizedBox(height: 20),
              Text('Pro · 一次购买'),
              SizedBox(height: 8),
              Text('按年份查看阅读时长、页数、完成次数、阅读天数、观影次数与平均评分；12 个月趋势，复制年度回顾。'),
            ])),
        const SizedBox(height: 16),
        const Text('购买适用于当前商店账号支持的设备，不包含跨系统会员、云同步或订阅。记录备份可在三端免费迁移。'),
        const SizedBox(height: 20),
        if (pro.isPro)
          ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const YearReviewPage())),
              child: const Text('查看我的年度回顾'))
        else ...[
          ElevatedButton(
              onPressed: pro.busy || pro.price == null ? null : pro.buy,
              child: Text(pro.busy
                  ? '正在连接商店…'
                  : pro.price == null
                      ? '购买暂不可用'
                      : '一次购买解锁 · ${pro.price}')),
          TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const YearReviewPage(preview: true))),
              child: const Text('预览示例年度回顾')),
        ],
        TextButton(
            onPressed: pro.busy ? null : pro.restore,
            child: const Text('恢复购买')),
        TextButton(
            onPressed: pro.busy ? null : pro.refresh,
            child: const Text('刷新商店状态')),
        if (pro.message != null)
          Text(pro.message!, key: const Key('purchase-message')),
      ]),
    );
  }
}
