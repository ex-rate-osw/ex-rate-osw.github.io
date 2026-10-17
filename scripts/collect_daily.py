#!/usr/bin/env python3
"""
한국수출입은행 현재환율 API로 일별 환율을 수집한다 (GitHub Actions에서 실행).

- 환경변수 KOREAEXIM_API_KEY 필요 (https://www.koreaexim.go.kr 오픈API에서 발급)
- 영업일 오전 11시 전후 하루 1번 고시되는 값을 기록한다.
- 실행될 때마다 오늘 값과, 아직 없는 과거 영업일(최근 BACKFILL_DAYS일)을 함께 채운다.
  GitHub 예약 실행이 며칠 건너뛰어도 다음 실행 때 빠진 날이 채워진다.

결과
  data/daily.csv        date, code, name, unit, base, ttb, tts
                        base = 매매기준율, ttb = 송금 받을 때, tts = 송금 보낼 때
                        unit = 기준 단위 (JPY, IDR은 100)
  data/no_data_dates.txt  조회했지만 고시가 없던 과거 날짜(공휴일 등). 다시 조회하지 않는다.

출처: 한국수출입은행 (공공데이터)
"""
import csv
import http.cookiejar
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.environ.get("DATA_DIR", os.path.join(ROOT, "data"))
CSV_PATH = os.path.join(DATA_DIR, "daily.csv")
EMPTY_PATH = os.path.join(DATA_DIR, "no_data_dates.txt")
FIELDS = ["date", "code", "name", "unit", "base", "ttb", "tts"]

API_URL = "https://oapi.koreaexim.go.kr/site/program/financial/exchangeJSON"
BACKFILL_DAYS = int(os.environ.get("BACKFILL_DAYS", "400"))  # 약 1년 + 여유
MAX_CALLS = int(os.environ.get("MAX_CALLS", "300"))  # 실행 1번당 최대 호출 수 (일일 한도 1000회)
RELEASE_HOUR = 11  # 영업일 11시 전후 고시

RESULT_ERRORS = {2: "DATA 코드 오류", 3: "인증키 오류 (만료·파기 여부 확인)", 4: "일일 호출 한도(1,000회) 초과"}


class StopCollect(Exception):
    """더 호출해도 의미 없는 오류 (인증키 오류, 한도 초과 등)"""


class CollectFailed(Exception):
    """조회한 날짜가 모두 실패함"""

    def __init__(self, errors):
        self.errors = errors
        super().__init__(f"{len(errors)}건 모두 실패 - 첫 오류: {errors[0][1]}")


def annotate(msg):
    """GitHub Actions 실행 화면에 오류 알림으로 표시 (로그인 없이도 보임)"""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print("::error::" + msg.replace("\n", " ").replace("%", "%25"))


# 일부 환경에서 쿠키 없이 요청하면 리다이렉트가 반복되는 경우가 있어 쿠키를 유지한다.
_opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
)


def http_json(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "ex-rate-osw/2.0"})
    with _opener.open(req, timeout=timeout) as res:
        body = res.read().decode("utf-8").strip()
    return json.loads(body) if body else None


def to_number(s):
    s = str(s or "").replace(",", "").strip()
    return float(s) if s else None


def parse_unit(cur_unit):
    """'JPY(100)' -> ('JPY', 100), 'USD' -> ('USD', 1)"""
    m = re.match(r"^\s*([A-Z]{3})\s*(?:\((\d+)\))?\s*$", str(cur_unit or ""))
    if not m:
        return None, None
    return m.group(1), int(m.group(2) or 1)


def fetch_day(api_key, day):
    """하루치 환율. 고시가 없으면 [] (휴일, 11시 이전 등)."""
    query = urllib.parse.urlencode({"authkey": api_key, "searchdate": day.strftime("%Y%m%d"), "data": "AP01"})
    data = http_json(f"{API_URL}?{query}")
    if not data:
        return []
    rows = []
    for item in data:
        result = int(item.get("result") or 0)
        if result != 1:
            raise StopCollect(f"수출입은행 API 오류 {result}: {RESULT_ERRORS.get(result, '알 수 없음')}")
        code, unit = parse_unit(item.get("cur_unit"))
        base = to_number(item.get("deal_bas_r"))
        if not code or code == "KRW" or not base:
            continue
        rows.append({
            "date": day.isoformat(),
            "code": code,
            "name": str(item.get("cur_nm") or code).strip(),
            "unit": unit,
            "base": f"{base:.2f}",
            "ttb": f"{to_number(item.get('ttb')) or 0:.2f}",
            "tts": f"{to_number(item.get('tts')) or 0:.2f}",
        })
    return rows


def read_rows():
    if not os.path.exists(CSV_PATH):
        return []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        return [r for r in csv.DictReader(f) if r.get("date") and r.get("code")]


def write_rows(rows):
    os.makedirs(DATA_DIR, exist_ok=True)
    rows = sorted(rows, key=lambda r: (r["date"], r["code"]))
    tmp = CSV_PATH + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    os.replace(tmp, CSV_PATH)


def read_empty():
    if not os.path.exists(EMPTY_PATH):
        return set()
    with open(EMPTY_PATH, encoding="utf-8") as f:
        return {l.strip() for l in f if l.strip()}


def write_empty(days):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(EMPTY_PATH, "w", encoding="utf-8") as f:
        f.write("".join(d + "\n" for d in sorted(days)))


def dates_to_check(have, empty, now):
    """조회가 필요한 날짜 (최신 날짜부터). 주말과 이미 확인한 날은 뺀다."""
    today = now.date()
    start = today if now.hour >= RELEASE_HOUR else today - timedelta(days=1)
    out = []
    for i in range(BACKFILL_DAYS):
        d = start - timedelta(days=i)
        key = d.isoformat()
        if d.weekday() >= 5 or key in have or key in empty:
            continue
        out.append(d)
    return out


def collect(api_key, now=None, fetch=fetch_day, sleep=time.sleep):
    now = now or datetime.now(KST)
    rows = read_rows()
    have = {r["date"] for r in rows}
    empty = read_empty()
    todo = dates_to_check(have, empty, now)
    added_days, empty_days, calls = [], [], 0
    errors = []  # (날짜, 오류) — 네트워크·응답 오류

    for d in todo:
        if calls >= MAX_CALLS:
            print(f"[info] 이번 실행 호출 한도({MAX_CALLS}) 도달, 나머지 {len(todo) - calls}일은 다음 실행에서 채움")
            break
        try:
            day_rows = fetch(api_key, d)
        except StopCollect:
            raise
        except Exception as e:  # 네트워크 오류 등은 그날만 건너뛰고 다음 실행에서 다시 시도
            msg = f"{type(e).__name__}: {e}"
            print(f"[warn] {d} 조회 실패 - {msg}", file=sys.stderr)
            errors.append((d.isoformat(), msg))
            calls += 1
            if len(errors) >= 5 and not added_days and not empty_days:
                break  # 처음부터 연달아 실패하면 더 호출하지 않음 (같은 원인일 가능성이 큼)
            continue
        calls += 1
        if day_rows:
            rows.extend(day_rows)
            added_days.append(d.isoformat())
        elif d < now.date():
            # 지난 영업일인데 고시가 없으면 공휴일로 보고 다시 조회하지 않음 (오늘은 나중에 다시 확인)
            empty.add(d.isoformat())
            empty_days.append(d.isoformat())
        sleep(0.2)

    if added_days:
        write_rows(rows)
    if empty_days:
        write_empty(empty)
    if errors and not added_days and not empty_days:
        raise CollectFailed(errors)
    return added_days, empty_days, calls


def main():
    api_key = os.environ.get("KOREAEXIM_API_KEY", "").strip()
    if not api_key:
        print("[error] KOREAEXIM_API_KEY가 설정되지 않았습니다 (저장소 Settings → Secrets → Actions)", file=sys.stderr)
        return 1
    try:
        added, empty, calls = collect(api_key)
    except StopCollect as e:
        print(f"[error] {e}", file=sys.stderr)
        annotate(str(e))
        return 1
    except CollectFailed as e:
        print(f"[error] 수출입은행 API 조회 실패: {e}", file=sys.stderr)
        for day, msg in e.errors[:3]:
            annotate(f"{day} 조회 실패 - {msg}"[:300])
        return 1
    print(f"[ok] 호출 {calls}회 · 추가 {len(added)}일"
          + (f" ({added[0]} ~ {added[-1]})" if added else "")
          + f" · 고시 없음 {len(empty)}일")
    return 0


if __name__ == "__main__":
    sys.exit(main())
