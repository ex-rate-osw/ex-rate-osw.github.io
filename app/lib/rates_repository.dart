import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// 일별 수집 데이터 (출처: 한국수출입은행). 서버(api.ohsangplay.com)가 안 되면 웹사이트의 같은 파일로 받는다.
const ratesCsvUrl = 'https://api.ohsangplay.com/exrate/daily.csv';
const ratesCsvFallbackUrl = 'https://ex-rate.ohsangplay.com/data/daily.csv';

Future<RatesData> fetchRates({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    Object? lastError;
    for (final url in [ratesCsvUrl, ratesCsvFallbackUrl]) {
      try {
        // 쿼리스트링으로 캐시를 피해 최신 파일을 받는다
        final uri = Uri.parse(url).replace(
          queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
        );
        final res = await c.get(uri).timeout(const Duration(seconds: 15));
        if (res.statusCode == 404 && url == ratesCsvFallbackUrl) {
          return parseDailyCsv(''); // 첫 수집 전
        }
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        return parseDailyCsv(utf8.decode(res.bodyBytes));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('환율 데이터를 받지 못했어요');
  } finally {
    if (client == null) c.close();
  }
}
