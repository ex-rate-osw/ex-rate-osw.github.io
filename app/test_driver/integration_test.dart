import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

// integration_test에서 찍은 화면을 app/screenshots/<이름>.png 로 저장하고,
// 테스트가 끝날 때 넘어온 장별 정보(모자이크할 글자 위치 등)는 <이름>.json 으로 저장
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
    responseDataCallback: (Map<String, dynamic>? data) async {
      final shots = data?['shot_meta'];
      if (shots is Map) {
        for (final entry in shots.entries) {
          final file = File('screenshots/${entry.key}.json');
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(entry.value));
        }
      }
    },
  );
}
