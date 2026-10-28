#!/usr/bin/env python3
"""
앱 화면 캡처(raw)에 캡션을 입혀 스토어 규격 스크린샷을 만든다.

사용법
  pip install pillow
  python frame_screenshots.py                 # raw/01.png ~ 05.png → out/screenshots/...
  python frame_screenshots.py --raw 내폴더     # 캡처 폴더 지정
  python frame_screenshots.py --crop-top 70   # 안드로이드 상태바(위쪽 70px) 잘라내기
  python frame_screenshots.py --mask          # 날짜·시각·환율 숫자를 모자이크 (raw/NN.json 필요)

입력: raw/01.png, raw/02.png ... (에뮬레이터·실기기 세로 캡처, 크기 무관)
출력:
  out/screenshots/play/01.png ...      1080×1920 (Google Play 휴대폰)
  out/screenshots/appstore/01.png ...            1206×2622 (App Store iPhone)
  out/screenshots/appstore-1179x2556/01.png ...  1179×2556 (App Store iPhone, 다른 허용 크기)
캡션은 아래 CAPTIONS에서 바꿀 수 있다.
"""
import argparse
import json
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
    # App Store Connect "Dynamic Island 지원 iPhone (중형 디스플레이)" 칸이 받는 크기
    "appstore": (1206, 2622),
    "appstore-1179x2556": (1179, 2556),
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


def pixelate(img, box, block):
    """box 영역을 모자이크한다."""
    l, t, r, b = [int(round(v)) for v in box]
    l, t = max(l, 0), max(t, 0)
    r, b = min(r, img.width), min(b, img.height)
    if r - l < 2 or b - t < 2:
        return
    region = img.crop((l, t, r, b))
    small = region.resize((max(1, (r - l) // block), max(1, (b - t) // block)), Image.BOX)
    img.paste(small.resize(region.size, Image.NEAREST), (l, t))


def find_tooltip(img):
    """라이트 모드 그래프 툴팁(어두운 상자)의 위치를 이미지에서 찾는다."""
    w, h = img.size
    px = img.convert("RGB").load()
    step = 2
    rows = []
    for y in range(int(h * 0.2), int(h * 0.95), step):
        dark = sum(1 for x in range(0, w, step) if max(px[x, y]) < 75)
        if dark * step > w * 0.18:
            rows.append(y)
    if not rows:
        return None
    # 가장 긴 연속 구간을 툴팁으로 본다
    best, cur = [rows[0]], [rows[0]]
    for y in rows[1:]:
        cur = cur + [y] if y - cur[-1] <= step * 3 else [y]
        if len(cur) > len(best):
            best = cur
    top, bottom = best[0], best[-1]
    mid = (top + bottom) // 2
    cols = [x for x in range(0, w, step) if max(px[x, mid]) < 75]
    return (min(cols), top, max(cols), bottom) if cols else None


def mask_sensitive(img, meta_path):
    """촬영 때 기록한 위치(NN.json)의 날짜·시각·금액을 모자이크한다."""
    with open(meta_path, encoding="utf-8") as f:
        meta = json.load(f)
    rects = meta.get("rects", [])
    width = float(meta.get("width") or img.width)
    # 위치가 논리 픽셀이면 이미지 배율로 키우고, 이미 물리 픽셀이면 그대로
    scale = 1.0 if any(r["r"] > width + 5 for r in rects) else img.width / width
    pad = 3 * scale
    block = max(8, round(img.width / 70))
    for r in rects:
        # 큰 글자는 모자이크 칸도 크게 (글자 높이의 절반 정도면 읽히지 않음)
        h = (r["b"] - r["t"]) * scale
        pixelate(img, (r["l"] * scale - pad, r["t"] * scale - pad, r["r"] * scale + pad, r["b"] * scale + pad),
                 max(block, round(h / 2)))
    if meta.get("tooltip") and not meta.get("dark"):
        box = find_tooltip(img)
        if box:
            pixelate(img, (box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6), block)
    return len(rects)


def frame(raw_path, title, sub, size, crop_top=0, mask=False):
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
    if mask:
        meta_path = os.path.splitext(raw_path)[0] + ".json"
        if not os.path.exists(meta_path):
            sys.exit(f"{meta_path}가 없어 모자이크할 위치를 알 수 없어요 (iOS 스크린샷 워크플로로 찍은 캡처에만 있음)")
        mask_sensitive(shot, meta_path)
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
    ap.add_argument("--mask", action="store_true", help="날짜·시각·환율 숫자를 모자이크 (raw/NN.json 필요)")
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
            img = frame(os.path.join(args.raw, name), title, sub, size, args.crop_top, args.mask)
            dst = os.path.join(args.out, store, f"{i + 1:02d}.png")
            img.save(dst, optimize=True)
            print(f"[ok] {dst} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
