// 스토어 스크린샷 자동 촬영.
// 실행: flutter drive --driver=test_driver/integration_test.dart \
//         --target=integration_test/screenshots_test.dart -d <시뮬레이터 UDID>
// 결과: app/screenshots/01.png ~ 05.png
import 'package:ex_rate_app/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // 모자이크할 글자: 날짜·시각·금액·등락률·그래프 눈금 숫자
  final sensitive = RegExp(
    r'\d{4}-\d{2}-\d{2}'          // 2026-10-28
    r'|\d{4}년 \d{1,2}월'          // 2026년 10월
    r'|\d{1,2}:\d{2}'              // 13:34
    r'|\d{1,2}/\d{1,2}주?'         // 10/7, 11/3주
    r'|[+-]?[\d,]+\.\d+%?'        // 1,324.30 / 0.13% / 25.09
    r'|^\s*[\d,]{3,}\s*$',       // 그래프 눈금 1,450 / 950
  );

  // 화면에 보이는 글자 중 sensitive에 해당하는 부분의 위치(논리 픽셀)
  List<Map<String, double>> sensitiveRects(WidgetTester tester) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final screen = Offset.zero & size;
    final rects = <Map<String, double>>[];
    for (final e in find.byType(RichText).evaluate()) {
      final rp = e.renderObject;
      if (rp is! RenderParagraph || !rp.attached || !rp.hasSize) continue;
      final text = rp.text.toPlainText();
      for (final m in sensitive.allMatches(text)) {
        var start = m.start, end = m.end;
        while (start < end && text[start] == ' ') start++;
        while (end > start && text[end - 1] == ' ') end--;
        if (start >= end) continue;
        final boxes = rp.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end));
        final transform = rp.getTransformTo(null);
        for (final b in boxes) {
          final r = MatrixUtils.transformRect(transform, b.toRect());
          if (!r.overlaps(screen)) continue;
          rects.add({'l': r.left, 't': r.top, 'r': r.right, 'b': r.bottom});
        }
      }
    }
    return rects;
  }

  // 테스트가 누른 자리에 잠깐 그려지는 터치 표시가 사라진 뒤에 찍는다 (hold: 누른 채로 찍을 때)
  // tooltip: 그래프 툴팁(캔버스에 그려져 위치를 알 수 없음)은 이미지에서 찾아 가리도록 표시
  // 장마다 모자이크 정보를 모았다가 테스트가 끝날 때 reportData로 한 번에 넘긴다
  // (iOS에서는 takeScreenshot에 추가 정보를 함께 넘길 수 없음)
  final meta = <String, Object?>{};

  Future<void> shot(WidgetTester tester, String name, {bool hold = false, bool tooltip = false}) async {
    if (!hold) await wait(tester, 2500);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    meta[name] = {
      'width': size.width,
      'height': size.height,
      'rects': sensitiveRects(tester),
      'tooltip': tooltip,
      'dark': tester.platformDispatcher.platformBrightness == Brightness.dark,
    };
    await binding.takeScreenshot(name);
  }

  // 바깥 목록의 스크롤 위치를 직접 지정 (손가락으로 끌면 그래프가 터치를 가져갈 수 있어서)
  Future<void> scrollTo(WidgetTester tester, double offset) async {
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final pos = state.position;
    pos.jumpTo(offset.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    await wait(tester, 900);
  }

  Future<void> toTop(WidgetTester tester) => scrollTo(tester, 0);

  Future<void> chip(WidgetTester tester, String label) async {
    final f = find.text(label);
    // 가로 통화 칩 목록은 화면 밖 칩을 만들지 않으므로, 안 보이면 칩 목록을 스크롤해서 찾는다
    final chips = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
    for (var i = 0; i < 8 && f.evaluate().isEmpty; i++) {
      await tester.drag(chips.first, const Offset(300, 0)); // 앞쪽으로
      await wait(tester, 300);
    }
    for (var i = 0; i < 12 && f.evaluate().isEmpty; i++) {
      await tester.drag(chips.first, const Offset(-300, 0)); // 뒤쪽으로
      await wait(tester, 300);
    }
    await tester.ensureVisible(f);
    await wait(tester, 300);
    await tester.tap(f);
    await wait(tester);
    await toTop(tester); // ensureVisible이 바깥 목록까지 내려서, 화면 맨 위로 되돌린다
  }

  Future<void> view(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await wait(tester);
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
    await shot(tester, '01');

    // 02 일본 옌 · 주별 · 그래프 툴팁 (손가락을 누른 채로 촬영)
    await chip(tester, '일본 옌 JPY');
    await view(tester, '주별');
    final chart = tester.getRect(find.byType(LineChart));
    final gesture = await tester.startGesture(Offset(chart.left + chart.width * 0.62, chart.center.dy));
    await wait(tester, 700);
    await shot(tester, '02', hold: true, tooltip: true);
    await gesture.up();
    await wait(tester, 500);

    // 03 유로 · 월별
    await chip(tester, '유로 EUR');
    await view(tester, '월별');
    await shot(tester, '03');

    // 04 미국 달러 · 일별 · 아래로 스크롤해 기록 목록
    await chip(tester, '미국 달러 USD');
    await view(tester, '일별');
    await scrollTo(tester, 900);
    await shot(tester, '04');

    // 05 다크 모드 · 미국 달러 · 일별 · 맨 위
    await toTop(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await wait(tester, 1200);
    await shot(tester, '05');

    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpWidget(const SizedBox()); // 자동 갱신 타이머 정리
    binding.reportData = {'shot_meta': meta}; // 'screenshots'는 integration_test가 내부에서 쓰는 키라 피함
  });
}
