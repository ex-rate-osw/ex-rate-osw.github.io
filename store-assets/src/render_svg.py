"""SVG → PNG 렌더링 (Chromium). 사용법: python3 render_svg.py 입력.svg 출력.png 너비 높이"""
import asyncio, sys, pathlib
from playwright.async_api import async_playwright

async def main(src, out, w, h):
    svg = pathlib.Path(src).read_text(encoding="utf-8")
    html = f"<html><body style='margin:0;background:transparent'>{svg}</body></html>"
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={"width": w, "height": h})
        await pg.set_content(html)
        await pg.evaluate(f"(()=>{{const s=document.querySelector('svg');s.setAttribute('width',{w});s.setAttribute('height',{h});s.style.display='block'}})()")
        await pg.wait_for_timeout(200)
        await pg.screenshot(path=out, omit_background=True, clip={"x": 0, "y": 0, "width": w, "height": h})
        await b.close()

asyncio.run(main(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])))
