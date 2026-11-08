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
                    '想读：已加入书架，还没有开始阅读。\n\n在读：正在进行第一轮阅读。\n\n再次阅读：正在进行第二轮或之后的阅读，卡片标明第几次。\n\n已读：已有阅读轮次，并且全部读完。')),
            SizedBox(height: 20),
            SectionTitle('电影的三类状态'),
            CardBox(
                child:
                    Text('想看：还没有观影记录。\n\n已看：恰好有一次观影记录。\n\n多次观看：已有两次或更多观影记录。')),
            SizedBox(height: 20),
            SectionTitle('怎样记录阅读'),
            CardBox(
                child: Text(
                    '添加书籍时选择想读、读过或在读；在读可以填写已经读了多少页、多少分钟。\n\n在读和再次阅读列表按进度、累计页数、累计时长的优先级只显示一项；详情同时显示本轮累计进度、页数和时长，全书累计另行汇总。\n\n记录本次阅读填写的是单次页数和时长；修正本轮累计数据填写的是这一轮的总数，可增可减，不改动单次记录或降低进度。\n\n进入书籍详情记录每次阅读，读完时结束本轮；重读时开启新一轮。以前读过的可补记往期阅读。\n\n当前轮次的进度应逐次增加；历史轮次可改日期、累计页数、时长和感想，不再新增阅读明细。')),
            SizedBox(height: 20),
            SectionTitle('怎样记录观影'),
            CardBox(
                child: Text(
                    '添加电影后，记录观看日期、评分和感想。再次观看时再记一条，分类会自动变为多次观看。\n\n阅读与观影记录都可修改；修改时间后会重新排序。只选日期时使用保存当下的时分，也可主动选择时间。书籍与观影评分均为10分制，可以修改或清除。')),
            SizedBox(height: 20),
            SectionTitle('搜索与月度回顾'),
            CardBox(
                child: Text(
                    '书架和电影顶部可以搜索，搜索会与当前分类、标签和评分条件一起筛选。书籍可按书名、作者、版本、标签或备注查找；电影可按片名、导演、年份、标签或备注查找。添加或编辑资料时用逗号分隔多个标签。\n\n统计中的月度回顾免费使用，可切换年月，并沿用统计页选择的书籍或电影范围。基础卡片可以保存图片、通过系统面板分享，也可以复制文字回顾。')),
            SizedBox(height: 20),
            SectionTitle('深度回顾与备份'),
            CardBox(
                child: Text(
                    '设置中的高级功能提供年度趋势、任选日期、跨年与历次感想对照。未开放购买的渠道可预览，完整报告复制、图片样式与 PDF 导出按 Pro 权益开放；原始 JSON 备份始终免费。\n\n备份导入默认限制20MB；大文件需主动确认。发生冲突时可逐本选择保留本机或采用来源，采用来源会替换该书资料与全部记录；操作前先导出当前数据。\n\n新备份为版本3，支持标签，仍可导入旧版1、2；旧应用可能不支持新备份。')),
          ])),
        ])),
      );
}
