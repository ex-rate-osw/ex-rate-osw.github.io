import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';

class RateChart extends StatelessWidget {
  const RateChart({super.key, required this.points, required this.view});

  final List<RatePoint> points;
  final RateView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);

    if (points.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Text('아직 수집된 데이터가 없어요', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    final values = points.map((p) => p.value).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = math.max((maxV - minV) * 0.1, maxV * 0.002);
    final axisDigits = (maxV - minV) < 5 ? 2 : 0;
    final labelEvery = math.max(1, (points.length / 4).ceil());

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: points.length == 1 ? 1 : (points.length - 1).toDouble(),
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
                reservedSize: 60,
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
                  if (value != i || i < 0 || i >= points.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(shortLabel(points[i].key, view), style: axisStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touched) => touched.map((s) {
                final p = points[s.x.round().clamp(0, points.length - 1)];
                final text = view == RateView.day
                    ? '${longLabel(p.key, view)}\n${formatNumber(p.value)}원'
                    : '${longLabel(p.key, view)}\n평균 ${formatNumber(p.value)}원\n'
                        '시 ${formatNumber(p.open)} · 종 ${formatNumber(p.close)}\n'
                        '고 ${formatNumber(p.high)} · 저 ${formatNumber(p.low)}';
                return LineTooltipItem(text, TextStyle(color: scheme.onInverseSurface, fontSize: 12));
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: scheme.primary,
              barWidth: 2,
              dotData: FlDotData(show: values.length <= 30),
              belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
