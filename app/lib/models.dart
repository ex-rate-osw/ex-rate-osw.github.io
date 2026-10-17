/// 일별 환율 데이터 모델과 일·주·월 집계 로직.
/// 웹 페이지(index.html)와 같은 규칙으로 계산한다.
library;

/// 칩 맨 앞에 보여줄 통화 순서 (나머지는 이름순)
const pinnedCodes = ['USD', 'JPY', 'EUR', 'CNH', 'GBP', 'HKD', 'AUD', 'CAD', 'CHF', 'SGD', 'THB'];

enum RateView {
  day('일별', 60, '최근 60영업일'),
  week('주별', 52, '최근 52주 · 주 평균'),
  month('월별', 24, '최근 24개월 · 월 평균');

  const RateView(this.label, this.count, this.description);
  final String label;
  final int count;
  final String description;
}

/// 하루치 고시 값
class DailyRate {
  const DailyRate({required this.date, required this.base, required this.ttb, required this.tts});

  /// 'YYYY-MM-DD'
  final String date;

  /// 매매기준율
  final double base;

  /// 송금 받을 때 (전신환 매입율)
  final double ttb;

  /// 송금 보낼 때 (전신환 매도율)
  final double tts;
}

class CurrencyInfo {
  const CurrencyInfo({required this.code, required this.name, required this.unit});
  final String code;
  final String name;

  /// 기준 단위 (JPY, IDR은 100)
  final int unit;

  String get unitText => '$code $unit';
}

/// 그래프의 점 하나 (하루, 한 주, 한 달)
class RatePoint {
  const RatePoint({
    required this.key,
    required this.value,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.days,
    this.prev,
    this.ttb,
    this.tts,
  });

  /// 일별: 'YYYY-MM-DD', 주별: 그 주 월요일 'YYYY-MM-DD', 월별: 'YYYY-MM'
  final String key;

  /// 일별은 그날 매매기준율, 주·월별은 평균
  final double value;
  final double open;
  final double close;
  final double high;
  final double low;
  final int days;

  /// 일별에서 직전 영업일 값
  final double? prev;
  final double? ttb;
  final double? tts;
}

class RatesData {
  RatesData(this.currencies, this.series);

  /// 표시 순서대로 정렬된 통화 목록
  final List<CurrencyInfo> currencies;

  /// 통화 코드 → 날짜순 일별 값
  final Map<String, List<DailyRate>> series;

  bool get isEmpty => series.isEmpty;

  String? get lastDate {
    String? m;
    for (final list in series.values) {
      if (list.isNotEmpty && (m == null || list.last.date.compareTo(m) > 0)) m = list.last.date;
    }
    return m;
  }

  CurrencyInfo? info(String code) {
    for (final c in currencies) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// daily.csv (date,code,name,unit,base,ttb,tts) 파싱
RatesData parseDailyCsv(String text) {
  final lines = text.trim().split(RegExp(r'\r?\n'));
  final series = <String, List<DailyRate>>{};
  final infos = <String, CurrencyInfo>{};
  if (lines.length > 1) {
    final head = lines.first.split(',');
    for (final line in lines.skip(1)) {
      final cols = line.split(',');
      final o = <String, String>{
        for (var i = 0; i < head.length && i < cols.length; i++) head[i]: cols[i],
      };
      final date = o['date'] ?? '';
      final code = o['code'] ?? '';
      final base = double.tryParse(o['base'] ?? '');
      if (date.length != 10 || code.isEmpty || base == null || base <= 0) continue;
      series.putIfAbsent(code, () => []).add(DailyRate(
            date: date,
            base: base,
            ttb: double.tryParse(o['ttb'] ?? '') ?? 0,
            tts: double.tryParse(o['tts'] ?? '') ?? 0,
          ));
      infos[code] = CurrencyInfo(code: code, name: o['name'] ?? code, unit: int.tryParse(o['unit'] ?? '') ?? 1);
    }
  }
  for (final list in series.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  final pinned = pinnedCodes.where(infos.containsKey).map((c) => infos[c]!).toList();
  final rest = infos.values.where((c) => !pinnedCodes.contains(c.code)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return RatesData([...pinned, ...rest], series);
}

DateTime _d(String s) => DateTime.parse(s);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 그 주 월요일 날짜
String weekStart(String date) {
  final d = _d(date);
  return _iso(d.subtract(Duration(days: d.weekday - 1)));
}

/// 일·주·월별로 묶은 그래프 점 (오래된 것부터)
List<RatePoint> groupRates(List<DailyRate> list, RateView view) {
  if (list.isEmpty) return const [];
  if (view == RateView.day) {
    final start = list.length > view.count ? list.length - view.count : 0;
    return [
      for (var i = start; i < list.length; i++)
        RatePoint(
          key: list[i].date,
          value: list[i].base,
          open: list[i].base,
          close: list[i].base,
          high: list[i].base,
          low: list[i].base,
          days: 1,
          prev: i > 0 ? list[i - 1].base : null,
          ttb: list[i].ttb,
          tts: list[i].tts,
        ),
    ];
  }
  final groups = <String, List<double>>{};
  for (final r in list) {
    final key = view == RateView.week ? weekStart(r.date) : r.date.substring(0, 7);
    groups.putIfAbsent(key, () => []).add(r.base);
  }
  final entries = groups.entries.toList();
  final start = entries.length > view.count ? entries.length - view.count : 0;
  return [
    for (final e in entries.sublist(start))
      RatePoint(
        key: e.key,
        value: e.value.reduce((a, b) => a + b) / e.value.length,
        open: e.value.first,
        close: e.value.last,
        high: e.value.reduce((a, b) => a > b ? a : b),
        low: e.value.reduce((a, b) => a < b ? a : b),
        days: e.value.length,
      ),
  ];
}

const _dow = '월화수목금토일';

String _md(String s) => '${int.parse(s.substring(5, 7))}/${int.parse(s.substring(8, 10))}';

/// 그래프 축 라벨
String shortLabel(String key, RateView view) => switch (view) {
      RateView.day => _md(key),
      RateView.week => '${_md(key)}주',
      RateView.month => '${key.substring(2, 4)}.${key.substring(5, 7)}',
    };

/// 툴팁·목록 라벨
String longLabel(String key, RateView view) {
  switch (view) {
    case RateView.day:
      return '$key (${_dow[_d(key).weekday - 1]})';
    case RateView.week:
      return '$key ~ ${_md(_iso(_d(key).add(const Duration(days: 4))))}';
    case RateView.month:
      return '${key.substring(0, 4)}년 ${int.parse(key.substring(5, 7))}월';
  }
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
