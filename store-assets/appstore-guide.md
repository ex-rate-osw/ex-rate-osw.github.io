# App Store 등록 정보 (환율 기록)

화면 순서대로 칸마다 넣을 값을 정리했어요. iOS 빌드·업로드는 Mac 없이 GitHub Actions(`.github/workflows/ios-testflight.yml`)로 합니다.

## 기본 값

| 항목 | 값 |
|---|---|
| 번들 ID (iOS) | `com.ohsang.util.exrate` |
| 패키지명 (Android) | `com.ohsang.util.exrate` |
| 홈 화면 표시 이름 | 환율 기록 |
| App Store 이름 | 환율 기록 - 고시 환율 그래프 |
| 부제 | 일별·주별·월별 환율 추이 한눈에 |
| SKU | `exrate-001` |
| 버전 / 빌드 | 1.0.0 / 자동 (GitHub Actions 실행 번호) |
| 지원 기기 | iPhone 전용 |
| 가격 | 무료 · 광고 없음 · 인앱 결제 없음 |

---

## 1. Certificates, Identifiers & Profiles

https://developer.apple.com/account/resources/identifiers/list

**Identifiers → + → App IDs → 계속 → App → 계속**

| 칸 | 값 |
|---|---|
| Description | `Ex Rate` (영문·숫자·공백만 가능) |
| Bundle ID | **Explicit** · `com.ohsang.util.exrate` |
| Capabilities | 아무것도 체크하지 않음 |
| App Services | 아무것도 체크하지 않음 |

→ **계속 → Register**

**인증서(Certificates)·프로파일(Profiles)은 만들지 않아도 돼요.** 업로드 워크플로가 관리자 API 키로 클라우드 서명을 써서, Apple이 배포 인증서와 프로파일을 자동으로 만들고 관리해요. 직접 만들어 두면 오히려 꼬일 수 있어요.

## 2. App Store Connect → 신규 앱

https://appstoreconnect.apple.com/apps → **+ → 신규 앱**

| 칸 | 값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `환율 기록 - 고시 환율 그래프` |
| 기본 언어 | 한국어 |
| 번들 ID | `Ex Rate - com.ohsang.util.exrate` (1단계에서 등록한 것) |
| SKU | `exrate-001` |
| 사용자 액세스 | 전체 액세스 |

이름이 이미 사용 중이라고 나오면: `환율 기록 - 매일 환율 그래프` 또는 `환율 기록: 고시 환율 차트`

## 3. 앱 정보 (일반 → 앱 정보)

| 칸 | 값 |
|---|---|
| 부제 | `일별·주별·월별 환율 추이 한눈에` |
| 카테고리 | 기본: **금융** / 보조: **유틸리티** |
| 콘텐츠 권한 | "타사 콘텐츠를 포함하거나 표시하나요?" → **예**, "필요한 권한이 있음" 체크 (한국수출입은행 공공데이터, 이용허락범위 제한 없음) |
| 연령 등급 | 설문 전부 **없음 / 아니요** → 4+ |
| 개인정보 처리방침 URL | `https://ex-rate.ohsangplay.com/privacy.html` |

## 4. 앱 개인정보 보호

**시작하기 → "이 앱에서 데이터를 수집합니까?" → 아니요, 이 앱에서 데이터를 수집하지 않습니다 → 게시**

## 5. 가격 및 사용 가능 여부

| 칸 | 값 |
|---|---|
| 가격 | 무료 (0원) |
| 사용 가능 국가 | 대한민국 (또는 전체 국가) |

## 6. 버전 1.0 (iOS 앱 → 1.0 준비 중)

**스크린샷 · iPhone iPhone** (1206×2622, 3~10장)
`store-assets/out/screenshots/appstore/01~05.png`
→ 안드로이드 캡처로 만든 임시본이니, TestFlight로 아이폰에 설치한 뒤 아이폰에서 캡처해서 `raw/`에 넣고 `python frame_screenshots.py`를 다시 돌린 걸 올리는 게 안전해요.

**프로모션 텍스트** (170자)
```
한국수출입은행 고시 환율을 매일 자동으로 기록해요. 달러·엔·유로 등 22개 통화의 일별·주별·월별 흐름을 그래프로 확인하세요. 광고 없음, 개인정보 수집 없음.
```

**설명** (4,000자)
```
환율 기록은 한국수출입은행이 영업일마다 고시하는 원화 환율을 매일 모아서, 일별·주별·월별 그래프와 기록으로 보여주는 앱입니다.

■ 이런 분께 좋아요
· 매일 은행 앱을 열어 환율을 따로 적어두던 분
· 여행, 해외 직구, 해외 송금 전에 환율 흐름을 보고 싶은 분
· 오늘 환율이 지난주, 지난달보다 높은지 낮은지 한눈에 비교하고 싶은 분

■ 주요 기능
· 오늘의 매매기준율과 전 영업일 대비 등락
· 송금 보낼 때 / 송금 받을 때 환율 함께 표시
· 일별(최근 60영업일), 주별(52주 평균), 월별(24개월 평균) 추이 그래프
· 그래프를 누르면 그날(그 주, 그 달)의 평균·시가·종가·고가·저가 확인
· 미국 달러, 일본 엔(100엔), 유로, 위안화, 영국 파운드, 홍콩 달러 등 22개 통화
· 최근 1년치 기록 제공, 매 영업일 자동으로 쌓임
· 앱을 켜두면 10분마다 자동 갱신, 당겨서 새로고침
· 다크 모드 지원

■ 개인정보를 모으지 않아요
회원가입, 로그인, 광고가 없습니다. 이름, 연락처, 위치, 광고 ID 등 어떠한 개인정보도 수집하지 않습니다.

■ 안내
· 환율 정보의 출처는 한국수출입은행이며, 영업일 오전 11시 전후 하루 1번 고시되는 값입니다.
· 표시되는 환율은 참고용이며, 실시간 시세나 각 은행의 실제 거래 환율(현찰 환율, 우대율 적용 환율 등)과 다를 수 있습니다.
· 이 앱은 한국수출입은행 및 특정 은행과 관련이 없는 개인 개발 앱입니다.

문의: dkwkehd2@gmail.com
```

**키워드** (100자)
```
환전,달러,엔화,유로,위안,매매기준율,송금,수출입은행,외화,해외여행,직구,엔저,원달러,환율계산,차트
```

| 칸 | 값 |
|---|---|
| 지원 URL | `https://ex-rate.ohsangplay.com/privacy.html#contact` |
| 마케팅 URL | `https://ex-rate.ohsangplay.com/` |
| 빌드 | 7단계에서 업로드한 빌드 선택 |
| 저작권 | `2026 오상원` (개인 계정이면 본인 이름) |
| 버전 출시 | 이 버전을 수동으로 출시 (심사 통과 후 원하는 때 출시) |

**앱 심사 정보**

| 칸 | 값 |
|---|---|
| 로그인 필요 | 체크 해제 (로그인 없음) |
| 연락처 | 이름 · 전화번호 · `dkwkehd2@gmail.com` |
| 첨부 파일 | 없음 |

메모:
```
This app shows daily official KRW exchange rates published by the Export-Import Bank of Korea (public data, no usage restrictions). Rates are collected once per business day and served as a static file from GitHub Pages. No login, no ads, no personal data collection. Users can switch among 22 currencies and view daily, weekly (average), and monthly (average) charts.
```

## 7. 빌드 업로드 (GitHub Actions)

**저장소 Secrets** (Settings → Secrets and variables → Actions) — 이름이 정확히 같아야 해요

| Name | 값 | 찾는 곳 |
|---|---|---|
| `APPLE_TEAM_ID` | 10자리 팀 ID | developer.apple.com/account → 멤버십 세부사항 |
| `ASC_KEY_ID` | API 키 ID | App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API |
| `ASC_ISSUER_ID` | 발급자 ID | 같은 화면 위쪽 |
| `ASC_KEY_P8_BASE64` | p8 파일의 base64 | 아래 명령 |

- API 키 역할은 **관리자(Admin)** 여야 클라우드 서명이 돼요. 다른 역할로 만들었으면 관리자 키를 새로 만들어 주세요.
- p8 → base64 (PowerShell, 결과가 클립보드에 복사됨):
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
  ```

**실행**: Actions → **iOS 빌드 → TestFlight 업로드** → Run workflow (upload 체크)
- 15~25분 뒤 App Store Connect → TestFlight에 빌드가 보여요 (처리 10~30분 추가).
- TestFlight → 내부 테스트에 본인을 추가하고, 아이폰 TestFlight 앱으로 설치해서 확인하세요.
- 실패하면 실행 로그의 빨간 단계를 알려주세요.

## 8. 심사 제출

6단계 화면 오른쪽 위 **심사에 추가 → 제출**. 보통 1~2일 안에 결과가 나와요.

**자주 걸리는 부분**
- **4.2 최소 기능**: 웹을 감싼 앱처럼 보이면 거절될 수 있어요. 네이티브 그래프·통화 전환·자동 갱신이 있어 괜찮을 가능성이 높지만, 거절되면 위젯이나 환율 계산기를 더하면 돼요.
- **2.3 정확한 메타데이터**: 스크린샷은 실제 iPhone 화면처럼 보여야 해요. 안드로이드 상태바가 보이면 안 돼요.
- **5.1.1 개인정보처리방침**: 링크가 열려야 하고, 앱 하단 링크도 동작해야 해요.
