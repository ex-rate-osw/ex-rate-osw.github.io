#!/usr/bin/env python3
"""
앱 화면 캡처(raw)에 캡션을 입혀 스토어 규격 스크린샷을 만든다.

사용법
  pip install pillow
  python frame_screenshots.py                 # raw/01.png ~ 05.png → out/screenshots/...
  python frame_screenshots.py --raw 내폴더     # 캡처 폴더 지정
  python frame_screenshots.py --crop-top 70   # 안드로이드 상태바(위쪽 70px) 잘라내기

입력: raw/01.png, raw/02.png ... (에뮬레이터·실기기 세로 캡처, 크기 무관)
출력:
  out/screenshots/play/01.png ...      1080×1920 (Google Play 휴대폰)
  out/screenshots/appstore/01.png ...  1290×2796 (App Store 6.9형 iPhone)
캡션은 아래 CAPTIONS에서 바꿀 수 있다.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

CAPTIONS = [
    ("오늘 환율을 한눈에", "매매기준율과 전일 대비 등락"),
    ("일별·주별·월별 추이", "흐름을 그래프로 비교해요"),
    ("22개 통화 지원", "달러·엔·유로·위안까지"),
    ("송금 환율도 함께", "보낼 때·받을 때 값을 매일 기록"),
    ("다크 모드 지원", "밤에도 편하게"),
]

SIZES = {
    "play": (1080, 1920),
    "appstore": (1290, 2796),
}

TOP = (59, 130, 246)      # #3B82F6
BOTTOM = (29, 78, 216)    # #1D4ED8

# 운영체제별 한글 굵은 글꼴 후보 (먼저 찾은 것을 사용)
FONT_CANDIDATES = {
    "bold": [
        r"C:\Windows\Fonts\malgunbd.ttf",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
    ],
    "regular": [
        r"C:\Windows\Fonts\malgun.ttf",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    ],
}


def load_font(kind, size):
    for path in FONT_CANDIDATES[kind]:
        if os.path.exists(path):
            # Noto CJK .ttc는 index 1이 KR, AppleSDGothicNeo는 index 0
            index = 1 if "NotoSansCJK" in path else 0
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    sys.exit("한글 글꼴을 찾지 못했어요. FONT_CANDIDATES에 글꼴 경로를 추가해 주세요.")


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        px.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.convert("RGB"), (0, 0), mask)
    return out, mask


def frame(raw_path, title, sub, size, crop_top=0):
    W, H = size
    canvas = gradient(W, H).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # 캡션 (화면 위쪽 약 22%)
    title_font = load_font("bold", round(W * 0.078))
    sub_font = load_font("regular", round(W * 0.040))
    top = round(H * 0.065)
    draw.text((W / 2, top), title, font=title_font, fill="white", anchor="mt")
    tb = draw.textbbox((W / 2, top), title, font=title_font, anchor="mt")
    draw.text((W / 2, tb[3] + round(H * 0.016)), sub, font=sub_font, fill=(255, 255, 255, 225), anchor="mt")

    # 앱 화면: 가로 84% 폭, 아래쪽은 살짝 잘려 나가게 배치
    shot = Image.open(raw_path).convert("RGB")
    if crop_top:
        shot = shot.crop((0, crop_top, shot.width, shot.height))  # 상태바 잘라내기
    y = round(H * 0.22)
    # 기본은 가로 84%, 단 화면의 80% 이상은 보이도록 (아래쪽만 살짝 잘림)
    sw = round(min(W * 0.84, (H - y) / 0.8 * shot.width / shot.height))
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = round(sw * 0.07)
    shot_rgba, mask = rounded(shot, radius)
    x = (W - sw) // 2

    # 그림자
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sm = Image.new("L", canvas.size, 0)
    sm.paste(mask, (x, y + round(W * 0.012)))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(W * 0.02)).point(lambda a: a * 0.35))
    canvas = Image.alpha_composite(canvas, shadow)

    # 테두리(기기 느낌)
    border = round(W * 0.012)
    bezel = Image.new("RGBA", (sw + border * 2, sh + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle(
        (0, 0, bezel.width - 1, bezel.height - 1), radius=radius + border, fill=(15, 23, 42, 255)
    )
    canvas.alpha_composite(bezel, (x - border, y - border))
    canvas.alpha_composite(shot_rgba, (x, y))
    return canvas.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(HERE, "raw"))
    ap.add_argument("--out", default=os.path.join(HERE, "out", "screenshots"))
    ap.add_argument("--crop-top", type=int, default=0,
                    help="캡처 위쪽에서 잘라낼 픽셀 수 (안드로이드 상태바 제거용, 예: 1080x2400 기기는 약 70)")
    args = ap.parse_args()

    raws = sorted(f for f in os.listdir(args.raw) if f.lower().endswith((".png", ".jpg", ".jpeg")))
    if not raws:
        sys.exit(f"{args.raw} 폴더에 캡처 이미지가 없어요 (01.png, 02.png ...)")
    if len(raws) > len(CAPTIONS):
        print(f"[warn] 캡처가 {len(raws)}장인데 캡션은 {len(CAPTIONS)}개라 앞의 {len(CAPTIONS)}장만 만듭니다.")

    for store, size in SIZES.items():
        os.makedirs(os.path.join(args.out, store), exist_ok=True)
        for i, name in enumerate(raws[: len(CAPTIONS)]):
            title, sub = CAPTIONS[i]
            img = frame(os.path.join(args.raw, name), title, sub, size, args.crop_top)
            dst = os.path.join(args.out, store, f"{i + 1:02d}.png")
            img.save(dst, optimize=True)
            print(f"[ok] {dst} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
