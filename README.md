# ex-rate-osw

한국수출입은행이 영업일마다 고시하는 원화 환율(23개 통화)을 매일 자동으로 기록하고, 일별·주별·월별 그래프와 표로 보여주는 저장소입니다. 서버나 DB 없이 GitHub Actions + GitHub Pages만으로 동작합니다.

```
.github/workflows/collect.yml   영업일 하루 몇 번 실행되는 수집 워크플로
scripts/collect_daily.py        수출입은행 API로 일별 환율 수집 (파이썬 표준 라이브러리만 사용)
data/daily.csv                  수집된 기록 (date, code, name, unit, base, ttb, tts)
data/no_data_dates.txt          조회했지만 고시가 없던 날짜 (공휴일 등)
index.html                      일별·주별·월별 그래프 페이지
app/                            같은 데이터를 보여주는 Flutter 앱
```

`daily.csv` 열: `base` 매매기준율, `tts` 송금 보낼 때(전신환 매도율), `ttb` 송금 받을 때(전신환 매입율), `unit` 기준 단위(JPY·IDR은 100).

## 설정

1. **API 키 발급**: [한국수출입은행 오픈API](https://www.koreaexim.go.kr/ir/HPHKIR020M01?apino=2&viewtype=C)에서 인증키를 발급받습니다. (무료, 하루 1,000회)
2. **키 등록**: 저장소 `Settings → Secrets and variables → Actions → New repository secret`
   - Name: `KOREAEXIM_API_KEY`
   - Secret: 발급받은 인증키
3. **첫 실행**: `Actions` 탭 → `환율 수집 (일별)` → `Run workflow`. 최근 약 1년치(영업일 약 280일)가 한 번에 채워집니다.

## 동작 방식

- 수출입은행은 영업일 오전 11시 전후에 하루 1번 고시합니다. 워크플로는 월~금 11:23, 13:23, 16:23, 19:23(한국시간)에 실행을 시도합니다.
- 실행할 때마다 오늘 값과 아직 없는 과거 영업일(최근 400일)을 함께 채웁니다. GitHub 예약 실행이 건너뛰어져도 다음 실행에서 빠진 날이 채워집니다.
- 이미 받은 날짜와 고시가 없던 공휴일은 다시 조회하지 않습니다. 실행 한 번에 최대 300회까지만 호출합니다.
- 인증키는 2년마다 재동의가 필요합니다. 수출입은행에서 재동의 메일이 오면 동의해 주세요. 키가 파기되면 수집이 `API 오류 3`으로 실패합니다.

## 로컬에서 보기

`index.html`이 CSV를 `fetch`로 읽기 때문에 간단한 서버로 띄워야 합니다.

```bash
python3 -m http.server 8000
# http://localhost:8000
```

## 데이터 출처

한국수출입은행 현재환율 API (공공데이터포털 이용허락범위: 제한 없음). 화면에 "출처: 한국수출입은행"을 표시합니다. 일 단위 고시 값이라 실시간 시세나 은행 창구 환율과는 다를 수 있습니다.
