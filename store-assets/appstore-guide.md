# App Store 등록 순서 (Mac 없이)

iOS 빌드는 GitHub Actions의 macOS 실행 환경(`.github/workflows/ios-testflight.yml`)에서 하고, 나머지는 웹(App Store Connect)에서 합니다.

| 항목 | 값 |
|---|---|
| 번들 ID | `com.ohsang.play.exrate` |
| 앱 표시 이름 (홈 화면) | 환율 기록 |
| App Store 이름 | 환율 기록 - 고시 환율 그래프 (`store-listing.md`) |
| 지원 기기 | iPhone 전용 (iPad 스크린샷 불필요) |
| SKU (내부 관리용) | `exrate-001` |

## 1. Apple Developer Program 가입 (한 번)

1. https://developer.apple.com/kr/programs/enroll/ 에서 Apple 계정으로 가입. 연 99달러(원화는 결제 화면에 표시).
2. **"개인"으로 등록**하세요. Apple의 "조직" 등록은 법인(D-U-N-S 번호)이 있어야 해서, 개인사업자는 개인으로 등록합니다. App Store 판매자 이름은 본인 이름(영문)으로 표시돼요.
3. 승인까지 보통 하루~이틀 걸려요.

## 2. 번들 ID 등록

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers → +**
2. **App IDs → App** 선택
3. Description: `Ex Rate`, Bundle ID: **Explicit** `com.ohsang.play.exrate`
4. Capabilities는 아무것도 켜지 않고 **Register**

## 3. App Store Connect에 앱 만들기

1. https://appstoreconnect.apple.com → **앱 → + → 신규 앱**
2. 플랫폼 **iOS**, 이름 `환율 기록 - 고시 환율 그래프`, 기본 언어 **한국어**, 번들 ID `com.ohsang.play.exrate`, SKU `exrate-001`, 사용자 액세스 **전체 액세스**
3. 이름이 이미 쓰이고 있다고 나오면 다른 이름을 정해야 해요 (예: `환율 기록 - 매일 환율 그래프`).

## 4. API 키 만들기 (GitHub에서 빌드·업로드용)

1. App Store Connect → **사용자 및 액세스 → 통합(Integrations) → App Store Connect API → 팀 키 → +**
2. 이름 `github-actions`, 역할 **관리자(Admin)** → 생성
   - 관리자 역할이어야 인증서를 Apple이 자동으로 관리하는 "클라우드 서명"이 돼요.
3. **API 키 다운로드**(`AuthKey_XXXXXXXXXX.p8`) — 한 번만 받을 수 있으니 안전한 곳에 보관하세요.
4. 같은 화면 위쪽의 **발급자 ID(Issuer ID)**, 키 목록의 **키 ID**를 메모
5. **팀 ID**: https://developer.apple.com/account → 멤버십 세부사항의 10자리 팀 ID

p8 파일을 base64 문자열로 바꾸기 (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```
(클립보드에 복사됩니다)

## 5. GitHub 저장소 Secrets 등록

저장소 **Settings → Secrets and variables → Actions → New repository secret** 에 4개:

| Name | 값 |
|---|---|
| `APPLE_TEAM_ID` | 팀 ID (10자리) |
| `ASC_KEY_ID` | API 키 ID |
| `ASC_ISSUER_ID` | 발급자 ID |
| `ASC_KEY_P8_BASE64` | 위에서 복사한 base64 문자열 |

## 6. 빌드해서 TestFlight에 올리기

1. **Actions → iOS 빌드 → TestFlight 업로드 → Run workflow** (upload 체크된 상태로)
2. 15~25분 정도 걸려요. 끝나면 App Store Connect → 앱 → **TestFlight**에 빌드가 나타나요(처리 10~30분).
3. 아이폰에 **TestFlight 앱**을 깔고, TestFlight → 내부 테스트 그룹에 본인을 추가하면 바로 설치해볼 수 있어요.
4. 실패하면 실행 로그의 빨간 단계를 알려주세요.

## 7. 스토어 정보 입력

앱 → **App Store** 탭 (버전 1.0):

- **스크린샷 (6.9형 iPhone)**: `out/screenshots/appstore/01~05.png` (1290×2796). 가능하면 iOS 화면으로 다시 찍는 게 좋아요 — TestFlight로 설치한 뒤 아이폰에서 캡처(측면 버튼 + 볼륨 업)해서 `raw/`에 넣고 `frame_screenshots.py`를 돌리면 돼요.
- **프로모션 텍스트, 설명, 키워드, 지원 URL, 마케팅 URL**: `store-listing.md`에서 복사
- **빌드**: 6단계에서 올린 빌드 선택
- **저작권**: `2026 오상원` (본인 이름)
- **버전 출시**: 심사 후 수동 출시를 추천 (출시 시점을 직접 정할 수 있어요)

앱 → **앱 정보**:
- 부제, 카테고리(주: 금융, 부: 유틸리티), 콘텐츠 권한: "타사 콘텐츠를 포함하거나 보여주나요?" → **예** (한국수출입은행 공개 데이터, 이용허락 제한 없음)
- **연령 등급**: 설문 전부 "없음" → 4+
- **개인정보처리방침 URL**: https://ex-rate-osw.github.io/privacy.html

앱 → **앱 개인정보 보호**:
- "데이터 수집 여부" → **아니요, 이 앱에서 데이터를 수집하지 않습니다**

앱 → **가격 및 사용 가능 여부**: 무료, 국가는 대한민국(또는 전체)

## 8. 심사 제출

**앱 심사 정보**:
- 로그인 필요: **아니요**
- 연락처: 이름, 전화번호, 이메일(dkwkehd2@gmail.com)
- 메모 (복사해서 사용):
```
This app shows daily official KRW exchange rates published by the Export-Import Bank of Korea (public data, no usage restrictions). Rates are collected once per business day and served as a static file from GitHub Pages. No login, no ads, no personal data collection. Users can switch among 22 currencies and view daily, weekly (average), and monthly (average) charts.
```

**심사에 제출** → 보통 1~2일 안에 결과가 나와요.

## 자주 걸리는 부분

- **4.2 최소 기능**: 웹페이지를 감싼 앱처럼 보이면 거절될 수 있는데, 이 앱은 네이티브 그래프·통화 전환·자동 갱신이 있어서 괜찮을 가능성이 높아요. 거절되면 위젯이나 환율 계산기 같은 기능을 더하면 돼요.
- **2.3 정확한 메타데이터**: 스크린샷이 실제 앱 화면과 달라 보이면 안 돼요. 안드로이드 상태바가 보이는 캡처는 쓰지 마세요.
- **5.1.1 개인정보처리방침**: 링크가 열려야 해요. 앱 하단 링크도 동작하는지 TestFlight에서 확인하세요.
