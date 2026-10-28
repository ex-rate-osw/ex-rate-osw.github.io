# 스토어 등록 자료

```
store-listing.md        스토어 문구(이름, 설명, 키워드 등)와 등록 정보, 규격 정리
capture-prompt.md       에뮬레이터에서 스크린샷 5장을 캡처하는 VS Code Claude Code용 프롬프트
frame_screenshots.py    캡처(raw/)에 캡션을 입혀 Play 1080×1920, App Store 1206×2622으로 만드는 스크립트
out/
  icon-1024.png                     App Store 아이콘 (투명도 없음)
  play-icon-512.png                 Google Play 아이콘
  android-adaptive-foreground.png   안드로이드 적응형 아이콘 전경 (안전 영역 안)
  android-adaptive-background.png   안드로이드 적응형 아이콘 배경
  play-feature-graphic-1024x500.png Google Play 대표 이미지
  screenshots/                      frame_screenshots.py 결과
src/                    아이콘·대표 이미지 원본 SVG와 렌더링 스크립트
```

## 앱에 아이콘 넣기

`app/` 폴더에서 [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)를 쓰면 한 번에 들어가요.

```yaml
# app/pubspec.yaml 의 dev_dependencies 아래
  flutter_launcher_icons: ^0.14.0

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "../store-assets/out/icon-1024.png"
  adaptive_icon_background: "../store-assets/out/android-adaptive-background.png"
  adaptive_icon_foreground: "../store-assets/out/android-adaptive-foreground.png"
  remove_alpha_ios: true
```

```bash
cd app
flutter pub get
dart run flutter_launcher_icons
```
