import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/services/pro_store.dart';
import 'package:shuying/store/app_store.dart';
import 'package:shuying/widgets/sheets.dart';

import 'review_regression_test.dart' show harness;

void main() {
  testWidgets('编辑总页数造成进度倒退时显示原因并保留表单和原资料', (tester) async {
    final store = AppStore();
    final pro = ProStore();
    addTearDown(() {
      store.dispose();
      pro.dispose();
    });
    final book = store.addBook(BookInput(title: '原书名', totalPages: 100));
    store.startReading(book.id);
    final round = store.bookById(book.id)!.rounds.single;
    store.addLog(
        book.id, round.id, LogInput(at: DateTime(2026, 1, 1), pages: 50));
    store.addLog(
        book.id, round.id, LogInput(at: DateTime(2026, 1, 2), progress: 60));
    await tester.pumpWidget(harness(
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showBookSheet(context, book: store.books.single),
                    child: const Text('编辑')))),
        store,
        pro));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Field)),
        matching: find.byType(TextField));
    await tester.enterText(field('书名'), '未保存的新书名');
    await tester.ensureVisible(field('总页数'));
    await tester.pumpAndSettle();
    await tester.enterText(field('总页数'), '50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100% → 60%'), findsOneWidget);
    expect(find.text('编辑书籍'), findsOneWidget);
    expect(store.books.single.title, '原书名');
    expect(store.books.single.totalPages, 100);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
