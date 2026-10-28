import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// GitHub Pages에 올라가 있는 일별 수집 데이터 (출처: 한국수출입은행)
const ratesCsvUrl = 'https://ex-rate.ohsangplay.com/data/daily.csv';

Future<RatesData> fetchRates({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    // 쿼리스트링으로 캐시를 피해 최신 파일을 받는다
    final uri = Uri.parse(ratesCsvUrl).replace(
      queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
    );
    final res = await c.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) return parseDailyCsv(''); // 첫 수집 전
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return parseDailyCsv(utf8.decode(res.bodyBytes));
  } finally {
    if (client == null) c.close();
  }
}
