# EzWoW - Error Catcher

Lua 오류·애드온 동작 차단·경고를 창에 모아 보여 주고 복사할 수 있게 합니다.
Collects Lua errors, blocked addon actions and warnings in a window you can copy from.

- 명령어 / Commands: `/ezerr`, `/오류` (`/ezerr test` · `/ezerr clear` · `/ezerr icon`)

## 한국어
- 오류가 나면 채팅창에 한 줄 알림(5초에 한 번까지)이 뜨고, 아이콘에 새 오류 수가 표시됩니다.
- 같은 오류는 한 줄로 묶어 횟수(x12)와 처음·마지막 시각을 보여 줍니다.
- 오른쪽 상세 칸에 오류 내용·호출 순서·변수 값이 나오며 **전체 선택**으로 바로 복사할 수 있습니다.
- 애드온이 막힌 동작(동작 차단)과 경고도 함께 모읍니다.
- EzWoW 애드온만 보기, 이전 접속 오류 보기, 시험 오류 만들기를 지원합니다.
- 게임의 기본 오류 처리는 그대로 두고 그 앞에서 기록만 합니다.

## English
- A one-line chat notice (at most every 5 seconds) and a counter on the icon when something breaks.
- Repeated errors are grouped with a count (x12) and first/last time.
- The detail pane shows the message, stack and locals; **Select all** to copy.
- Blocked addon actions and warnings are collected too.
- Filter to EzWoW addons, show older sessions, or make a test error.
- The game's own error handling still runs; errors are only recorded on the way.
