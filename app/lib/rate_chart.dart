import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';

class RateChart extends StatelessWidget {
  const RateChart({
    super.key,
    required this.rows,
    required this.currency,
    required this.range,
  });

  final List<RateRecord> rows;
  final Currency currency;
  final RateRange range;

  String _label(int i) {
    final r = rows[i];
    return range == RateRange.today ? r.hourLabel : r.slotLabel;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);

    if (rows.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Text('아직 수집된 데이터가 없어요', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    final values = rows.map((r) => r.value(currency)).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = math.max((maxV - minV) * 0.1, 1.0);
    final axisDigits = (maxV - minV) < 5 ? 1 : 0;
    final labelEvery = math.max(1, (rows.length / 4).ceil());

    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: values.length == 1 ? 1 : (values.length - 1).toDouble(),
          minY: minV - pad,
          maxY: maxV + pad,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                  return Text(formatNumber(value, digits: axisDigits), style: axisStyle);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (value != i || i < 0 || i >= rows.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_label(i), style: axisStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (touched) => touched.map((s) {
                final r = rows[s.x.round().clamp(0, rows.length - 1)];
                return LineTooltipItem(
                  '${r.slotLabel} 기록\n${formatNumber(s.y)}원 (${r.collectedAt} 수집)',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: scheme.primary,
              barWidth: 2,
              dotData: FlDotData(show: values.length <= 24),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
