/**
 * 환율 기록 API (Cloudflare Workers)
 * 운영 주소: https://api.ohsangplay.com/exrate/...
 *
 *   GET /exrate/daily.csv   일별 고시 환율 (date,code,name,unit,base,ttb,tts)
 *   GET /exrate/health      {"ok":true}
 *   GET /exrate             서버 정보 (브라우저로 열면 웹사이트로 이동)
 *
 * 데이터 원본은 GitHub 저장소의 data/daily.csv (GitHub Actions가 영업일마다 갱신).
 * 원본을 5분 동안 캐시해서 앱이 10분마다 받아도 GitHub에 부담이 거의 없다.
 */
const BASE = '/exrate';
const WEBSITE = 'https://ex-rate.ohsangplay.com/';
const ORIGINS = [
  'https://raw.githubusercontent.com/ex-rate-osw/ex-rate-osw.github.io/main/data/daily.csv',
  'https://ex-rate.ohsangplay.com/data/daily.csv',
];
const CACHE_SECONDS = 300;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' },
  });

async function dailyCsv(request, ctx) {
  // 앱이 붙이는 ?t= 같은 쿼리는 무시하고 한 가지 키로 캐시
  const cacheKey = new Request(new URL(`${BASE}/daily.csv`, request.url).toString(), { method: 'GET' });
  const cache = caches.default;
  const hit = await cache.match(cacheKey);
  if (hit) return hit;

  let lastStatus = 0;
  for (const origin of ORIGINS) {
    try {
      const res = await fetch(origin, { cf: { cacheTtl: CACHE_SECONDS, cacheEverything: true } });
      lastStatus = res.status;
      if (!res.ok) continue;
      const body = await res.text();
      if (!body.startsWith('date,')) continue; // 엉뚱한 페이지(HTML 등)는 버림
      const out = new Response(body, {
        headers: {
          'content-type': 'text/csv; charset=utf-8',
          'cache-control': `public, max-age=${CACHE_SECONDS}`,
          'access-control-allow-origin': '*',
        },
      });
      ctx.waitUntil(cache.put(cacheKey, out.clone()));
      return out;
    } catch (e) {
      lastStatus = 0;
    }
  }
  return json({ ok: false, error: 'upstream_unavailable', status: lastStatus }, 502);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    let path = url.pathname;
    if (path === BASE || path.startsWith(`${BASE}/`)) path = path.slice(BASE.length) || '/';
    path = path.replace(/\/+$/, '') || '/';

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, HEAD, OPTIONS' },
      });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') return json({ ok: false, error: 'method_not_allowed' }, 405);

    switch (path) {
      case '/':
        if ((request.headers.get('accept') || '').includes('text/html')) return Response.redirect(WEBSITE, 302);
        return json({ name: 'exrate-api', ok: true, data: `${BASE}/daily.csv`, website: WEBSITE });
      case '/health':
        return json({ ok: true });
      case '/daily.csv':
      case '/data/daily.csv':
        return dailyCsv(request, ctx);
      case '/privacy':
        return Response.redirect(`${WEBSITE}privacy.html`, 302);
      default:
        return json({ ok: false, error: 'not_found' }, 404);
    }
  },
};
