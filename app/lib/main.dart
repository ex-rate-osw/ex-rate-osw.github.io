import 'package:flutter/material.dart';

import 'models.dart';
import 'rate_chart.dart';
import 'rates_repository.dart';

void main() => runApp(const ExRateApp());

// 한국식 등락 색상: 상승 빨강, 하락 파랑
const _upColor = Color(0xFFDC2626);
const _downColor = Color(0xFF2563EB);

class ExRateApp extends StatelessWidget {
  const ExRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB);
    return MaterialApp(
      title: '환율 기록',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<RateRecord> _rows = const [];
  bool _loading = true;
  String? _error;
  Currency _currency = Currency.usd;
  RateRange _range = RateRange.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱으로 다시 돌아올 때마다 최신 데이터로 갱신
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await fetchRates();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했어요 ($e)';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _rows.isEmpty ? null : _rows.last;
    final ranged = filterRange(_rows, _range);

    return Scaffold(
      appBar: AppBar(
        title: const Text('환율 기록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (_error != null)
                    Card(
                      color: scheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                      ),
                    ),
                  Text(
                    last == null ? '기록 없음' : '마지막 기록 ${last.ts} (KST)',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  for (final c in Currency.values)
                    _CurrencyCard(
                      currency: c,
                      rows: _rows,
                      selected: c == _currency,
                      onTap: () => setState(() => _currency = c),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '${_currency.label} 추이 (${_currency.unit})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SegmentedButton<RateRange>(
                              showSelectedIcon: false,
                              segments: [
                                for (final r in RateRange.values)
                                  ButtonSegment(value: r, label: Text(r.label)),
                              ],
                              selected: {_range},
                              onSelectionChanged: (s) => setState(() => _range = s.first),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RateChart(rows: ranged, currency: _currency, range: _range),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text('일자별 · ${_currency.label}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final d in summarizeByDate(ranged, _currency)) _DailyTile(summary: d),
                  const SizedBox(height: 16),
                  Text(
                    '시장 환율 기준이라 은행 고시환율과 차이가 있을 수 있어요.\n데이터: Twelve Data / Rates By Exchange Rate API',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.currency,
    required this.rows,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final List<RateRecord> rows;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = rows.isEmpty ? null : rows.last.value(currency);
    final prev = previousClose(rows, currency);

    Widget diff;
    if (now == null || prev == null) {
      diff = Text('전일 데이터 없음', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant));
    } else {
      final d = now - prev;
      final pct = d / prev * 100;
      final color = d > 0 ? _upColor : (d < 0 ? _downColor : scheme.onSurfaceVariant);
      final sign = d > 0 ? '▲' : (d < 0 ? '▼' : '–');
      diff = Text(
        '$sign ${formatNumber(d.abs())} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
        style: TextStyle(fontSize: 13, color: color),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${currency.label} · ${currency.unit}',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    diff,
                  ],
                ),
              ),
              Text(
                now == null ? '–' : '${formatNumber(now)}원',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = summary;
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.date} (${s.weekday})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '시 ${formatNumber(s.open)} · 고 ${formatNumber(s.high)} · 저 ${formatNumber(s.low)}',
                    style: small,
                  ),
                  Text('평균 ${formatNumber(s.average)} · 기록 ${s.count}회', style: small),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('종가', style: small),
                Text(
                  formatNumber(s.close),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
