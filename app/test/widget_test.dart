import 'package:ex_rate_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-05(월) ~ 10-16(금), 10-09(금)은 공휴일로 없음 + 9월 마지막 날
const _csv = '''date,code,name,unit,base,ttb,tts
2026-09-30,USD,미국 달러,1,1330.00,1316.70,1343.30
2026-10-05,USD,미국 달러,1,1340.00,1326.60,1353.40
2026-10-06,USD,미국 달러,1,1342.00,1328.58,1355.42
2026-10-07,USD,미국 달러,1,1338.00,1324.62,1351.38
2026-10-08,USD,미국 달러,1,1344.00,1330.56,1357.44
2026-10-12,USD,미국 달러,1,1350.00,1336.50,1363.50
2026-10-16,USD,미국 달러,1,1346.00,1332.54,1359.46
2026-10-16,JPY,일본 옌,100,850.27,841.77,858.77
2026-10-16,AED,아랍에미리트 디르함,1,365.25,361.60,368.90
''';

void main() {
  final data = parseDailyCsv(_csv);
  final usd = data.series['USD']!;

  test('CSV를 통화별로 날짜순 파싱', () {
    expect(usd.length, 7);
    expect(usd.first.date, '2026-09-30');
    expect(data.info('JPY')!.unit, 100);
    expect(data.info('JPY')!.unitText, 'JPY 100');
    expect(data.lastDate, '2026-10-16');
  });

  test('고정 통화가 먼저, 나머지는 이름순', () {
    expect(data.currencies.map((c) => c.code).toList(), ['USD', 'JPY', 'AED']);
  });

  test('빈 파일·헤더만·깨진 줄', () {
    expect(parseDailyCsv('').isEmpty, isTrue);
    expect(parseDailyCsv('date,code,name,unit,base,ttb,tts\n').isEmpty, isTrue);
    expect(parseDailyCsv('date,code,name,unit,base,ttb,tts\nbroken,line\n').isEmpty, isTrue);
  });

  test('일별: 직전 영업일 값 포함', () {
    final days = groupRates(usd, RateView.day);
    expect(days.length, 7);
    expect(days.last.key, '2026-10-16');
    expect(days.last.prev, 1350.0);
    expect(days.first.prev, isNull);
  });

  test('주별: 월요일 기준으로 묶고 평균·시가·종가·고가·저가', () {
    final weeks = groupRates(usd, RateView.week);
    expect(weeks.map((w) => w.key).toList(), ['2026-09-28', '2026-10-05', '2026-10-12']);
    final w = weeks[1];
    expect(w.days, 4);
    expect(w.open, 1340.0);
    expect(w.close, 1344.0);
    expect(w.high, 1344.0);
    expect(w.low, 1338.0);
    expect(w.value, 1341.0);
  });

  test('월별', () {
    final months = groupRates(usd, RateView.month);
    expect(months.map((m) => m.key).toList(), ['2026-09', '2026-10']);
    expect(months.last.days, 6);
  });

  test('라벨', () {
    expect(weekStart('2026-10-16'), '2026-10-12');
    expect(weekStart('2026-10-12'), '2026-10-12');
    expect(shortLabel('2026-10-12', RateView.week), '10/12주');
    expect(longLabel('2026-10-12', RateView.week), '2026-10-12 ~ 10/16');
    expect(longLabel('2026-10-16', RateView.day), '2026-10-16 (금)');
    expect(shortLabel('2026-10', RateView.month), '26.10');
    expect(longLabel('2026-10', RateView.month), '2026년 10월');
  });

  test('숫자 포맷', () {
    expect(formatNumber(1342.98), '1,342.98');
    expect(formatNumber(-1234567.5, digits: 1), '-1,234,567.5');
  });
}
