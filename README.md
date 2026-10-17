# ex-rate-osw

달러(USD) · 엔화(JPY 100) · 유로(EUR)의 원화 환율을 매시간 자동으로 기록하고, 그래프와 일자별 표로 보여주는 저장소입니다. 서버나 DB 없이 GitHub Actions + GitHub Pages만으로 동작합니다.

```
.github/workflows/collect.yml   매시간 실행되는 수집 워크플로
scripts/collect.py              환율을 받아 CSV에 한 줄 추가 (파이썬 표준 라이브러리만 사용)
data/rates.csv                  수집된 기록 (slot_kst=몇 시 기록인지, timestamp_kst=실제 수집 시각, usd, jpy100, eur, source)
index.html                      그래프 · 일자별 표 페이지
```

## 설정

1. **API 키 발급**: [Twelve Data](https://twelvedata.com)에 가입하고 API 키를 받습니다. (무료 플랜: 하루 800회, 분당 8회 — 이 저장소는 하루 약 72회 사용)
2. **키 등록**: 저장소 `Settings → Secrets and variables → Actions → New repository secret`
   - Name: `TWELVE_DATA_API_KEY`
   - Secret: 발급받은 키
3. **쓰기 권한 확인**: `Settings → Actions → General → Workflow permissions`가 `Read and write permissions`인지 확인합니다.
4. **첫 실행**: `Actions` 탭 → `환율 수집` → `Run workflow`. 성공하면 `data/rates.csv`에 첫 줄이 커밋됩니다.
5. **페이지 공개** (선택): `Settings → Pages → Deploy from a branch → main / (root)`.

## 동작 방식

- 외환시장이 열려 있는 시간(한국시간 월 07시 ~ 토 08시)에 매시간 7분쯤 실행됩니다. GitHub 예약 실행은 몇 분 늦어질 수 있습니다.
- GitHub 예약 실행은 자주 건너뛰어지므로 10분마다 시도하고, 실행될 때마다 Twelve Data 시간봉으로 최근 약 5일 중 빠진 시간대를 그 시간 정각 시세로 채웁니다(`source`가 `twelvedata-1h`인 줄). 주말처럼 시장이 닫힌 시간은 기록하지 않습니다.
- `TWELVE_DATA_API_KEY`가 없거나 호출에 실패하면 ExchangeRate-API 무료 엔드포인트로 대신 받습니다. 이쪽은 **하루 1회만 갱신**되므로 `source` 열이 `open.er-api`인 기록은 시간대별 변동이 반영되지 않습니다.
- 값은 시장 환율(매매기준율 성격)이라 신한은행 등 은행 고시환율과는 소수점 단위로 차이가 있습니다.

## 로컬에서 보기

`index.html`이 CSV를 `fetch`로 읽기 때문에 파일을 더블클릭하면 안 열리고, 간단한 서버로 띄워야 합니다.

```bash
python3 -m http.server 8000
# http://localhost:8000
```

## 참고

- Twelve Data 무료 플랜은 개인·내부 용도 기준입니다. 페이지를 외부에 공개해서 다른 사람에게 보여줄 계획이면 약관을 확인하세요.
- 공개 저장소는 60일간 활동이 없으면 예약 워크플로가 자동 중지될 수 있습니다. 수집 커밋이 계속 쌓이는 동안은 문제없지만, 멈췄다면 Actions 탭에서 다시 켜면 됩니다.
