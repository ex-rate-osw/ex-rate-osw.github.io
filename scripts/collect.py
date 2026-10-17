#!/usr/bin/env python3
"""
환율 수집 스크립트 (GitHub Actions에서 매시간 실행)

- 1순위: Twelve Data (환경변수 TWELVE_DATA_API_KEY 필요, 시장 실시간 환율)
- 2순위: ExchangeRate-API 무료 엔드포인트 (키 불필요, 하루 1회 갱신 값)

결과는 data/rates.csv 에 시간대(정시)마다 한 줄씩 저장된다.
  slot_kst      어느 시간대 기록인지  예) 2026-10-16 13:00 = 13시 기록
  timestamp_kst 실제 수집한 시각     예) 2026-10-16 13:43
  usd, jpy100, eur, source  (모두 원화 기준, 엔화는 100엔당)

GitHub 예약 실행은 자주 건너뛰어지므로, 실행될 때마다 Twelve Data 시간봉으로
빠진 시간대를 그 시간 정각 시세(시가)로 채운다. 이런 줄은 source가 twelvedata-1h.
"""
import csv
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.environ.get("RATES_CSV", os.path.join(ROOT, "data", "rates.csv"))
FIELDS = ["slot_kst", "timestamp_kst", "usd", "jpy100", "eur", "source"]

# 터무니없는 값이 기록되지 않도록 하는 안전 범위 (원)
SANE = {"usd": (500, 5000), "jpy100": (300, 3000), "eur": (500, 5000)}


def http_json(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "ex-rate-osw/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        return json.loads(res.read().decode("utf-8"))


def from_twelvedata(api_key):
    query = urllib.parse.urlencode(
        {"symbol": "USD/KRW,JPY/KRW,EUR/KRW", "apikey": api_key, "dp": 6}
    )
    data = http_json(f"https://api.twelvedata.com/price?{query}")
    if data.get("status") == "error":
        raise RuntimeError(f"Twelve Data 오류: {data.get('message')}")

    def price(symbol):
        item = data.get(symbol) or {}
        if item.get("status") == "error" or "price" not in item:
            raise RuntimeError(f"Twelve Data {symbol} 응답 이상: {item}")
        return float(item["price"])

    return {
        "usd": price("USD/KRW"),
        "jpy100": price("JPY/KRW") * 100,
        "eur": price("EUR/KRW"),
        "source": "twelvedata",
    }


def from_open_er_api():
    data = http_json("https://open.er-api.com/v6/latest/KRW")
    if data.get("result") != "success":
        raise RuntimeError(f"ExchangeRate-API 오류: {data.get('error-type')}")
    r = data["rates"]  # 1원당 외화 → 역수로 외화 1단위당 원화
    return {
        "usd": 1 / r["USD"],
        "jpy100": 100 / r["JPY"],
        "eur": 1 / r["EUR"],
        "source": "open.er-api",
    }


def validate(rates):
    for key, (lo, hi) in SANE.items():
        v = rates[key]
        if not (lo <= v <= hi):
            raise RuntimeError(f"{key} 값이 비정상 범위입니다: {v}")
    return rates


def fetch():
    api_key = os.environ.get("TWELVE_DATA_API_KEY", "").strip()
    sources = []
    if api_key:
        sources.append(("Twelve Data", lambda: from_twelvedata(api_key)))
    sources.append(("ExchangeRate-API", from_open_er_api))

    errors = []
    for name, fn in sources:
        try:
            return validate(fn())
        except Exception as e:  # 다음 출처로 넘어감
            errors.append(f"{name}: {e}")
            print(f"[warn] {name} 실패 - {e}", file=sys.stderr)
    raise RuntimeError(" / ".join(errors))


def slot_of(now):
    """수집 시각이 속한 시간대(정시)  예) 13:43 -> '2026-10-16 13:00'"""
    return now.strftime("%Y-%m-%d %H:00")


def read_rows():
    """기존 CSV를 읽는다. 예전 형식(slot_kst 없음)이면 수집 시각으로 시간대를 채운다."""
    if not os.path.exists(CSV_PATH) or os.path.getsize(CSV_PATH) == 0:
        return []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r.get("timestamp_kst")]
    for r in rows:
        if not r.get("slot_kst"):
            r["slot_kst"] = r["timestamp_kst"][:13] + ":00"
    return rows


def write_rows(rows):
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    tmp = CSV_PATH + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(tmp, CSV_PATH)


def save_rate(rates, now=None):
    """이번 시간대 기록을 저장한다. 같은 시간대 기록이 이미 있으면 새 값으로 바꾼다."""
    now = now or datetime.now(KST)
    row = {
        "slot_kst": slot_of(now),
        "timestamp_kst": now.strftime("%Y-%m-%d %H:%M"),
        "usd": f"{rates['usd']:.2f}",
        "jpy100": f"{rates['jpy100']:.2f}",
        "eur": f"{rates['eur']:.2f}",
        "source": rates["source"],
    }
    rows = [r for r in read_rows() if r["slot_kst"] != row["slot_kst"]]
    rows.append(row)
    rows.sort(key=lambda r: r["slot_kst"])
    write_rows(rows)
    return row


def already_recorded_this_hour(now=None):
    """이번 시간대(KST)에 이미 기록이 있으면 True"""
    slot = slot_of(now or datetime.now(KST))
    return any(r["slot_kst"] == slot for r in read_rows())


BACKFILL_SOURCE = "twelvedata-1h"
BACKFILL_BARS = 120  # 최근 120개 시간봉 (시장이 열린 시간 기준 약 5일)
SYMBOLS = {"usd": ("USD/KRW", 1), "jpy100": ("JPY/KRW", 100), "eur": ("EUR/KRW", 1)}


def hourly_opens_twelvedata(api_key, symbol, outputsize=BACKFILL_BARS):
    """시간봉의 시가(정각 시세)를 {'YYYY-MM-DD HH:00': 값} 으로 돌려준다 (한국시간)."""
    query = urllib.parse.urlencode({
        "symbol": symbol, "interval": "1h", "outputsize": outputsize,
        "timezone": "Asia/Seoul", "dp": 6, "apikey": api_key,
    })
    data = http_json(f"https://api.twelvedata.com/time_series?{query}")
    if data.get("status") == "error" or "values" not in data:
        raise RuntimeError(f"Twelve Data {symbol} 시간봉 오류: {data.get('message')}")
    out = {}
    for bar in data["values"]:
        dt = str(bar.get("datetime", ""))
        if len(dt) < 13 or dt[13:16] not in ("", ":00"):
            continue  # 정시 봉이 아니면 무시
        out[dt[:13] + ":00"] = float(bar["open"])
    return out


def backfill(api_key, now=None, fetch_hourly=hourly_opens_twelvedata):
    """빠진 시간대를 시간봉 시가(그 시간 정각 시세)로 채운다.
    이미 있는 기록은 건드리지 않고, 세 통화가 모두 있는 시간대만 채운다.
    시장이 닫힌 시간(주말)은 시간봉이 없으므로 채워지지 않는다."""
    now = now or datetime.now(KST)
    current = slot_of(now)
    series = {key: fetch_hourly(api_key, sym) for key, (sym, _) in SYMBOLS.items()}
    rows = read_rows()
    have = {r["slot_kst"] for r in rows}
    added = []
    for slot in sorted(set.intersection(*(set(v) for v in series.values()))):
        if slot in have or slot > current:
            continue
        rates = {key: series[key][slot] * mult for key, (_, mult) in SYMBOLS.items()}
        rates["source"] = BACKFILL_SOURCE
        try:
            validate(rates)
        except RuntimeError as e:
            print(f"[warn] {slot} 보충 건너뜀 - {e}", file=sys.stderr)
            continue
        rows.append({
            "slot_kst": slot,
            "timestamp_kst": slot,  # 정각 시세
            "usd": f"{rates['usd']:.2f}",
            "jpy100": f"{rates['jpy100']:.2f}",
            "eur": f"{rates['eur']:.2f}",
            "source": BACKFILL_SOURCE,
        })
        added.append(slot)
    if added:
        rows.sort(key=lambda r: r["slot_kst"])
        write_rows(rows)
    return added


def market_open(now=None):
    """외환시장이 열려 있는 시간인지 (한국시간 월 07시 ~ 토 08시)"""
    now = now or datetime.now(KST)
    wd, h = now.weekday(), now.hour  # 월=0 ... 일=6
    if wd == 5:
        return h < 8
    if wd == 6:
        return False
    if wd == 0:
        return h >= 7
    return True


def main():
    force = os.environ.get("FORCE_COLLECT", "").lower() in ("1", "true")
    api_key = os.environ.get("TWELVE_DATA_API_KEY", "").strip()
    if not force and already_recorded_this_hour():
        print("[skip] 이번 시간대는 이미 기록됨")
        return 0

    status = 0
    if not market_open():
        # 주말에는 시세가 멈춰 있어 같은 값만 쌓이므로 기록하지 않는다 (늦게 돈 실행 대비)
        print("[skip] 외환시장이 닫힌 시간이라 현재 시세는 기록하지 않음")
    else:
        try:
            row = save_rate(fetch())
            print(f"[ok] {row}")
        except Exception as e:
            print(f"[error] 모든 출처에서 환율 수집 실패: {e}", file=sys.stderr)
            status = 1

    # GitHub 예약 실행이 건너뛴 시간대 채우기 (실패해도 이번 기록에는 영향 없음)
    if api_key:
        try:
            added = backfill(api_key)
            print(f"[backfill] {len(added)}개 시간대 보충: {', '.join(a[5:13] for a in added) or '없음'}")
        except Exception as e:
            print(f"[warn] 빠진 시간대 보충 실패 - {e}", file=sys.stderr)
    return status


if __name__ == "__main__":
    sys.exit(main())
