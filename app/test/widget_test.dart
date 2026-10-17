import 'package:ex_rate_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv = '''slot_kst,timestamp_kst,usd,jpy100,eur,source
2026-10-14 15:00,2026-10-14 15:07,1340.00,850.00,1500.00,twelvedata
2026-10-14 16:00,2026-10-14 16:47,1341.50,851.00,1502.00,twelvedata
2026-10-15 09:00,2026-10-15 09:13,1345.00,852.00,1505.00,twelvedata
2026-10-15 10:00,2026-10-15 10:58,1343.00,849.00,1508.00,twelvedata
''';

void main() {
  final rows = parseRatesCsv(_csv);

  test('CSV를 시간순으로 파싱한다', () {
    expect(rows.length, 4);
    expect(rows.last.slot, '2026-10-15 10:00');
    expect(rows.last.ts, '2026-10-15 10:58');
    expect(rows.last.hourLabel, '10시');
    expect(rows.last.slotLabel, '10/15 10시');
    expect(rows.last.collectedAt, '10:58');
    expect(rows.last.howCollected, '10:58 수집');
    expect(rows.first.value(Currency.jpy100), 850.0);
  });

  test('예전 형식(slot_kst 없음)은 수집 시각의 정시로 채운다', () {
    final old = parseRatesCsv('timestamp_kst,usd,jpy100,eur,source\n2026-10-16 13:43,1348.2,851.9,1511.4,twelvedata\n');
    expect(old.single.slot, '2026-10-16 13:00');
    expect(old.single.hourLabel, '13시');
  });

  test('시간봉으로 채운 기록 표시', () {
    final r = parseRatesCsv('slot_kst,timestamp_kst,usd,jpy100,eur,source\n'
        '2026-10-16 14:00,2026-10-16 14:00,1340.1,859.0,1500.1,twelvedata-1h\n').single;
    expect(r.isBackfilled, isTrue);
    expect(r.howCollected, '정각 시세로 보충');
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
