import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'rate_chart.dart';
import 'rates_repository.dart';

void main() => runApp(const ExRateApp());

const privacyPolicyUrl = 'https://ex-rate.ohsangplay.com/privacy.html';

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
  /// 앱이 화면에 떠 있는 동안 자동으로 다시 받아오는 간격
  static const _autoRefreshInterval = Duration(minutes: 10);

  RatesData _data = RatesData(const [], const {});
  bool _loading = true; // 첫 로딩
  bool _refreshing = false; // 받아오는 중 (중복 요청 방지)
  String? _error;
  DateTime? _checkedAt;
  Timer? _timer;
  String _code = 'USD';
  RateView _view = RateView.day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _load(); // 앱으로 돌아오면 바로 갱신 (타이머도 새로 시작)
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel(); // 백그라운드에서는 받아오지 않음
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// 새로고침 버튼, 당겨서 새로고침, 앱 복귀, 자동 타이머가 모두 이 함수를 쓴다.
  /// 끝나면 타이머를 처음부터 다시 10분으로 건다.
  Future<void> _load() async {
    if (_refreshing) return;
    _timer?.cancel();
    if (mounted) setState(() => _refreshing = true);
    try {
      final data = await fetchRates();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        if (data.info(_code) == null && data.currencies.isNotEmpty) _code = data.currencies.first.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '데이터를 불러오지 못했어요 ($e)');
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _loading = false;
          _checkedAt = DateTime.now();
        });
        _scheduleNext();
      }
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed && state != AppLifecycleState.inactive) {
      return; // 백그라운드면 걸지 않음, 돌아올 때 resumed에서 다시 받음
    }
    _timer = Timer(_autoRefreshInterval, _load);
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final info = _data.info(_code);
    final list = _data.series[_code] ?? const <DailyRate>[];
    final points = groupRates(list, _view);
    final lastDate = _data.lastDate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('환율 기록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refreshing ? null : _load,
            icon: _refreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
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
                  Text(lastDate == null ? '아직 기록이 없어요' : '마지막 고시일 ${longLabel(lastDate, RateView.day)}',
                      style: small),
                  if (_checkedAt != null)
                    Text(
                      '${_hhmm(_checkedAt!)} 확인 · 다음 자동 갱신 ${_hhmm(_checkedAt!.add(_autoRefreshInterval))}',
                      style: small,
                    ),
                  const SizedBox(height: 10),
                  _CurrencyChips(
                    currencies: _data.currencies,
                    selected: _code,
                    onSelected: (c) => setState(() => _code = c),
                  ),
                  const SizedBox(height: 10),
                  if (info != null && list.isNotEmpty) _SummaryCard(info: info, list: list),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${info?.name ?? ''} ${_view.label} 추이', style: text.titleMedium),
                                Text(_view.description, style: small),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SegmentedButton<RateView>(
                              showSelectedIcon: false,
                              segments: [
                                for (final v in RateView.values) ButtonSegment(value: v, label: Text(v.label)),
                              ],
                              selected: {_view},
                              onSelectionChanged: (s) => setState(() => _view = s.first),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RateChart(points: points, view: _view),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text('${_view.label} 기록 · ${info?.name ?? ''}', style: text.titleMedium),
                  ),
                  for (final p in points.reversed) _PointTile(point: p, view: _view),
                  const SizedBox(height: 16),
                  Text(
                    '매매기준율 기준 · 출처: 한국수출입은행\n영업일 오전 11시 전후 하루 1번 고시 · 참고용이며 실제 거래 환율과 다를 수 있어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
                      child: const Text('개인정보처리방침', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CurrencyChips extends StatelessWidget {
  const _CurrencyChips({required this.currencies, required this.selected, required this.onSelected});

  final List<CurrencyInfo> currencies;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: currencies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = currencies[i];
          return ChoiceChip(
            label: Text('${c.name} ${c.code}'),
            selected: c.code == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(c.code),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.info, required this.list});

  final CurrencyInfo info;
  final List<DailyRate> list;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final last = list.last;
    final prev = list.length > 1 ? list[list.length - 2].base : null;

    Widget diff;
    if (prev == null) {
      diff = Text('이전 기록 없음', style: small);
    } else {
      final d = last.base - prev;
      final pct = d / prev * 100;
      final color = d > 0 ? _upColor : (d < 0 ? _downColor : scheme.onSurfaceVariant);
      final sign = d > 0 ? '▲' : (d < 0 ? '▼' : '–');
      diff = Text.rich(TextSpan(children: [
        TextSpan(
          text: '$sign ${formatNumber(d.abs())} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
          style: TextStyle(fontSize: 13, color: color),
        ),
        TextSpan(text: '  전 영업일 대비', style: small),
      ]));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${info.name} · ${info.unitText} · ${longLabel(last.date, RateView.day)} 고시', style: small),
            const SizedBox(height: 4),
            Text(
              '${formatNumber(last.base)}원',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 2),
            diff,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('송금 보낼 때  ${last.tts > 0 ? formatNumber(last.tts) : '–'}', style: small)),
                Expanded(child: Text('송금 받을 때  ${last.ttb > 0 ? formatNumber(last.ttb) : '–'}', style: small)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.point, required this.view});

  final RatePoint point;
  final RateView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = point;
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final numStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);

    final Widget detail;
    final Widget trailing;
    if (view == RateView.day) {
      final d = p.prev == null ? null : p.value - p.prev!;
      final color = d == null || d == 0 ? scheme.onSurfaceVariant : (d > 0 ? _upColor : _downColor);
      detail = Text(
        '보낼 때 ${p.tts != null && p.tts! > 0 ? formatNumber(p.tts!) : '–'} · 받을 때 ${p.ttb != null && p.ttb! > 0 ? formatNumber(p.ttb!) : '–'}',
        style: small,
      );
      trailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatNumber(p.value), style: numStyle),
          Text(d == null ? '–' : '${d > 0 ? '▲' : d < 0 ? '▼' : ''} ${formatNumber(d.abs())}',
              style: TextStyle(fontSize: 12, color: color)),
        ],
      );
    } else {
      detail = Text(
        '시 ${formatNumber(p.open)} · 고 ${formatNumber(p.high)} · 저 ${formatNumber(p.low)} · 종 ${formatNumber(p.close)}\n고시 ${p.days}일',
        style: small,
      );
      trailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [Text('평균', style: small), Text(formatNumber(p.value), style: numStyle)],
      );
    }

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
                  Text(longLabel(p.key, view), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  detail,
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
