#!/usr/bin/env bash
# 플랫폼 폴더(android/, ios/)를 만들고 스토어 출시용 설정을 맞춘다.
# 사용: app 폴더에서  bash setup_platforms.sh
# (GitHub Actions의 iOS 업로드 워크플로도 이 스크립트를 쓴다. Windows에서는 Git Bash로 실행)
set -euo pipefail
cd "$(dirname "$0")"

APP_ID="com.ohsang.play.exrate"   # iOS 번들 ID / Android 패키지명
APP_NAME="환율 기록"

# 1) 플랫폼 폴더가 없으면 생성 (lib/, test/, pubspec.yaml은 건드리지 않음)
if [ ! -d ios ] || [ ! -d android ]; then
  flutter create --org com.ohsang.play --project-name ex_rate_app --platforms android,ios .
  # flutter create는 이미 있는 파일을 덮어쓰지 않지만, 혹시 바뀌었으면 알려준다
  if ! git diff --quiet -- lib test pubspec.yaml 2>/dev/null; then
    echo "[주의] lib/, test/, pubspec.yaml에 변경이 있어요. git diff로 확인해 주세요."
  fi
fi

# 2) iOS
PBX=ios/Runner.xcodeproj/project.pbxproj
PLIST=ios/Runner/Info.plist
if [ -f "$PBX" ]; then
  # 번들 ID (flutter create 기본값 com.ohsang.play.exRateApp → com.ohsang.play.exrate)
  sed -i.bak -E "s/PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.]*exRateApp(\.RunnerTests)?;/PRODUCT_BUNDLE_IDENTIFIER = ${APP_ID}\1;/" "$PBX"
  # iPhone 전용 (iPad 스크린샷 없이 제출)
  sed -i.bak -E 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/' "$PBX"
  rm -f "$PBX.bak"
fi
if [ -f "$PLIST" ] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  PB=/usr/libexec/PlistBuddy
  $PB -c "Set :CFBundleDisplayName ${APP_NAME}" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PLIST"
  # 표준 HTTPS 외 암호화 없음 → 수출 규정 질문 자동 처리
  $PB -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null || $PB -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
elif [ -f "$PLIST" ]; then
  echo "[안내] PlistBuddy가 없어 Info.plist는 수정하지 않았어요 (Mac/CI에서 다시 실행하면 적용됩니다)"
fi

# 3) Android
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  grep -q 'android.permission.INTERNET' "$MANIFEST" || \
    perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
  APP_NAME="$APP_NAME" perl -pi -e 's/android:label="[^"]*"/android:label="$ENV{APP_NAME}"/' "$MANIFEST"
fi
for G in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$G" ]; then
    # applicationId만 바꾼다 (namespace는 MainActivity 패키지와 맞아야 해서 그대로 둠)
    APP_ID="$APP_ID" perl -pi -e 's/(applicationId\s*=?\s*)"[^"]*"/$1"$ENV{APP_ID}"/' "$G"
  fi
done

# 4) 아이콘
flutter pub get
dart run flutter_launcher_icons

echo "[ok] 플랫폼 설정 완료: ${APP_ID} / ${APP_NAME}"
