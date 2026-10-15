#!/usr/bin/env python3
"""
환율 수집 스크립트 (GitHub Actions에서 매시간 실행)

- 1순위: Twelve Data (환경변수 TWELVE_DATA_API_KEY 필요, 시장 실시간 환율)
- 2순위: ExchangeRate-API 무료 엔드포인트 (키 불필요, 하루 1회 갱신 값)

결과는 data/rates.csv 에 한 줄씩 추가된다.
  timestamp_kst, usd, jpy100, eur, source
  (모두 원화 기준, 엔화는 100엔당)
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
FIELDS = ["timestamp_kst", "usd", "jpy100", "eur", "source"]

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


def append_row(rates, now=None):
    now = now or datetime.now(KST)
    row = {
        "timestamp_kst": now.strftime("%Y-%m-%d %H:%M"),
        "usd": f"{rates['usd']:.2f}",
        "jpy100": f"{rates['jpy100']:.2f}",
        "eur": f"{rates['eur']:.2f}",
        "source": rates["source"],
    }
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    new_file = not os.path.exists(CSV_PATH) or os.path.getsize(CSV_PATH) == 0
    with open(CSV_PATH, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        if new_file:
            writer.writeheader()
        writer.writerow(row)
    return row


def main():
    try:
        rates = fetch()
    except Exception as e:
        print(f"[error] 모든 출처에서 환율 수집 실패: {e}", file=sys.stderr)
        return 1
    row = append_row(rates)
    print(f"[ok] {row}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
