import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';

class UsageGuidePage extends StatelessWidget {
  const UsageGuidePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.of(context).bg,
        body: SafeArea(
            child: Column(children: [
          const NavBar(title: '使用说明'),
          Expanded(
              child:
                  ListView(padding: const EdgeInsets.all(16), children: const [
            Text('每本书、每部电影只属于一个状态分类。“全部”是汇总视图，不是额外分类。'),
            SizedBox(height: 20),
            SectionTitle('书籍的四类状态'),
            CardBox(
                child: Text(
                    '想读：已加入书架，还没有开始阅读。\n\n在读：正在进行第一轮阅读。\n\n再次阅读：正在进行第二轮或之后的阅读。\n\n已读：已有阅读轮次，并且全部读完。')),
            SizedBox(height: 20),
            SectionTitle('电影的三类状态'),
            CardBox(
                child:
                    Text('想看：还没有观影记录。\n\n已看：恰好有一次观影记录。\n\n多次观看：已有两次或更多观影记录。')),
            SizedBox(height: 20),
            SectionTitle('怎样记录阅读'),
            CardBox(
                child: Text(
                    '添加书籍时选择想读、读过或在读；在读可以填写已经读了多少页、多少分钟。\n\n进入书籍详情记录每次阅读，读完时结束本轮；重读时开启新一轮。以前读过的可补记往期阅读。\n\n当前轮次的进度应逐次增加；历史轮次可改日期、累计页数、时长和感想，不再新增阅读明细。')),
            SizedBox(height: 20),
            SectionTitle('怎样记录观影'),
            CardBox(
                child: Text(
                    '添加电影后，记录观看日期、评分和感想。再次观看时再记一条，分类会自动变为多次观看。\n\n阅读与观影记录都可修改；修改时间后会重新排序。只选日期时使用保存当下的时分，也可主动选择时间。书籍与观影评分均为10分制，可以修改或清除。')),
          ])),
        ])),
      );
}
