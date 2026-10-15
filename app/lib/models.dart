/// 환율 기록 데이터 모델과 계산 로직.
/// 웹 페이지(index.html)와 같은 규칙으로 계산한다.
library;

enum Currency {
  usd('미국 달러', 'USD 1'),
  jpy100('일본 엔', 'JPY 100'),
  eur('유로', 'EUR 1');

  const Currency(this.label, this.unit);
  final String label;
  final String unit;
}

enum RateRange {
  today('오늘'),
  week('7일'),
  month('30일'),
  all('전체');

  const RateRange(this.label);
  final String label;
}

class RateRecord {
  const RateRecord({
    required this.ts,
    required this.usd,
    required this.jpy100,
    required this.eur,
    required this.source,
  });

  /// 'YYYY-MM-DD HH:MM' (한국시간)
  final String ts;
  final double usd;
  final double jpy100;
  final double eur;
  final String source;

  String get date => ts.substring(0, 10);

  /// 기록끼리 시간 차이를 계산하는 용도 (모두 KST라 타임존 변환 불필요)
  DateTime get time => DateTime.parse(ts.replaceFirst(' ', 'T'));

  double value(Currency c) => switch (c) {
        Currency.usd => usd,
        Currency.jpy100 => jpy100,
        Currency.eur => eur,
      };
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.average,
    required this.count,
  });

  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double average;
  final int count;

  String get weekday => '월화수목금토일'[DateTime.parse(date).weekday - 1];
}

/// rates.csv 내용을 시간순 기록 목록으로 변환
List<RateRecord> parseRatesCsv(String text) {
  final lines = text.trim().split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return [];
  final head = lines.first.split(',');
  final rows = <RateRecord>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final cols = line.split(',');
    final o = <String, String>{
      for (var i = 0; i < head.length && i < cols.length; i++) head[i]: cols[i],
    };
    final ts = o['timestamp_kst'] ?? '';
    final usd = double.tryParse(o['usd'] ?? '');
    final jpy = double.tryParse(o['jpy100'] ?? '');
    final eur = double.tryParse(o['eur'] ?? '');
    if (ts.length < 16 || usd == null || jpy == null || eur == null) continue;
    rows.add(RateRecord(ts: ts, usd: usd, jpy100: jpy, eur: eur, source: o['source'] ?? ''));
  }
  rows.sort((a, b) => a.ts.compareTo(b.ts));
  return rows;
}

/// 마지막 기록 기준으로 기간을 자른다 (주말에도 그래프가 비지 않도록)
List<RateRecord> filterRange(List<RateRecord> rows, RateRange range) {
  if (rows.isEmpty) return const [];
  final last = rows.last;
  switch (range) {
    case RateRange.all:
      return rows;
    case RateRange.today:
      return rows.where((r) => r.date == last.date).toList();
    case RateRange.week:
    case RateRange.month:
      final days = range == RateRange.week ? 7 : 30;
      final cutoff = last.time.subtract(Duration(days: days));
      return rows.where((r) => !r.time.isBefore(cutoff)).toList();
  }
}

/// 마지막 기록 날짜 이전의 가장 최근 값 (전일 종가)
double? previousClose(List<RateRecord> rows, Currency c) {
  if (rows.isEmpty) return null;
  final lastDate = rows.last.date;
  for (var i = rows.length - 1; i >= 0; i--) {
    if (rows[i].date != lastDate) return rows[i].value(c);
  }
  return null;
}

/// 일자별 시가·고가·저가·종가·평균 (최신 날짜가 먼저)
List<DailySummary> summarizeByDate(List<RateRecord> rows, Currency c) {
  final byDate = <String, List<double>>{};
  for (final r in rows) {
    byDate.putIfAbsent(r.date, () => []).add(r.value(c));
  }
  final result = byDate.entries.map((e) {
    final v = e.value;
    var high = v.first, low = v.first, sum = 0.0;
    for (final x in v) {
      if (x > high) high = x;
      if (x < low) low = x;
      sum += x;
    }
    return DailySummary(
      date: e.key,
      open: v.first,
      high: high,
      low: low,
      close: v.last,
      average: sum / v.length,
      count: v.length,
    );
  }).toList();
  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

/// 1342.98 → '1,342.98'
String formatNumber(double v, {int digits = 2}) {
  final negative = v < 0;
  final parts = v.abs().toStringAsFixed(digits).split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  final frac = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}$buf$frac';
}
