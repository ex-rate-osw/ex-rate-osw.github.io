// 스토어 스크린샷 자동 촬영.
// 실행: flutter drive --driver=test_driver/integration_test.dart \
//         --target=integration_test/screenshots_test.dart -d <시뮬레이터 UDID>
// 결과: app/screenshots/01.png ~ 05.png
import 'package:ex_rate_app/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> wait(WidgetTester tester, [int ms = 900]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 40}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('화면을 기다리다 시간 초과: $finder');
  }

  Future<void> shot(String name) async {
    await binding.takeScreenshot(name);
  }

  Future<void> chip(WidgetTester tester, String label) async {
    final f = find.text(label);
    await tester.ensureVisible(f);
    await wait(tester, 300);
    await tester.tap(f);
    await wait(tester);
  }

  Future<void> view(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await wait(tester);
  }

  Future<void> toTop(WidgetTester tester) async {
    await tester.fling(find.byType(ListView).first, const Offset(0, 3000), 3000);
    await wait(tester, 1200);
  }

  testWidgets('store screenshots', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(const ExRateApp());
    await waitFor(tester, find.textContaining('마지막 고시일'));
    await waitFor(tester, find.byType(LineChart));
    await wait(tester, 1500);

    // 01 미국 달러 · 일별 · 맨 위
    await chip(tester, '미국 달러 USD');
    await view(tester, '일별');
    await shot('01');

    // 02 일본 옌 · 주별 · 그래프 툴팁 (손가락을 누른 채로 촬영)
    await chip(tester, '일본 옌 JPY');
    await view(tester, '주별');
    final chart = tester.getRect(find.byType(LineChart));
    final gesture = await tester.startGesture(Offset(chart.left + chart.width * 0.62, chart.center.dy));
    await wait(tester, 700);
    await shot('02');
    await gesture.up();
    await wait(tester, 500);

    // 03 유로 · 월별
    await chip(tester, '유로 EUR');
    await view(tester, '월별');
    await shot('03');

    // 04 미국 달러 · 일별 · 아래로 스크롤해 기록 목록
    await chip(tester, '미국 달러 USD');
    await view(tester, '일별');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await wait(tester, 1200);
    await shot('04');

    // 05 다크 모드 · 미국 달러 · 일별 · 맨 위
    await toTop(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await wait(tester, 1200);
    await shot('05');

    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpWidget(const SizedBox()); // 자동 갱신 타이머 정리
  });
}
