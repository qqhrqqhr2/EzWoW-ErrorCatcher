# EzWoW - Error Catcher

Lua 오류·애드온 동작 차단·경고를 창에 모아 보여 주고 복사할 수 있게 합니다.
Collects Lua errors, blocked addon actions and warnings in a window you can copy from.

- 명령어 / Commands: `/ezerr`, `/오류` (`/ezerr test` · `/ezerr clear` · `/ezerr icon`)

## 한국어

![오류 창](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-ErrorCatcher/master/docs/images/ui_ko.png)

> 애드온 코드의 창 크기·좌표·색상·문구로 재현한 **예시 화면**입니다. 오류 내용과 애드온 이름(MyAddon 등)은 예시입니다.

- 오류가 나면 채팅창에 한 줄 알림(5초에 한 번까지, 그 사이 생긴 수를 덧붙임)이 뜨고, 아이콘에 새 오류 수가 표시됩니다.
- 같은 오류는 한 줄로 묶어 횟수(x12)와 마지막 시각을 보여 줍니다. 이전 접속 오류는 날짜까지 표시합니다(`11/05 22:41:10`).
- 오른쪽 상세 칸에 처음~마지막 시각, 오류 내용·호출 순서·변수 값이 나오며 **전체 선택 (복사)** 후 Ctrl + C로 복사합니다.
- 애드온 동작 차단과 경고도 함께 모읍니다(노란색).
- EzWoW 애드온만 보기, 이전 접속 포함, 채팅창 알림·아이콘 켜고 끄기, 시험 오류 만들기, 언어(자동 + 8개 언어).
- 최근 오류 300개까지 저장합니다. 오류 내용 1000자, 호출 순서 4000자, 변수 값 2000자를 넘으면 잘라서 저장합니다.
- 게임의 기본 오류 처리는 그대로 두고 그 앞에서 기록만 합니다.
- `/ezerr icon`: 아이콘을 다시 켜고 처음 위치로 옮깁니다. 아이콘은 끌어서 옮길 수 있습니다.

## English

![Error window](https://raw.githubusercontent.com/qqhrqqhr2/EzWoW-ErrorCatcher/master/docs/images/ui_en.png)

> A **mock-up** rebuilt from the window sizes, coordinates, colours and strings in the addon code. Errors and addon names (MyAddon etc.) are examples.

- A one-line chat notice (at most every 5 seconds, with the number held back meanwhile) and a counter on the icon when something breaks.
- Repeated errors are grouped with a count (x12) and the last time. Errors from older sessions also show the date (`11/05 22:41:10`).
- The detail pane shows the first ~ last time, the message, stack and locals; **Select all (copy)**, then Ctrl + C.
- Blocked addon actions and warnings are collected too (gold).
- EzWoW addons only, older sessions, chat notice and icon on/off, a test error, and language (auto + 8 languages).
- The latest 300 errors are kept. Messages over 1000 characters, stacks over 4000 and locals over 2000 are cut when saved.
- The game's own error handling still runs; errors are only recorded on the way.
- `/ezerr icon` shows the icon again at its default spot. Drag the icon to move it.
