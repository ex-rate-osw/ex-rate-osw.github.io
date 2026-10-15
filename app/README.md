# 환율 기록 앱 (Flutter)

https://ex-rate-osw.github.io/data/rates.csv 에 쌓이는 기록을 읽어 달러·엔화(100엔)·유로 시세, 추이 그래프, 일자별 시가·고가·저가·종가를 보여주는 Android / iOS 앱입니다.

```
lib/main.dart              화면 (통화 카드, 기간 선택, 그래프, 일자별 목록)
lib/rate_chart.dart        fl_chart 라인 그래프
lib/models.dart            CSV 파싱, 기간 필터, 전일 대비, 일자별 요약 (웹 페이지와 같은 규칙)
lib/rates_repository.dart  CSV 다운로드
test/widget_test.dart      계산 로직 테스트
```

## 처음 한 번: 플랫폼 폴더 만들기

`android/`, `ios/` 폴더는 저장소에 없으니 처음에 한 번 생성합니다. 이미 있는 `lib/`, `pubspec.yaml`, `test/` 파일은 덮어쓰지 않아요.

```bash
cd app
flutter create --org io.github.exrateosw --project-name ex_rate_app --platforms android,ios .
flutter pub get
flutter test
```

### Android 인터넷 권한 (릴리스 빌드에 필수)

`android/app/src/main/AndroidManifest.xml`의 `<manifest ...>` 바로 아래에 한 줄 추가합니다. 디버그 실행은 없어도 되지만, 폰에 설치할 릴리스 APK는 이게 없으면 데이터를 못 불러와요.

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 앱 이름을 "환율 기록"으로 (선택)

- Android: 같은 파일의 `android:label="ex_rate_app"` → `android:label="환율 기록"`
- iOS: `ios/Runner/Info.plist`의 `CFBundleDisplayName` 값 → `환율 기록`

생성된 `android/`, `ios/` 폴더는 커밋해두면 다음부터는 이 과정이 필요 없습니다.

## 폰에 설치

**Android**

```bash
flutter build apk --release
```

`build/app/outputs/flutter-apk/app-release.apk`를 폰으로 옮겨 설치하거나, USB 연결 후 `flutter install`.

**iOS** (Mac + Xcode 필요)

```bash
open ios/Runner.xcworkspace
```

Xcode에서 Runner → Signing & Capabilities → Team에 본인 Apple ID 선택 → 아이폰 연결 후 실행. 무료 Apple ID로 설치한 앱은 7일 후 다시 설치해야 합니다.

## 동작

- 앱을 열거나 다시 돌아올 때, 당겨서 새로고침할 때 최신 CSV를 받아옵니다.
- GitHub Pages 캐시 때문에 방금 수집된 값이 최대 몇 분 늦게 보일 수 있어요.
