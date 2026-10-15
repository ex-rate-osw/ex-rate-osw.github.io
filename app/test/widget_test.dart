import 'package:ex_rate_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv = '''timestamp_kst,usd,jpy100,eur,source
2026-10-14 15:07,1340.00,850.00,1500.00,twelvedata
2026-10-14 16:07,1341.50,851.00,1502.00,twelvedata
2026-10-15 09:07,1345.00,852.00,1505.00,twelvedata
2026-10-15 10:07,1343.00,849.00,1508.00,twelvedata
''';

void main() {
  final rows = parseRatesCsv(_csv);

  test('CSV를 시간순으로 파싱한다', () {
    expect(rows.length, 4);
    expect(rows.last.ts, '2026-10-15 10:07');
    expect(rows.first.value(Currency.jpy100), 850.0);
  });

  test('헤더만 있거나 깨진 줄은 무시한다', () {
    expect(parseRatesCsv('timestamp_kst,usd,jpy100,eur,source\n'), isEmpty);
    expect(parseRatesCsv('timestamp_kst,usd,jpy100,eur,source\nbroken,line\n'), isEmpty);
  });

  test('전일 종가와 기간 필터', () {
    expect(previousClose(rows, Currency.usd), 1341.5);
    expect(filterRange(rows, RateRange.today).length, 2);
    expect(filterRange(rows, RateRange.week).length, 4);
  });

  test('일자별 요약은 최신 날짜가 먼저', () {
    final d = summarizeByDate(rows, Currency.usd);
    expect(d.first.date, '2026-10-15');
    expect(d.first.open, 1345.0);
    expect(d.first.close, 1343.0);
    expect(d.first.high, 1345.0);
    expect(d.first.low, 1343.0);
    expect(d.first.average, 1344.0);
    expect(d.first.weekday, '목');
  });

  test('숫자 포맷', () {
    expect(formatNumber(1342.98), '1,342.98');
    expect(formatNumber(850.27), '850.27');
    expect(formatNumber(-1234567.5, digits: 1), '-1,234,567.5');
    expect(formatNumber(1342.4, digits: 0), '1,342');
  });
}
