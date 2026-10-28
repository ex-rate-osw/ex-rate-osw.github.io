# 환율 기록 앱 (Flutter)

https://ex-rate-osw.github.io/data/daily.csv 에 쌓이는 한국수출입은행 일별 고시 환율(23개 통화)을 읽어 매매기준율, 송금 보낼 때/받을 때 환율, 일별·주별·월별 추이 그래프와 기록을 보여주는 Android / iOS 앱입니다.

```
lib/main.dart              화면 (통화 칩, 요약 카드, 일·주·월 전환, 그래프, 기록 목록)
lib/rate_chart.dart        fl_chart 라인 그래프
lib/models.dart            CSV 파싱, 일·주·월 집계, 라벨 (웹 페이지와 같은 규칙)
lib/rates_repository.dart  CSV 다운로드
test/widget_test.dart      계산 로직 테스트
setup_platforms.sh         플랫폼 폴더 생성·출시 설정 (앱 ID, 이름, 아이콘)
```

App Store 업로드는 Mac 없이 GitHub Actions로 합니다 → `../store-assets/appstore-guide.md`

## 처음 한 번: 플랫폼 폴더 만들기

`android/`, `ios/` 폴더는 저장소에 없어서, 처음에 한 번 스크립트로 만듭니다. 이미 있는 `lib/`, `pubspec.yaml`, `test/` 파일은 덮어쓰지 않아요.

```bash
cd app
bash setup_platforms.sh      # Windows는 Git Bash에서 실행
flutter test
```

스크립트가 해주는 일:
- `flutter create`로 android/ios 폴더 생성 (없을 때만)
- 앱 ID를 `com.ohsang.play.exrate`로 (iOS 번들 ID, Android applicationId)
- 앱 이름을 "환율 기록"으로, Android 인터넷 권한 추가
- iOS를 iPhone 전용으로, 수출 규정(암호화) 항목 설정 (Info.plist 수정은 Mac/CI에서만 적용)
- 앱 아이콘 생성 (`flutter_launcher_icons.yaml`, 원본은 `../store-assets/out/`)

이미 예전 방식(`--org io.github.exrateosw`)으로 만든 폴더가 있으면, 스크립트를 다시 실행하면 앱 ID와 이름만 새 값으로 바뀌어요.

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
- 앱이 화면에 떠 있는 동안 10분마다 자동으로 다시 받아옵니다(새로고침하면 타이머가 다시 시작).
- 수출입은행 고시는 영업일 하루 1번(오전 11시 전후)이라, 값은 하루에 한 번 바뀝니다.
- 화면 하단에 출처(한국수출입은행)를 표시합니다.
