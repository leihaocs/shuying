import 'package:flutter_test/flutter_test.dart';
import 'package:shuying/domain/books.dart';
import 'package:shuying/domain/fmt.dart';
import 'package:shuying/domain/movies.dart';
import 'package:shuying/models/models.dart';

Book _book({int? totalPages, List<ReadingRound> rounds = const []}) => Book(
      id: 'b1',
      title: '活着',
      author: '余华',
      totalPages: totalPages,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      rounds: rounds,
    );

ReadingRound _round({
  int index = 1,
  DateTime? finishedAt,
  List<ReadingLog> logs = const [],
}) =>
    ReadingRound(
      id: 'r$index',
      index: index,
      startedAt: DateTime(2026, 1, 2),
      finishedAt: finishedAt,
      logs: logs,
    );

void main() {
  group('书籍状态推导', () {
    test('没有轮次 -> 想读', () {
      expect(bookStatus(_book()), BookStatus.want);
      expect(statusLabel(_book()), '想读');
    });

    test('第 1 轮未完成 -> 在读', () {
      final b = _book(rounds: [_round()]);
      expect(bookStatus(b), BookStatus.reading);
      expect(statusLabel(b), '在读');
    });

    test('第 2 轮未完成 -> 再次阅读', () {
      final b = _book(rounds: [
        _round(index: 1, finishedAt: DateTime(2026, 1, 5)),
        _round(index: 2),
      ]);
      expect(bookStatus(b), BookStatus.rereading);
      expect(statusLabel(b), '再次阅读');
    });

    test('全部完成 -> 已读 N 次', () {
      final b = _book(rounds: [
        _round(index: 1, finishedAt: DateTime(2026, 1, 5)),
        _round(index: 2, finishedAt: DateTime(2026, 2, 5)),
      ]);
      expect(bookStatus(b), BookStatus.finished);
      expect(statusLabel(b), '已读2次');
      expect(bookSummary(b).readTimes, 2);
    });
  });

  group('进度计算', () {
    test('优先取最近一次显式填写的进度', () {
      final b = _book(totalPages: 100, rounds: [
        _round(logs: [
          ReadingLog(id: 'l1', at: DateTime(2026, 1, 3), pages: 40, progress: 40),
          ReadingLog(id: 'l2', at: DateTime(2026, 1, 4), minutes: 30),
        ]),
      ]);
      expect(roundProgress(b, b.rounds.first), 40);
    });

    test('没填进度时按页数估算', () {
      final b = _book(totalPages: 200, rounds: [
        _round(logs: [
          ReadingLog(id: 'l1', at: DateTime(2026, 1, 3), pages: 50),
          ReadingLog(id: 'l2', at: DateTime(2026, 1, 4), pages: 50),
        ]),
      ]);
      expect(roundProgress(b, b.rounds.first), 50);
    });

    test('既无进度也无总页数时为 0', () {
      final b = _book(rounds: [
        _round(logs: [
          ReadingLog(id: 'l1', at: DateTime(2026, 1, 3), minutes: 30),
        ]),
      ]);
      expect(roundProgress(b, b.rounds.first), 0);
    });
  });

  group('电影状态', () {
    test('没有观影记录 -> 想看', () {
      final m = Movie(
        id: 'm1',
        title: '肖申克的救赎',
        director: '弗兰克·德拉邦特',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(movieStatus(m), MovieStatus.want);
      expect(movieStatusLabel(m), '想看');
    });

    test('看两次 -> 已看 2 次', () {
      final m = Movie(
        id: 'm1',
        title: '肖申克的救赎',
        director: '弗兰克·德拉邦特',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        watches: [
          WatchRecord(id: 'w1', at: DateTime(2026, 1, 3), rating: 5),
          WatchRecord(id: 'w2', at: DateTime(2026, 2, 3), rating: 5),
        ],
      );
      expect(movieStatus(m), MovieStatus.watched);
      expect(movieStatusLabel(m), '已看2次');
      expect(lastWatch(m)!.at, DateTime(2026, 2, 3));
    });
  });

  group('JSON 往返', () {
    test('书籍序列化后能原样读回', () {
      final b = _book(totalPages: 191, rounds: [
        _round(finishedAt: DateTime(2026, 3, 1), logs: [
          ReadingLog(
            id: 'l1',
            at: DateTime(2026, 2, 28, 21, 30),
            pages: 46,
            minutes: 52,
            progress: 24,
            note: '开篇就很抓人。',
          ),
        ]),
      ]);
      final back = Book.fromJson(b.toJson());
      expect(back.title, b.title);
      expect(back.author, b.author);
      expect(back.totalPages, 191);
      expect(back.rounds.length, 1);
      expect(back.rounds.first.finishedAt, DateTime(2026, 3, 1));
      expect(back.rounds.first.logs.first.note, '开篇就很抓人。');
      expect(back.rounds.first.logs.first.at, DateTime(2026, 2, 28, 21, 30));
    });
  });

  group('格式化', () {
    test('时长', () {
      expect(formatDuration(0), '—');
      expect(formatDuration(45), '45分钟');
      expect(formatDuration(60), '1小时');
      expect(formatDuration(80), '1小时20分');
      expect(compactDuration(35), '35m');
      expect(compactDuration(120), '2h');
    });

    test('相对日期', () {
      final now = DateTime.now();
      expect(relativeDay(now), '今天');
      expect(relativeDay(now.subtract(const Duration(days: 1))), '昨天');
      expect(relativeDay(now.subtract(const Duration(days: 3))), '3天前');
    });
  });
}
