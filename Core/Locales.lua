--===========================================================================
-- EzWoW - Error Catcher
-- Core/Locales.lua : 8-Language Localization Registry (Auto + enUS Fallback)
--===========================================================================
local _, ns = ...
local type, ipairs = type, ipairs

ns.LANGUAGE_OPTIONS = {
    { "auto", "Auto" },
    { "koKR", "한국어" },
    { "enUS", "English" },
    { "deDE", "Deutsch" },
    { "frFR", "Français" },
    { "esES", "Español" },
    { "ruRU", "Русский" },
    { "zhCN", "简体中文" },
    { "zhTW", "繁體中文" },
}

local UI_STRINGS = {
    koKR = {
        subtitle = "이번 접속 오류 %d개 · 저장된 오류 %d개",
        empty = "오류가 없습니다.",
        stack = "호출 순서", locals = "변수 값",
        kind_error = "Lua 오류", kind_blocked = "동작 차단", kind_warning = "경고",
        selectAll = "전체 선택 (복사)", remove = "이 오류 지우기",
        opt_onlyEzWoW = "EzWoW 애드온만", opt_showOlder = "이전 접속 포함",
        opt_chatNotice = "채팅창 알림", opt_showIcon = "아이콘 표시",
        clearAll = "모두 지우기", test = "시험 오류 만들기",
        language = "언어", donate = "후원 · 링크 복사", copy = "후원 링크 · Ctrl + C로 복사",
        iconCount = "이번 접속 오류 %d개 · 새 오류 %d개", iconHint = "클릭: 오류 창 · 끌기: 이동",
        panelDesc = "Lua 오류, 애드온 동작 차단, 경고를 모아 보여 주고 복사할 수 있게 합니다.",
        panelOpen = "오류 창 열기 (/ezerr)",
        cleared = "저장된 오류를 모두 지웠습니다.",
        notice = "오류 [%s] %s  (/ezerr 로 보기)", noticeMore = " · 그 사이 %d개 더",
        testError = "EzWoW - Error Catcher 시험 오류입니다.",
    },
    enUS = {
        subtitle = "%d errors this session · %d saved",
        empty = "No errors.",
        stack = "Stack", locals = "Locals",
        kind_error = "Lua error", kind_blocked = "Blocked action", kind_warning = "Warning",
        selectAll = "Select all (copy)", remove = "Remove",
        opt_onlyEzWoW = "EzWoW addons only", opt_showOlder = "Older sessions",
        opt_chatNotice = "Chat notice", opt_showIcon = "Show icon",
        clearAll = "Clear all", test = "Make a test error",
        language = "Language", donate = "Donate · Copy link", copy = "Donate link · Ctrl + C to copy",
        iconCount = "%d errors this session · %d new", iconHint = "Click: error window · Drag: move",
        panelDesc = "Collects Lua errors, blocked addon actions and warnings, ready to copy.",
        panelOpen = "Open the error window (/ezerr)",
        cleared = "All saved errors were cleared.",
        notice = "Error [%s] %s  (type /ezerr to view)", noticeMore = " · %d more meanwhile",
        testError = "EzWoW - Error Catcher test error.",
    },
    deDE = {
        subtitle = "%d Fehler in dieser Sitzung · %d gespeichert",
        empty = "Keine Fehler.",
        stack = "Aufrufliste", locals = "Variablen",
        kind_error = "Lua-Fehler", kind_blocked = "Aktion blockiert", kind_warning = "Warnung",
        selectAll = "Alles markieren (kopieren)", remove = "Entfernen",
        opt_onlyEzWoW = "Nur EzWoW-Addons", opt_showOlder = "Frühere Sitzungen",
        opt_chatNotice = "Chathinweis", opt_showIcon = "Symbol zeigen",
        clearAll = "Alles löschen", test = "Testfehler erzeugen",
        language = "Sprache", donate = "Spenden · Link kopieren", copy = "Spendenlink · Strg + C zum Kopieren",
        iconCount = "%d Fehler in dieser Sitzung · %d neu", iconHint = "Klick: Fehlerfenster · Ziehen: bewegen",
        panelDesc = "Sammelt Lua-Fehler, blockierte Addon-Aktionen und Warnungen zum Kopieren.",
        panelOpen = "Fehlerfenster öffnen (/ezerr)",
        cleared = "Alle gespeicherten Fehler wurden gelöscht.",
        notice = "Fehler [%s] %s  (/ezerr zum Anzeigen)", noticeMore = " · %d weitere",
        testError = "Testfehler von EzWoW - Error Catcher.",
    },
    frFR = {
        subtitle = "%d erreurs cette session · %d enregistrées",
        empty = "Aucune erreur.",
        stack = "Pile d'appels", locals = "Variables",
        kind_error = "Erreur Lua", kind_blocked = "Action bloquée", kind_warning = "Avertissement",
        selectAll = "Tout sélectionner (copier)", remove = "Supprimer",
        opt_onlyEzWoW = "Addons EzWoW seulement", opt_showOlder = "Sessions précédentes",
        opt_chatNotice = "Avis dans le chat", opt_showIcon = "Afficher l'icône",
        clearAll = "Tout effacer", test = "Créer une erreur test",
        language = "Langue", donate = "Faire un don · Copier", copy = "Lien de don · Ctrl + C pour copier",
        iconCount = "%d erreurs cette session · %d nouvelles", iconHint = "Clic : fenêtre · Glisser : déplacer",
        panelDesc = "Rassemble les erreurs Lua, actions bloquées et avertissements, prêts à copier.",
        panelOpen = "Ouvrir la fenêtre des erreurs (/ezerr)",
        cleared = "Toutes les erreurs enregistrées ont été effacées.",
        notice = "Erreur [%s] %s  (/ezerr pour voir)", noticeMore = " · %d de plus",
        testError = "Erreur de test d'EzWoW - Error Catcher.",
    },
    esES = {
        subtitle = "%d errores en esta sesión · %d guardados",
        empty = "No hay errores.",
        stack = "Pila de llamadas", locals = "Variables",
        kind_error = "Error de Lua", kind_blocked = "Acción bloqueada", kind_warning = "Aviso",
        selectAll = "Seleccionar todo (copiar)", remove = "Quitar",
        opt_onlyEzWoW = "Solo addons EzWoW", opt_showOlder = "Sesiones anteriores",
        opt_chatNotice = "Aviso en el chat", opt_showIcon = "Mostrar icono",
        clearAll = "Borrar todo", test = "Crear error de prueba",
        language = "Idioma", donate = "Donar · Copiar enlace", copy = "Enlace de donación · Ctrl + C para copiar",
        iconCount = "%d errores en esta sesión · %d nuevos", iconHint = "Clic: ventana · Arrastrar: mover",
        panelDesc = "Reúne errores de Lua, acciones bloqueadas y avisos, listos para copiar.",
        panelOpen = "Abrir la ventana de errores (/ezerr)",
        cleared = "Se borraron todos los errores guardados.",
        notice = "Error [%s] %s  (escribe /ezerr para verlo)", noticeMore = " · %d más",
        testError = "Error de prueba de EzWoW - Error Catcher.",
    },
    ruRU = {
        subtitle = "Ошибок за сеанс: %d · сохранено: %d",
        empty = "Ошибок нет.",
        stack = "Стек вызовов", locals = "Переменные",
        kind_error = "Ошибка Lua", kind_blocked = "Действие заблокировано", kind_warning = "Предупреждение",
        selectAll = "Выделить всё (копировать)", remove = "Удалить",
        opt_onlyEzWoW = "Только аддоны EzWoW", opt_showOlder = "Прошлые сеансы",
        opt_chatNotice = "Сообщение в чат", opt_showIcon = "Показывать значок",
        clearAll = "Очистить всё", test = "Создать тестовую ошибку",
        language = "Язык", donate = "Поддержать · Ссылка", copy = "Ссылка · Ctrl + C для копирования",
        iconCount = "Ошибок за сеанс: %d · новых: %d", iconHint = "Клик: окно ошибок · Перетаскивание: переместить",
        panelDesc = "Собирает ошибки Lua, заблокированные действия и предупреждения для копирования.",
        panelOpen = "Открыть окно ошибок (/ezerr)",
        cleared = "Все сохранённые ошибки удалены.",
        notice = "Ошибка [%s] %s  (/ezerr — посмотреть)", noticeMore = " · ещё %d",
        testError = "Тестовая ошибка EzWoW - Error Catcher.",
    },
    zhCN = {
        subtitle = "本次登录 %d 个错误 · 已保存 %d 个",
        empty = "没有错误。",
        stack = "调用堆栈", locals = "变量值",
        kind_error = "Lua 错误", kind_blocked = "动作被阻止", kind_warning = "警告",
        selectAll = "全选（复制）", remove = "删除此错误",
        opt_onlyEzWoW = "只看 EzWoW 插件", opt_showOlder = "包括以前的登录",
        opt_chatNotice = "聊天框提示", opt_showIcon = "显示图标",
        clearAll = "全部清除", test = "生成测试错误",
        language = "语言", donate = "赞助 · 复制链接", copy = "赞助链接 · Ctrl + C 复制",
        iconCount = "本次登录 %d 个错误 · 新错误 %d 个", iconHint = "点击：错误窗口 · 拖动：移动",
        panelDesc = "收集 Lua 错误、被阻止的插件动作和警告，方便复制。",
        panelOpen = "打开错误窗口 (/ezerr)",
        cleared = "已清除所有保存的错误。",
        notice = "错误 [%s] %s（输入 /ezerr 查看）", noticeMore = " · 期间另有 %d 个",
        testError = "EzWoW - Error Catcher 测试错误。",
    },
    zhTW = {
        subtitle = "本次登入 %d 個錯誤 · 已儲存 %d 個",
        empty = "沒有錯誤。",
        stack = "呼叫堆疊", locals = "變數值",
        kind_error = "Lua 錯誤", kind_blocked = "動作被阻止", kind_warning = "警告",
        selectAll = "全選（複製）", remove = "刪除此錯誤",
        opt_onlyEzWoW = "只看 EzWoW 插件", opt_showOlder = "包括以前的登入",
        opt_chatNotice = "聊天框提示", opt_showIcon = "顯示圖示",
        clearAll = "全部清除", test = "產生測試錯誤",
        language = "語言", donate = "贊助 · 複製連結", copy = "贊助連結 · Ctrl + C 複製",
        iconCount = "本次登入 %d 個錯誤 · 新錯誤 %d 個", iconHint = "點擊：錯誤視窗 · 拖曳：移動",
        panelDesc = "收集 Lua 錯誤、被阻止的插件動作和警告，方便複製。",
        panelOpen = "開啟錯誤視窗 (/ezerr)",
        cleared = "已清除所有儲存的錯誤。",
        notice = "錯誤 [%s] %s（輸入 /ezerr 查看）", noticeMore = " · 期間另有 %d 個",
        testError = "EzWoW - Error Catcher 測試錯誤。",
    },
}

function ns:GetActiveLang()
    local lang = (self.db and self.db.language) or "auto"
    if lang == "auto" then
        lang = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    end
    if lang == "esMX" then lang = "esES" end
    if lang == "enGB" then lang = "enUS" end
    return UI_STRINGS[lang] and lang or "enUS"
end

function ns:L(key)
    local tbl = UI_STRINGS[self:GetActiveLang()] or UI_STRINGS.enUS
    return tbl[key] or UI_STRINGS.enUS[key] or key
end

function ns:GetLanguageDisplayLabel()
    local pref = (self.db and self.db.language) or "auto"
    for _, item in ipairs(self.LANGUAGE_OPTIONS) do
        if item[1] == pref then return item[2] end
    end
    return "Auto"
end
