import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/period_review.dart';
import '../services/pro_store.dart';
import '../store/app_store.dart';
import '../widgets/bits.dart';
import 'advanced_review_page.dart';
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
    final store = context.watch<AppStore?>();
    final hasRecords =
        store != null && latestReviewDate(store.books, store.movies) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('书影温故 Pro')),
      body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(pro.isPro ? '你的深度书影档案已解锁' : '让每一次阅读与观影都有回顾',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            // Column is not const in the older HarmonyOS Flutter SDK.
            // ignore: prefer_const_constructors
            CardBox(
                // ignore: prefer_const_constructors
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('普通版 · 免费'),
                  const SizedBox(height: 8),
                  const Text(
                      '不限量书籍与电影、多轮记录、搜索与基础筛选、基础统计、月度回顾、基础分享卡片、明暗主题、JSON 文件导出和合并导入。'),
                  const SizedBox(height: 20),
                  Text(pro.sandbox
                      ? 'Pro · 沙盒测试'
                      : pro.purchasesEnabled
                          ? 'Pro · 一次购买'
                          : 'Pro · 功能介绍'),
                  const SizedBox(height: 8),
                  const Text(
                      '年度 12 个月趋势、任选日期范围汇总、跨年对比；同一本书多轮阅读、同一电影历次评分与感想对照；完整回顾可复制、保存图片和 PDF。'),
                ])),
            const SizedBox(height: 16),
            Text(pro.sandbox
                ? '当前为华为沙盒测试版，不会真实扣款。测试解锁仅在本次前台使用期间有效；切到后台或重启后可能需要重新测试。'
                : pro.purchasesEnabled
                    ? '购买适用于当前商店账号支持的设备，不包含跨系统会员、云同步或订阅。记录备份可在三端免费迁移。'
                    : '当前渠道暂未开放 Pro 购买，可预览深度回顾。有记录时使用你的真实数据，没有记录时年度页会明确标注示例。基础记录、统计与备份功能免费使用。'),
            const SizedBox(height: 20),
            if (pro.isPro) ...[
              ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const YearReviewPage())),
                  child: const Text('查看我的年度回顾')),
              OutlinedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const AdvancedReviewPage())),
                  child: const Text('日期范围、跨年与历次对照')),
            ] else ...[
              if (pro.purchasesEnabled)
                ElevatedButton(
                    onPressed: pro.busy || pro.price == null ? null : pro.buy,
                    child: Text(pro.busy
                        ? '正在连接商店…'
                        : pro.price == null
                            ? '购买暂不可用'
                            : pro.sandbox
                                ? '沙盒购买测试 · ${pro.price}'
                                : '一次购买解锁 · ${pro.price}')),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const YearReviewPage(preview: true))),
                  child: Text(hasRecords ? '预览我的年度回顾' : '预览示例年度回顾')),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const AdvancedReviewPage(preview: true))),
                  child: const Text('预览日期范围、跨年与历次对照')),
            ],
            if (pro.purchasesEnabled)
              TextButton(
                  onPressed: pro.busy ? null : pro.restore,
                  child: const Text('恢复购买')),
            if (pro.purchasesEnabled)
              TextButton(
                  onPressed: pro.busy ? null : pro.refresh,
                  child: const Text('刷新商店状态')),
            if (pro.message != null)
              Text(pro.message!, key: const Key('purchase-message')),
          ])),
    );
  }
}
