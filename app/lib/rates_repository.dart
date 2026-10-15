import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// GitHub Pages에 올라가 있는 수집 데이터
const ratesCsvUrl = 'https://ex-rate-osw.github.io/data/rates.csv';

Future<List<RateRecord>> fetchRates({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    // 쿼리스트링으로 캐시를 피해 최신 파일을 받는다
    final uri = Uri.parse(ratesCsvUrl).replace(
      queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
    );
    final res = await c.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return parseRatesCsv(utf8.decode(res.bodyBytes));
  } finally {
    if (client == null) c.close();
  }
}
