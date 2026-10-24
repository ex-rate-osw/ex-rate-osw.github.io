# 스토어 스크린샷 캡처 요청

이 PC(Windows)의 안드로이드 에뮬레이터에서 환율 기록 앱 화면 5장을 캡처하고, 스토어 규격 이미지로 만들어줘. 터미널은 PowerShell 기준이야.

## 위치
- 저장소: `$HOME\Documents\ex-rate-osw.github.io` (없으면 `git clone https://github.com/ex-rate-osw/ex-rate-osw.github.io.git`, 있으면 `git pull`)
- 앱: `app\`
- 스토어 자료: `store-assets\` (캡처 저장 위치 `store-assets\raw\`, 결과 `store-assets\out\screenshots\`)
- 캡션 편집 스크립트: `store-assets\frame_screenshots.py` (Pillow 필요: `pip install pillow`)

## 1. 준비
1. 앱이 에뮬레이터에서 실행되는 상태로 만들어줘 (`app` 폴더에서 `flutter run`). 아직 플랫폼 폴더가 없으면 `app\README.md`의 "처음 한 번" 순서대로 먼저 만들어줘.
2. `adb`가 PATH에 없으면 `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`를 써줘. `adb devices`로 에뮬레이터 인식 확인.
3. 깔끔한 상태바를 위해 데모 모드를 켜줘:
   ```powershell
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```
4. 라이트 모드로 시작: `adb shell cmd uimode night no`

## 2. 캡처할 화면 (5장)

| 파일 | 화면 |
|---|---|
| `raw\01.png` | 미국 달러, 일별 보기, 맨 위 (요약 카드와 그래프가 보이게) |
| `raw\02.png` | 일본 엔, 주별 보기, 그래프 가운데쯤 점 하나를 눌러 툴팁이 뜬 상태 |
| `raw\03.png` | 유로, 월별 보기, 통화 칩이 잘 보이게 |
| `raw\04.png` | 미국 달러, 일별 보기, 아래로 스크롤해서 일별 기록 목록(송금 보낼 때·받을 때)이 보이게 |
| `raw\05.png` | 다크 모드(`adb shell cmd uimode night yes`)에서 미국 달러, 일별 보기, 맨 위 |

- 화면 조작은 `adb shell uiautomator dump /sdcard/ui.xml` 후 `adb pull /sdcard/ui.xml`로 요소 위치(text, content-desc, bounds)를 찾아서 `adb shell input tap x y`, 스크롤은 `adb shell input swipe`로 해줘.
- Flutter 화면 요소가 dump에 안 잡히거나 툴팁 띄우기가 어려우면, 억지로 하지 말고 **나한테 그 화면을 맞춰달라고 말한 뒤** 내가 "됐어"라고 하면 캡처해줘.
- 캡처: `adb exec-out screencap -p > store-assets\raw\0N.png`
  - PowerShell에서는 `>` 리다이렉트가 바이너리를 깨뜨릴 수 있으니 이렇게 해줘:
    ```powershell
    adb shell screencap -p /sdcard/shot.png
    adb pull /sdcard/shot.png store-assets\raw\01.png
    ```
- 각 캡처 후 이미지를 열어서 화면이 맞는지, 로딩 중이거나 에러 카드가 떠 있지 않은지 확인해줘.

## 3. 스토어 규격으로 변환
- 상태바 높이를 확인해줘: 캡처 크기와 기기 밀도(`adb shell wm density`)로 계산 (상태바 ≈ 24dp × density/160). 보통 1080×2400 기기는 약 63~70px.
- 실행:
  ```powershell
  cd store-assets
  python frame_screenshots.py --crop-top <상태바 px>
  ```
- 결과 확인: `out\screenshots\play\01~05.png` (1080×1920), `out\screenshots\appstore\01~05.png` (1290×2796). 각 이미지를 열어 캡션이 잘리지 않았는지, 앱 화면이 자연스럽게 보이는지 확인해줘.

## 4. 마무리
- 데모 모드 끄기: `adb shell am broadcast -a com.android.systemui.demo -e command exit`, 다크 모드 원래대로: `adb shell cmd uimode night no`
- **커밋·푸시는 하지 마.** 만든 파일 목록만 보여줘.

## 참고
- App Store 스크린샷은 iPhone 화면이 원칙이라, 나중에 Mac이 생기면 iOS 시뮬레이터(iPhone 16 Pro Max)에서 같은 5장을 캡처해서 `raw\`에 넣고 다시 돌리는 게 가장 안전해. 지금 만드는 App Store용은 안드로이드 캡처에서 상태바를 잘라낸 임시본이야.
