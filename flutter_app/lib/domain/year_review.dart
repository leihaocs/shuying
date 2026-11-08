import '../models/models.dart';
import 'period_review.dart';

class YearReview extends PeriodReview {
  /// 年度与免费月度回顾共用同一套范围与累计量归属规则。
  YearReview(List<Book> books, List<Movie> movies, int year, {int? month})
      : super(books, movies,
            start: _start(year, month),
            end: DateTime(year, month == null ? 13 : month + 1, 0));

  static DateTime _start(int year, int? month) {
    if (month != null && (month < 1 || month > 12)) {
      throw ArgumentError.value(month, 'month', '月份应为 1～12');
    }
    return DateTime(year, month ?? 1);
  }
}
