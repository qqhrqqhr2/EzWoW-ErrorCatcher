#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Error Catcher (docs/images/ui_ko.png, ui_en.png).

The window is rebuilt from the sizes, positions, colours and texts in UI/MainWindow.lua,
Core/UIKit.lua, Core/Init.lua and Core/Locales.lua (game pixels x SCALE).
The error entries are made-up examples from fictional addons.
usage: python scripts/make_readme_images.py .   (needs Google Chrome; standard library only)
"""
import base64
import html
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PAGE_W = 1600
SCALE = 1.6

# ns.Style (Core/Init.lua)
ACCENT = "#e77c70"               # accent .906 .486 .439
WARN = "#f2c254"                 # warning .95 .76 .33
BG = "rgba(18,24,31,.97)"        # bgPrimary
PANEL = "rgba(29,40,49,.96)"     # bgSecondary
INPUT = "rgba(12,17,22,.96)"     # bgInput
ACC_BG = "rgba(56,31,28,.96)"    # bgAccent
BORDER = "#344c5b"
TEXT = "#edf4f7"
MUTED = "#a7b9c5"
DISABLED = "#63727b"
CALL = ACCENT

# UI/MainWindow.lua
WIDTH, HEIGHT, LIST_WIDTH = 820, 520, 300
ROW_H, ROW_GAP = 40, 3

FONT = "'Noto Sans KR', 'Malgun Gothic', sans-serif"
MONO = "Consolas, 'Malgun Gothic', monospace"


def read_locales(root):
    """koKR / enUS tables of Core/Locales.lua -> {key: text}."""
    src = (root / "Core" / "Locales.lua").read_text(encoding="utf-8")
    out = {}
    for code, lang in (("koKR", "ko"), ("enUS", "en")):
        block = re.search(r"\n    %s = \{(.*?)\n    \}," % code, src, re.S).group(1)
        out[lang] = {k: v for k, v in re.findall(r'(\w+) = "((?:[^"\\]|\\.)*)"', block)}
        # issue reporter option: added per language after the main tables ({ label, tooltip })
        m = re.search(r'\n    %s = \{ "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)" \}' % code, src)
        out[lang]["opt_hideIssueReport"], out[lang]["tip_hideIssueReport"] = m.group(1), m.group(2)
    return out


def read_version(root):
    toc = (root / "EzWoW-ErrorCatcher.toc").read_text(encoding="utf-8")
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    return m.group(1) if m else ""


def test_error_line(root):
    src = (root / "Modules" / "Capture.lua").read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(src, 1):
        if 'error(ns:L("testError"))' in line:
            return i
    return 1


def px(v):
    return f"{v * SCALE:.1f}px"


def esc(s):
    return html.escape(s, quote=False)


# example entries: (addon, kind, count, message, first, last, older)
def sample_entries(L, test_line):
    p = "Interface/AddOns/"
    return [
        ("MyAddon", "error", 12, p + "MyAddon/Core/Frames.lua:142: attempt to index field 'healthBar' (a nil value)",
         "21:02:51", "21:14:08", False),
        ("EzWoW-ErrorCatcher", "error", 1, p + f"EzWoW-ErrorCatcher/Modules/Capture.lua:{test_line}: " + L["testError"],
         "21:12:40", "21:12:40", False),
        ("MyActionBars", "blocked", 3, "[ADDON_ACTION_BLOCKED] MyActionBars: UseAction()", "21:05:17", "21:09:33", False),
        ("MyRaidFrames", "error", 46, p + "MyRaidFrames/Auras.lua:57: attempt to compare number with nil",
         "20:58:02", "21:07:45", False),
        ("MyMinimap", "warning", 1, "Couldn't open " + p + "MyMinimap/Media/Border.tga", "20:57:30", "20:57:30", False),
        ("MyQuestHelper", "error", 2, p + "MyQuestHelper/Quests.lua:88: bad argument #1 to 'pairs' (table expected, got nil)",
         "20:57:41", "20:57:44", False),
        ("MyAddon", "error", 1, p + "MyAddon/Options.lua:23: attempt to call global 'GetItemInfo' (a nil value)",
         "11/05 22:41:10", "11/05 22:41:10", True),
        ("MyChatTools", "error", 4, p + "MyChatTools/Links.lua:310: attempt to concatenate local 'name' (a nil value)",
         "11/05 22:16:03", "11/05 22:30:52", True),
        ("MyMacros", "blocked", 1, "[ADDON_ACTION_FORBIDDEN] MyMacros: PickupMacro()", "11/05 21:48:19", "11/05 21:48:19", True),
        ("MyBagSort", "error", 1, p + "MyBagSort/Sort.lua:71: attempt to perform arithmetic on a nil value",
         "11/04 19:20:44", "11/04 19:20:44", True),
    ]


SEL_STACK = """[Interface/AddOns/MyAddon/Core/Frames.lua]:142: in function 'UpdateHealth'
[Interface/AddOns/MyAddon/Core/Frames.lua]:96: in function <Interface/AddOns/MyAddon/Core/Frames.lua:90>"""

SEL_LOCALS = """self = Frame {
 unit = "target"
 healthBar = nil
}
health = 1520
maxHealth = 1980
(*temporary) = nil"""

T = {
    "ko": {
        "head": "Lua 오류·동작 차단·경고를 한 창에 모아 묶어 보여 주고, 그대로 복사할 수 있습니다.",
        "notes": [
            ("오류 목록", "같은 오류는 한 줄로 묶어 횟수(x12)와 마지막 시각을 표시. 코랄 = Lua 오류, 노랑 = 동작 차단·경고. 이전 접속 오류는 날짜까지(11/05 22:41:10)."),
            ("상세 칸", "애드온 · 종류 · 횟수 · 처음~마지막 시각, 그 아래 오류 내용 · 호출 순서 · 변수 값."),
            ("전체 선택 (복사)", "상세 내용을 모두 선택합니다. Ctrl + C로 복사. 이 오류 지우기."),
            ("필터", "EzWoW 애드온만, 이전 접속 포함(최근 300개까지 저장)."),
            ("알림·아이콘·F6", "채팅창 알림, 화면 아이콘, 이슈 리포터 창과 툴팁의 'F6 버그 제보' 문구 숨김(기본 켬)을 켜고 끕니다."),
            ("아래 버튼", "모두 지우기 · 시험 오류 만들기(수집 확인용) · 언어(자동 + 8개 언어)."),
            ("채팅창 알림", "새 오류마다 한 줄, 5초에 한 번까지. 그 사이 생긴 오류 수를 덧붙이고, 전투 중 오류는 전투가 끝난 뒤 알립니다."),
            ("아이콘", "새 오류 수 배지. 클릭: 오류 창 · 끌기: 이동. 오류가 없으면 흐리게 표시."),
        ],
        "foot": "애드온 코드의 창 크기·좌표·색상·문구로 재현한 예시 화면입니다. 오류 내용과 애드온 이름(MyAddon 등)은 예시입니다.",
        "chat_extra": "그 사이 %d개 더",
    },
    "en": {
        "head": "Lua errors, blocked actions and warnings in one window, grouped and ready to copy.",
        "notes": [
            ("Error list", "Repeated errors are grouped with a count (x12) and the last time. Coral = Lua error, gold = blocked action / warning. Older sessions show the date too (11/05 22:41:10)."),
            ("Detail pane", "Addon · kind · count · first ~ last time, then the message, stack and locals."),
            ("Select all (copy)", "Selects the whole detail text; press Ctrl + C. Remove deletes the entry."),
            ("Filters", "EzWoW addons only, older sessions (the latest 300 are kept)."),
            ("Notice · icon · F6", "Chat notice, screen icon, and hiding the issue reporter frame and the 'F6' bug line on tooltips (on by default)."),
            ("Bottom buttons", "Clear all · make a test error (checks the capture) · language (auto + 8 languages)."),
            ("Chat notice", "One line per new error, at most every 5 seconds, with the number held back meanwhile. Errors in combat are announced after combat."),
            ("Icon", "Badge with the number of new errors. Click: error window · drag: move. Dimmed when there are none."),
        ],
        "foot": "Mock-up rebuilt from the window sizes, coordinates, colours and strings in the addon code. Errors and addon names (MyAddon etc.) are examples.",
    },
}


CSS = f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: {PAGE_W}px; overflow: hidden; }}
body {{ background: radial-gradient(ellipse at 30% 0%, #2a2224 0%, #14191f 55%, #0b1014 100%);
  font-family: {FONT}; color: {TEXT}; }}
.page {{ position: relative; padding: 34px 50px 40px; }}
h1 {{ color: {ACCENT}; font-size: 40px; font-weight: 700; letter-spacing: .3px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.abs {{ position: absolute; }}
.win {{ position: absolute; background: {BG}; border: 1px solid {BORDER}; }}
.hdr {{ position: absolute; left: 1px; right: 1px; top: 1px; height: {px(58)}; background: rgba(29,40,49,.98); }}
.hline {{ position: absolute; left: 1px; right: 1px; top: {px(57)}; height: {px(2)}; background: {ACCENT}; }}
.title {{ position: absolute; left: {px(48)}; top: {px(9)}; font-size: {px(15)}; color: {ACCENT}; white-space: nowrap; }}
.sub {{ position: absolute; left: {px(48)}; top: {px(32)}; font-size: {px(10)}; color: {MUTED}; white-space: nowrap; }}
.btn {{ position: absolute; background: {PANEL}; border: 1px solid {BORDER}; color: {TEXT}; font-size: {px(11)};
  display: flex; align-items: center; justify-content: center; white-space: nowrap; overflow: hidden; }}
.btn.acc {{ background: {ACC_BG}; border-color: {ACCENT}; color: {ACCENT}; }}
.row {{ position: absolute; background: {PANEL}; border: 1px solid {BORDER}; overflow: hidden; }}
.row.sel {{ background: {ACC_BG}; border-color: {ACCENT}; }}
.row .bar {{ position: absolute; left: 0; top: 0; bottom: 0; width: {px(3)}; }}
.row .addon {{ position: absolute; left: {px(9)}; top: {px(3)}; font-size: {px(12)}; white-space: nowrap; }}
.row .cnt {{ position: absolute; right: {px(7)}; top: {px(4)}; font-size: {px(10)}; color: {TEXT}; white-space: pre; }}
.row .msg {{ position: absolute; left: {px(9)}; right: {px(8)}; bottom: {px(4)}; font-size: {px(10.5)}; color: {MUTED};
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.detail {{ position: absolute; background: {INPUT}; border: 1px solid {BORDER}; overflow: hidden;
  padding: {px(8)} {px(14)} {px(8)} {px(8)}; }}
.detail pre {{ font-family: {MONO}; font-size: {px(10.6)}; line-height: 1.42; color: {TEXT}; white-space: pre-wrap; overflow-wrap: anywhere; }}
.detail pre .h {{ color: {MUTED}; }}
.lbl {{ position: absolute; font-size: {px(12)}; color: {TEXT}; white-space: nowrap; }}
.check {{ position: absolute; width: {px(24)}; height: {px(24)}; padding: {px(3)}; }}
.check i {{ display: block; width: 100%; height: 100%; border: 1px solid #6d6a5d; background: #191919; border-radius: 2px; position: relative; }}
.check.on i::after {{ content: '✔'; position: absolute; left: {px(1)}; top: {px(-6)}; font-size: {px(19)}; color: #ffd200; text-shadow: 0 0 1px #000; }}
.call {{ position: absolute; width: 30px; height: 30px; border-radius: 50%; background: {CALL}; color: #1d0c0a; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #1d0c0a; box-shadow: 0 0 0 2px {CALL}55; }}
.notes {{ position: absolute; }}
.note {{ display: flex; gap: 12px; margin-bottom: 11px; font-size: 16.5px; line-height: 1.5; color: #dfe6ea; }}
.note .n {{ flex: none; width: 28px; height: 28px; border-radius: 50%; background: {CALL}; color: #1d0c0a; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; margin-top: 1px; }}
.note b {{ color: #fff; }}
.foot {{ color: #7d8d98; font-size: 13.5px; }}
.scene {{ position: absolute; border: 1px solid #2b3a45; border-radius: 6px;
  background: linear-gradient(180deg, #1b2a22 0%, #22301f 45%, #2d2a1d 100%); overflow: hidden; }}
.chat {{ position: absolute; background: rgba(0,0,0,.42); padding: 10px 14px; font-size: 17px; line-height: 1.5;
  color: #fff; text-shadow: 1px 1px 1px #000; }}
.chat .dim {{ color: #ffff9f; }}
.tip {{ position: absolute; background: rgba(4,8,14,.94); border: 2px solid #5d6d7a; border-radius: 4px; padding: 10px 14px;
  font-size: 16px; line-height: 1.55; white-space: nowrap; }}
"""


def ui_page(lang, L, icon_uri, version, test_line):
    t = T[lang]
    W, H = WIDTH, HEIGHT
    ox, oy = 128, 160
    parts = []

    def at(x, y):
        return f"left:{px(x)};top:{px(y)};"

    entries = sample_entries(L, test_line)
    session = [e for e in entries if not e[6]]
    sel = entries[0]

    parts.append(f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">')
    # header (UIKit:CreateHeader)
    parts.append('<div class="hdr"></div><div class="hline"></div>')
    parts.append(f'<img class="abs" src="{icon_uri}" style="{at(15, 15)}width:{px(28)};height:{px(28)}">')
    parts.append(f'<div class="title">EzWoW - Error Catcher</div>')
    parts.append(f'<div class="sub" style="max-width:{px(560)};overflow:hidden">{esc(L["subtitle"] % (len(session), len(entries)))}</div>')
    parts.append(f'<div class="btn" style="{at(W - 1 - 10 - 22, 11)}width:{px(22)};height:{px(22)};font-size:{px(12)}">X</div>')

    # list (12, 70) .. bottom 76, rows 40 + 3, width LIST_WIDTH - 8
    list_h = H - 70 - 76
    visible = (list_h + ROW_GAP) // (ROW_H + ROW_GAP)
    for i, (addon, kind, count, msg, first, last, older) in enumerate(entries[:visible]):
        color = ACCENT if kind == "error" else WARN
        y = 70 + i * (ROW_H + ROW_GAP)
        cnt = (f"x{count}  " if count > 1 else "") + last
        short = re.sub(r"^.*?[Aa]dd[Oo]ns[/\\][^/\\]+[/\\]", "", msg, count=1)
        parts.append(f'<div class="row{" sel" if i == 0 else ""}" style="{at(12, y)}width:{px(LIST_WIDTH - 8)};height:{px(ROW_H)}">'
                     f'<span class="bar" style="background:{color}"></span>'
                     f'<span class="addon" style="color:{color}">{esc(addon)}</span><span class="cnt">{esc(cnt)}</span>'
                     f'<span class="msg">{esc(short)}</span></div>')
    # scroll track + thumb (4 px on the right of the list)
    thumb = max(20, list_h * visible / len(entries))
    parts.append(f'<div class="abs" style="{at(12 + LIST_WIDTH - 4, 70)}width:{px(4)};height:{px(list_h)};background:rgba(52,76,91,.35)"></div>')
    parts.append(f'<div class="abs" style="{at(12 + LIST_WIDTH - 4, 70)}width:{px(4)};height:{px(thumb)};background:rgba(231,124,112,.75)"></div>')

    # detail side
    left = 12 + LIST_WIDTH + 10
    kind_text = L["kind_" + sel[1]]
    info = f"{sel[0]}  ·  {kind_text}  ·  x{sel[2]}  ·  {sel[4]} ~ {sel[5]}"
    parts.append(f'<div class="lbl" style="{at(left + 2, 76)}font-size:{px(10.5)};color:{MUTED}">{esc(info)}</div>')
    parts.append(f'<div class="btn acc" style="{at(W - 12 - 120, 70)}width:{px(120)};height:{px(24)}">{esc(L["selectAll"])}</div>')
    parts.append(f'<div class="btn" style="{at(W - 12 - 120 - 6 - 100, 70)}width:{px(100)};height:{px(24)}">{esc(L["remove"])}</div>')
    text = (f'{esc(sel[3])}\n\n<span class="h">---- {esc(L["stack"])} ----</span>\n{esc(SEL_STACK)}\n\n'
            f'<span class="h">---- {esc(L["locals"])} ----</span>\n{esc(SEL_LOCALS)}')
    parts.append(f'<div class="detail" style="{at(left, 100)}width:{px(W - 12 - left)};height:{px(H - 76 - 100)}"><pre>{text}</pre></div>')

    # option checks: BOTTOMLEFT x, 40 (24 x 24), label 4 px to the right, 160 px apart
    # (showOlder is off by default; it is on here so the list shows older sessions)
    checks = [(12, "onlyEzWoW", False), (172, "showOlder", True), (332, "chatNotice", True), (492, "showIcon", True),
              (652, "hideIssueReport", True)]
    for x, key, on in checks:
        y = H - 40 - 24
        parts.append(f'<div class="check{" on" if on else ""}" style="{at(x, y)}"><i></i></div>')
        parts.append(f'<div class="lbl" style="{at(x + 28, y + 3)}">{esc(L["opt_" + key])}</div>')

    # bottom buttons
    by = H - 10 - 24
    parts.append(f'<div class="btn" style="{at(12, by)}width:{px(130)};height:{px(24)}">{esc(L["clearAll"])}</div>')
    parts.append(f'<div class="btn" style="{at(148, by)}width:{px(130)};height:{px(24)}">{esc(L["test"])}</div>')
    parts.append(f'<div class="btn" style="{at(284, by)}width:{px(160)};height:{px(24)}">{esc(L["language"])}: Auto ▼</div>')
    parts.append(f'<div class="btn acc" style="{at(W - 12 - 150, by)}width:{px(150)};height:{px(24)}">{esc(L["donate"])}</div>')
    ver = (f"v{version}  ·  " if version else "") + "/ezerr"
    parts.append(f'<div class="lbl" style="right:{px(12 + 150 + 10)};top:{px(by + 5)};font-size:{px(10)};color:#808080">{esc(ver)}</div>')
    parts.append('</div>')

    # scene under the window: chat notice + launcher icon
    sy = oy + H * SCALE + 46
    sh = 150
    parts.append(f'<div class="scene" style="left:{ox}px;top:{sy:.0f}px;width:{W * SCALE:.0f}px;height:{sh}px">')
    first_line = entries[3][3]
    if len(first_line) > 120:
        first_line = first_line[:117] + "..."
    pre = f'<span style="color:{ACCENT}">EzWoW - Error Catcher:</span> '
    line1 = pre + esc(L["notice"] % (sel[0], sel[3]))
    line2 = pre + esc(L["notice"] % (entries[3][0], first_line) + L["noticeMore"] % 2)
    parts.append(f'<div class="chat" style="left:14px;top:14px;width:900px">{line1}<br>{line2}</div>')
    # launcher: 32 x 32, badge 18 x 16 at TOPRIGHT (+6, +4)
    lx = W * SCALE - 90
    ly = 52
    parts.append(f'<div class="abs" style="left:{lx:.0f}px;top:{ly}px;width:{px(32)};height:{px(32)}">'
                 f'<img src="{icon_uri}" style="width:100%;height:100%">'
                 f'<div class="abs" style="right:{px(-6)};top:{px(-4)};min-width:{px(18)};height:{px(16)};padding:0 {px(4)};'
                 f'background:rgba(140,31,26,.95);border:1px solid {ACCENT};color:#fff;font-size:{px(10)};'
                 f'display:flex;align-items:center;justify-content:center">3</div></div>')
    # tooltip (ANCHOR_LEFT)
    tip = (f'<div style="color:{ACCENT};font-size:17px">EzWoW - Error Catcher</div>'
           f'<div>{esc(L["iconCount"] % (len(session), 3))}</div>'
           f'<div style="color:{MUTED}">{esc(L["iconHint"])}</div>')
    parts.append(f'<div class="tip" style="right:{W * SCALE - lx + 14:.0f}px;top:30px">{tip}</div>')
    parts.append('</div>')

    # callouts (game px -> page px)
    def cx(x): return ox + x * SCALE
    def cy(y): return oy + y * SCALE
    rx = cx(W) + 26
    calls = [
        (cx(0) - 26, cy(70 + 1.5 * (ROW_H + ROW_GAP))),        # 1 list
        (rx, cy(250)),                                         # 2 detail
        (rx, cy(82)),                                          # 3 select all
        (cx(0) - 26, cy(H - 52)),                              # 4 filters
        (cx(332) - 20, cy(H - 52)),                            # 5 notice / icon / issue reporter checks
        (cx(0) - 26, cy(H - 22)),                              # 6 bottom buttons
        (ox - 26, sy + 38),                                    # 7 chat
        (ox + lx + 32 * SCALE + 34, sy + ly + 14),             # 8 icon
    ]
    for i, (x, y) in enumerate(calls, 1):
        parts.append(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>')

    notes_top = sy + sh + 40
    def note_html(start, lst):
        return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{esc(a)}</b> — {esc(b)}</div></div>'
                       for i, (a, b) in enumerate(lst))
    parts.append(f'<div class="notes" style="left:50px;top:{notes_top:.0f}px;width:730px">{note_html(1, t["notes"][:4])}</div>')
    parts.append(f'<div class="notes" style="left:820px;top:{notes_top:.0f}px;width:730px">{note_html(5, t["notes"][4:])}</div>')
    page_h = notes_top + 290
    parts.append(f'<div class="abs foot" style="left:50px;top:{page_h - 44:.0f}px">{esc(t["foot"])}</div>')
    body = (f'<div class="page" style="height:{page_h:.0f}px"><h1>EzWoW - Error Catcher</h1>'
            f'<div class="lead">{esc(t["head"])}</div></div>' + "".join(parts))
    return body, int(page_h)


def render(html_path, png_path, height, profile):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={profile}",
                    f"--window-size={PAGE_W},{height}", f"--screenshot={png_path}", html_path.resolve().as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)


def main(root: Path):
    root = root.resolve()
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    icon_uri = "data:image/png;base64," + base64.b64encode((root / "Media" / "Icon.png").read_bytes()).decode()
    locales = read_locales(root)
    version = read_version(root)
    test_line = test_error_line(root)
    tmp = Path(tempfile.mkdtemp(prefix="ezwow_errorcatcher_"))
    for lang in ("ko", "en"):
        body, h = ui_page(lang, locales[lang], icon_uri, version, test_line)
        page = f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{body}</body></html>'
        html_path = tmp / f"ui_{lang}.html"
        html_path.write_text(page, encoding="utf-8")
        png = out / f"ui_{lang}.png"
        render(html_path, png, h, tmp / f"chrome_profile_{lang}")
        print("wrote", png, h)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
