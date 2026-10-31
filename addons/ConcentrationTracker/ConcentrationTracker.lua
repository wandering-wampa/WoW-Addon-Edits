local addonName, ns = ...
ns = ns or {}
ns.searchText = ns.searchText or ""

function ns.GetSearchText()
    local q = ns.searchText
    if type(q) ~= "string" then
        return ""
    end
    return (q:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.EntryPassesSearchFilter(charName, professionName, realm)
    local q = ns.GetSearchText():lower()
    if q == "" then
        return true
    end
    charName = tostring(charName or ""):lower()
    professionName = tostring(professionName or ""):lower()
    realm = tostring(realm or ""):lower()
    return charName:find(q, 1, true) ~= nil
        or professionName:find(q, 1, true) ~= nil
        or realm:find(q, 1, true) ~= nil
end

-- Тижневі квести професій Midnight (тренер / збір / крафт), якщо тег API порожній.
ns.KNOWN_PROFESSION_WEEKLY = {
    [93692] = true, [93694] = true,
    [93700] = true, [93702] = true, [93703] = true, [93704] = true,
    [93705] = true, [93706] = true, [93707] = true, [93708] = true, [93709] = true,
}
ns.PROFESSION_QUEST_TAG_ID = 267

function ns.IsQuestReadyForTurnIn(questID, info)
    questID = tonumber(questID)
    if not questID then
        return false
    end
    if C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then
        return true
    end
    if C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
        return true
    end
    return info and info.isComplete == true
end

function ns.IsProfessionWeeklyQuest(info, tag)
    if type(info) ~= "table" or info.isHeader or not info.questID then
        return false
    end
    local questID = tonumber(info.questID)
    if not questID then
        return false
    end
    tag = tag or (C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID))
    local hasProfession = type(tag) == "table"
        and (tonumber(tag.tradeskillLineID) or tag.tagID == ns.PROFESSION_QUEST_TAG_ID)
    if ns.KNOWN_PROFESSION_WEEKLY[questID] then
        hasProfession = true
    end
    if not hasProfession then
        return false
    end
    local weekly = Enum and Enum.QuestFrequency
    local freq = info.frequency
    if weekly then
        if freq == weekly.Weekly or freq == weekly.ResetByScheduler then
            return true
        end
    end
    if C_QuestLog and C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
        return true
    end
    return ns.KNOWN_PROFESSION_WEEKLY[questID] == true
end

function ns.CollectReadyProfessionWeeklies()
    local list = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return list
    end
    local num = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, num do
        local info = C_QuestLog.GetInfo(i)
        if type(info) == "table" and info.questID and not info.isHeader then
            local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(info.questID)
            if ns.IsProfessionWeeklyQuest(info, tag) and ns.IsQuestReadyForTurnIn(info.questID, info) then
                local title = info.title
                if (not title or title == "") and C_QuestLog.GetTitleForQuestID then
                    title = C_QuestLog.GetTitleForQuestID(info.questID)
                end
                local professionName
                local skillLineID = tag and tonumber(tag.tradeskillLineID)
                if skillLineID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                    local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
                    if pinfo then
                        professionName = pinfo.professionName
                    end
                end
                list[#list + 1] = {
                    questID = info.questID,
                    title = title or ("Quest " .. tostring(info.questID)),
                    professionName = professionName,
                    skillLineID = skillLineID,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.title or "") < (b.title or "")
    end)
    return list
end

-- ===========================================================
-- 1. ОГОЛОШЕННЯ ЗМІННИХ ТА СТВОРЕННЯ ФРЕЙМА ДЛЯ ПОДІЙ
-- ===========================================================
local frame = CreateFrame("Frame")

-- Реєструємо основні події для завантаження та збереження аддона
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Події вікна професії: запис при відкритті, зміні джерела даних і після крафту (не при CLOSE — API може бути недійсним, зайві помилки в чаті)
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
frame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_TURNED_IN")

-- Глобальні (або локальні) змінні збереження:
--   ConcentrationTrackerDB, ConcentrationTrackerSettings
-- Не ініціалізуємо тут, лише оголошуємо; ініціалізація буде після ADDON_LOADED

-- Текстові рядки (локалізація) завантажуватимемо згодом
local L = {}

local function LOr(key, english)
    return (L and L[key]) or english
end

-- Отримуємо шрифт, який підтримує поточну мову клієнта
local function GetLocaleFont()
    local loc = GetLocale()
    if loc == "koKR" then
        return "Fonts\\2002B.TTF"
    end
    if loc == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    end
    if loc == "zhTW" then
        return "Fonts\\ARKai_TC.ttf"
    end
    return "Fonts\\ARIALN.TTF"
end
local ADDON_FONT = (GameFontHighlight and select(1, GameFontHighlight:GetFont())) or GetLocaleFont()

-- Запасна межа, якщо з API немає maxQuantity (у retail зазвичай 1000)
local MAX_CONCENTRATION = 1000

-- Artisan's Moxie (Midnight): окрема валюта на професію, IDs 3256–3266 (Wowhead).
-- Порядок currency ID: Alchemy…Tailor за назвою валюти; ключі — Enum.Profession.
local MOXIE_NOTIFY_THRESHOLD = 600
local MOXIE_CURRENCY_MIN = 3256
local MOXIE_CURRENCY_MAX = 3266
-- Enum.Profession → Artisan * Moxie currency ID
local MOXIE_CURRENCY_BY_PROFESSION = {
    [1] = 3257,  -- Blacksmithing → Artisan Blacksmith's Moxie
    [2] = 3263,  -- Leatherworking → Artisan Leatherworker's Moxie
    [3] = 3256,  -- Alchemy → Artisan Alchemist's Moxie
    [4] = 3260,  -- Herbalism → Artisan Herbalist's Moxie
    [6] = 3264,  -- Mining → Artisan Miner's Moxie
    [7] = 3266,  -- Tailoring → Artisan Tailor's Moxie
    [8] = 3259,  -- Engineering → Artisan Engineer's Moxie
    [9] = 3258,  -- Enchanting → Artisan Enchanter's Moxie
    [11] = 3265, -- Skinning → Artisan Skinner's Moxie
    [12] = 3262, -- Jewelcrafting → Artisan Jewelcrafter's Moxie
    [13] = 3261, -- Inscription → Artisan Scribe's Moxie
}

-- Enum.Profession → іконка (fallback, якщо API не повертає texture)
local PROFESSION_ICON_BY_ENUM = {
    [1] = "Interface\\Icons\\Trade_BlackSmithing",
    [2] = "Interface\\Icons\\Trade_LeatherWorking",
    [3] = "Interface\\Icons\\Trade_Alchemy",
    [4] = "Interface\\Icons\\Trade_Herbalism",
    [6] = "Interface\\Icons\\Trade_Mining",
    [7] = "Interface\\Icons\\Trade_Tailoring",
    [8] = "Interface\\Icons\\Trade_Engineering",
    [9] = "Interface\\Icons\\Trade_Engraving",
    [11] = "Interface\\Icons\\Trade_Skinning",
    [12] = "Interface\\Icons\\Inv_Misc_Gem_01",
    [13] = "Interface\\Icons\\Inv_Inscription_Tradeskill01",
}

local MOXIE_ONLY_KEY_PREFIX = "m"

-- Префікси назв ліній навичок (найдовші спочатку). expansionName з API часто "Unknown".
local EXPANSION_NAME_PREFIXES = {
    "Khaz Algar",
    "Khaz'Algar",
    "Battle for Azeroth",
    "Wrath of the Lich King",
    "Warlords of Draenor",
    "Mists of Pandaria",
    "Dragon Isles",
    "Shadowlands",
    "Burning Crusade",
    "Midnight",
    "Legion",
    "Cataclysm",
    "Classic",
}

local EXPANSION_DISPLAY_ORDER = {
    "Midnight",
    "Khaz Algar",
    "Dragon Isles",
    "Shadowlands",
    "Battle for Azeroth",
    "Legion",
    "Warlords of Draenor",
    "Mists of Pandaria",
    "Cataclysm",
    "Wrath of the Lich King",
    "Burning Crusade",
    "Classic",
    "Other",
}

local function NormalizeExpansionKey(name)
    if not name or name == "" then
        return nil
    end
    if name == "Khaz'Algar" or name == "The War Within" then
        return "Khaz Algar"
    end
    return name
end

local function GetExpansionKeyFromProfessionName(professionName)
    if type(professionName) ~= "string" or professionName == "" then
        return nil
    end
    for _, prefix in ipairs(EXPANSION_NAME_PREFIXES) do
        if professionName:sub(1, #prefix) == prefix then
            local nextCh = professionName:sub(#prefix + 1, #prefix + 1)
            if nextCh == "" or nextCh == " " then
                return NormalizeExpansionKey(prefix)
            end
        end
    end
    return nil
end

local function GetExpansionKeyForSkillLine(skillLineID, professionName)
    skillLineID = tonumber(skillLineID)
    if skillLineID and type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if pinfo and pinfo.expansionName and pinfo.expansionName ~= "" and pinfo.expansionName ~= "Unknown" then
            return NormalizeExpansionKey(pinfo.expansionName)
        end
    end
    if type(GetProfessionInfo) == "function" and skillLineID then
        local n = GetNumProfessionSkills and GetNumProfessionSkills() or 0
        for i = 1, math.max(n, 12) do
            local profName, _, _, _, _, _, skillLine, _, _, _, skillLineName = GetProfessionInfo(i)
            if not profName then
                break
            end
            if skillLine == skillLineID and skillLineName and skillLineName ~= "" then
                local fromName = GetExpansionKeyFromProfessionName(skillLineName)
                if fromName then
                    return fromName
                end
            end
        end
    end
    return GetExpansionKeyFromProfessionName(professionName)
end

local function GetExpansionKeyForEntry(data, skillLineID)
    if type(data) ~= "table" then
        return "Other"
    end
    if data.expansionKey and data.expansionKey ~= "" then
        return data.expansionKey
    end
    skillLineID = tonumber(skillLineID) or tonumber(data.entrySkillLine or data.professionID)
    local key = GetExpansionKeyForSkillLine(skillLineID, data.professionName)
    if key then
        return key
    end
    local moxieCID = tonumber(data.moxieCurrencyID)
    if data.moxieOnly or (moxieCID and IsMoxieCurrencyID(moxieCID)) then
        return "Midnight"
    end
    return "Other"
end

local function EntryPassesExpansionFilter(data, skillLineID)
    if not ConcentrationTrackerSettings then
        return true
    end
    local filter = ConcentrationTrackerSettings.selectedExpansion or "All"
    if filter == "All" then
        return true
    end
    return GetExpansionKeyForEntry(data, skillLineID) == filter
end

local function CollectExpansionFilterOptions()
    local seen = {}
    local list = { "All" }
    seen.All = true
    for _, exp in ipairs(EXPANSION_DISPLAY_ORDER) do
        if exp ~= "Other" then
            seen[exp] = true
            list[#list + 1] = exp
        end
    end
    if ConcentrationTrackerDB then
        for _, data in pairs(ConcentrationTrackerDB) do
            if type(data) == "table" then
                local sid = tonumber(data.entrySkillLine or data.professionID)
                local exp = GetExpansionKeyForEntry(data, sid)
                if exp and not seen[exp] then
                    seen[exp] = true
                    list[#list + 1] = exp
                end
            end
        end
    end
    return list
end

local function SanitizeSelectedExpansionFilter()
    if not ConcentrationTrackerSettings then
        return
    end
    local selected = ConcentrationTrackerSettings.selectedExpansion or "All"
    if selected == "All" then
        return
    end
    for _, exp in ipairs(CollectExpansionFilterOptions()) do
        if exp == selected then
            return
        end
    end
    ConcentrationTrackerSettings.selectedExpansion = "All"
end

local function GetExpansionDropdownLabel(expansionKey)
    if not expansionKey or expansionKey == "All" then
        return (L and L["all_expansions"]) or "All expansions"
    end
    return expansionKey
end

local function InitializeExpansionDropdown(dropdown, onSelect)
    if not dropdown then
        return
    end
    SanitizeSelectedExpansionFilter()
    UIDropDownMenu_Initialize(dropdown, function()
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(self)
            ConcentrationTrackerSettings.selectedExpansion = self.value
            UIDropDownMenu_SetSelectedValue(dropdown, self.value)
            UIDropDownMenu_SetText(dropdown, GetExpansionDropdownLabel(self.value))
            if onSelect then
                onSelect()
            end
        end
        info.text = GetExpansionDropdownLabel("All")
        info.value = "All"
        info.checked = (ConcentrationTrackerSettings.selectedExpansion or "All") == "All"
        UIDropDownMenu_AddButton(info)
        for _, exp in ipairs(CollectExpansionFilterOptions()) do
            if exp ~= "All" then
                info.text = exp
                info.value = exp
                info.checked = (ConcentrationTrackerSettings.selectedExpansion or "All") == exp
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    UIDropDownMenu_SetText(dropdown, GetExpansionDropdownLabel(ConcentrationTrackerSettings.selectedExpansion or "All"))
    UIDropDownMenu_SetSelectedValue(dropdown, ConcentrationTrackerSettings.selectedExpansion or "All")
end

local function BackfillExpansionKeys()
    if not ConcentrationTrackerDB then
        return
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            data.expansionKey = GetExpansionKeyForEntry(data, sid)
        end
    end
end

--- Збережені дані можуть не мати maxQuantity (старий формат); tonumber відсікає рядки/сміття.
local function GetEffectiveMaxQuantity(storedMax)
    local m = tonumber(storedMax)
    if m and m >= 1 then
        return m
    end
    return MAX_CONCENTRATION
end

-- Швидкість відновлення: GetRestoreRate() (налаштовується, дефолт 10/год)

-- Константи для логів та таймерів
local ADDON_TAG = "[ConcentrationTracker] "
local UI_UPDATE_INTERVAL = 2 -- секунд між оновленнями таймерів у вікні
local MOXIE_POLL_INTERVAL = 8 -- опитування Moxie без відкриття вікна професії
local STALE_DATA_SECONDS = 24 * 60 * 60 -- підказка «застарілі дані», якщо lastUpdate старший за добу

-- Локальні посилання на вікна (не засмічуємо _G)
local ConcentrationWindow, LanguageSettingsWindow
local ldbObject -- LibDataBroker data object (якщо є)
-- Локалізація: Locales.lua
local LANGUAGES = ns.LANGUAGES
local GetLanguageDisplayName = ns.GetLanguageDisplayName
local LoadLocalization = ns.LoadLocalization
local loadedLocaleLang = nil

--- Кешує результат LoadLocalization; перезавантажує лише при зміні мови.
local function EnsureLocalization(forceLang)
    local lang = forceLang
        or (ConcentrationTrackerSettings and ConcentrationTrackerSettings.language)
        or "en"
    if type(lang) ~= "string" or lang == "" then
        lang = "en"
    end
    if L and loadedLocaleLang == lang and L["addon_name"] then
        return L
    end
    L = LoadLocalization(lang)
    loadedLocaleLang = lang
    return L
end

--- Оновлюється в ADDON_LOADED з метаданих TOC (Version).
local ADDON_VERSION = "?"

local DEFAULT_SETTINGS = {
    transparency = 1,
    language = "en",
    sortOrder = "character",
    sortAscending = true,
    selectedProfession = "All",
    selectedExpansion = "All",
    selectedCharacter = "All",
    showRealm = false,
    hideFullConcentration = false,
    hideStaleRows = false,
    hideMoxieOnlyRows = false,
    showConcentrationPercent = false,
    compactTimeFormat = false,
    highlightFullRows = true,
    autoFilterThisCharacter = false,
    refreshOnOpen = false,
    highlightLowRows = false,
    highlightSoonRows = false,
    highlightThisCharacter = true,
    lockWindow = false,
    hideInCombat = false,
    fontSize = 12,
    windowScale = 1,
    enableNotifications = true,
    hideFloatingButton = false,
    logUpdatesToChat = false,
    restoreRatePerHour = 10,
    notificationRaidWarning = true,
    notificationChat = false,
    notificationSound = true,
    showMoxie = true,
    notifyMoxieAt600 = true,
    notifyWeeklyTurnIn = true,
    showColCharacter = true,
    showColProfession = true,
    showColMoxie = true,
    showColConcentration = true,
    showColTimeToFull = true,
    showColRestoresAt = true,
}

local function GetDefaultSettings()
    return {
        transparency = DEFAULT_SETTINGS.transparency,
        language = DEFAULT_SETTINGS.language,
        sortOrder = DEFAULT_SETTINGS.sortOrder,
        sortAscending = DEFAULT_SETTINGS.sortAscending,
        selectedProfession = DEFAULT_SETTINGS.selectedProfession,
        selectedExpansion = DEFAULT_SETTINGS.selectedExpansion,
        selectedCharacter = DEFAULT_SETTINGS.selectedCharacter,
        showRealm = DEFAULT_SETTINGS.showRealm,
        hideFullConcentration = DEFAULT_SETTINGS.hideFullConcentration,
        hideStaleRows = DEFAULT_SETTINGS.hideStaleRows,
        hideMoxieOnlyRows = DEFAULT_SETTINGS.hideMoxieOnlyRows,
        showConcentrationPercent = DEFAULT_SETTINGS.showConcentrationPercent,
        compactTimeFormat = DEFAULT_SETTINGS.compactTimeFormat,
        highlightFullRows = DEFAULT_SETTINGS.highlightFullRows,
        autoFilterThisCharacter = DEFAULT_SETTINGS.autoFilterThisCharacter,
        refreshOnOpen = DEFAULT_SETTINGS.refreshOnOpen,
        highlightLowRows = DEFAULT_SETTINGS.highlightLowRows,
        highlightSoonRows = DEFAULT_SETTINGS.highlightSoonRows,
        highlightThisCharacter = DEFAULT_SETTINGS.highlightThisCharacter,
        lockWindow = DEFAULT_SETTINGS.lockWindow,
        hideInCombat = DEFAULT_SETTINGS.hideInCombat,
        fontSize = DEFAULT_SETTINGS.fontSize,
        windowScale = DEFAULT_SETTINGS.windowScale,
        enableNotifications = DEFAULT_SETTINGS.enableNotifications,
        hideFloatingButton = DEFAULT_SETTINGS.hideFloatingButton,
        logUpdatesToChat = DEFAULT_SETTINGS.logUpdatesToChat,
        restoreRatePerHour = DEFAULT_SETTINGS.restoreRatePerHour,
        notificationRaidWarning = DEFAULT_SETTINGS.notificationRaidWarning,
        notificationChat = DEFAULT_SETTINGS.notificationChat,
        notificationSound = DEFAULT_SETTINGS.notificationSound,
        showMoxie = DEFAULT_SETTINGS.showMoxie,
        notifyMoxieAt600 = DEFAULT_SETTINGS.notifyMoxieAt600,
        notifyWeeklyTurnIn = DEFAULT_SETTINGS.notifyWeeklyTurnIn,
        showColCharacter = DEFAULT_SETTINGS.showColCharacter,
        showColProfession = DEFAULT_SETTINGS.showColProfession,
        showColMoxie = DEFAULT_SETTINGS.showColMoxie,
        showColConcentration = DEFAULT_SETTINGS.showColConcentration,
        showColTimeToFull = DEFAULT_SETTINGS.showColTimeToFull,
        showColRestoresAt = DEFAULT_SETTINGS.showColRestoresAt,
        ignoredSkillLines = {},
        minimap = { hide = false, minimapPos = 220 },
    }
end

local function EnsureMinimapSettings()
    if not ConcentrationTrackerSettings then
        return
    end
    if not ConcentrationTrackerSettings.minimap then
        ConcentrationTrackerSettings.minimap = { hide = false, minimapPos = 220 }
    end
    if ConcentrationTrackerSettings.minimap.hide == nil then
        ConcentrationTrackerSettings.minimap.hide = false
    end
    if ConcentrationTrackerSettings.minimap.minimapPos == nil then
        ConcentrationTrackerSettings.minimap.minimapPos = 220
    end
end

local function IsSupportedLanguage(code)
    if type(code) ~= "string" then
        return false
    end
    for _, lang in ipairs(LANGUAGES) do
        if lang.value == code then
            return true
        end
    end
    return false
end

--- Заповнює відсутні ключі з дефолтів і обмежує числові поля (пошкоджені SavedVariables).
local function SanitizeSettings()
    if not ConcentrationTrackerSettings then
        return
    end
    local defaults = GetDefaultSettings()
    for k, v in pairs(defaults) do
        if ConcentrationTrackerSettings[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for sk, sv in pairs(v) do
                    copy[sk] = sv
                end
                ConcentrationTrackerSettings[k] = copy
            else
                ConcentrationTrackerSettings[k] = v
            end
        end
    end
    if not IsSupportedLanguage(ConcentrationTrackerSettings.language) then
        ConcentrationTrackerSettings.language = DEFAULT_SETTINGS.language
    end
    local fs = tonumber(ConcentrationTrackerSettings.fontSize)
    if not fs then
        ConcentrationTrackerSettings.fontSize = DEFAULT_SETTINGS.fontSize
    else
        ConcentrationTrackerSettings.fontSize = math.max(10, math.min(18, math.floor(fs + 0.5)))
    end
    local ws = tonumber(ConcentrationTrackerSettings.windowScale)
    if not ws or ws < 0.5 or ws > 1.5 then
        ConcentrationTrackerSettings.windowScale = DEFAULT_SETTINGS.windowScale
    end
    ConcentrationTrackerSettings.transparency = 1
    local tr = tonumber(ConcentrationTrackerSettings.transparency)
    if not tr then
        ConcentrationTrackerSettings.transparency = DEFAULT_SETTINGS.transparency
    else
        -- Старий дефолт 0.5 → 0.8
        if tr == 0.5 then
            tr = DEFAULT_SETTINGS.transparency
        end
        ConcentrationTrackerSettings.transparency = math.max(0, math.min(1, tr))
    end
    local rate = tonumber(ConcentrationTrackerSettings.restoreRatePerHour)
    if not rate or rate < 0.1 then
        ConcentrationTrackerSettings.restoreRatePerHour = DEFAULT_SETTINGS.restoreRatePerHour
    else
        ConcentrationTrackerSettings.restoreRatePerHour = math.min(rate, 100)
    end
    if type(ConcentrationTrackerSettings.ignoredSkillLines) ~= "table" then
        ConcentrationTrackerSettings.ignoredSkillLines = {}
    end
    EnsureMinimapSettings()
end

local function CancelAddonTimers()
    if frame.worldSyncTimer then
        frame.worldSyncTimer:Cancel()
        frame.worldSyncTimer = nil
    end
    if frame.loginSyncTimer then
        frame.loginSyncTimer:Cancel()
        frame.loginSyncTimer = nil
    end
    if frame.worldEnterTimer then
        frame.worldEnterTimer:Cancel()
        frame.worldEnterTimer = nil
    end
    if frame.notificationTicker then
        frame.notificationTicker:Cancel()
        frame.notificationTicker = nil
    end
    if frame.moxiePollTicker then
        frame.moxiePollTicker:Cancel()
        frame.moxiePollTicker = nil
    end
end

-- Ключ запису: \031 не трапляється в іменах персонажа/реалму (Retail)
local DB_KEY_SEP = "\031"

local function MakeStorageKey(charName, realm, skillLineID)
    return charName .. DB_KEY_SEP .. realm .. DB_KEY_SEP .. tostring(skillLineID)
end

local function MakeMoxieOnlyStorageKey(charName, realm, moxieCurrencyID)
    return MakeStorageKey(charName, realm, MOXIE_ONLY_KEY_PREFIX .. tostring(moxieCurrencyID))
end

local function EntryHasConcentration(data)
    return type(data) == "table" and data.lastUpdate and data.quantity ~= nil and not data.moxieOnly
end

local function GetEntryIdentity(key, data)
    if data and data.entryChar and data.entryRealm then
        local sid = tonumber(data.entrySkillLine) or tonumber(data.professionID)
        if sid then
            return data.entryChar, data.entryRealm, sid
        end
        if data.entryChar and data.entryRealm then
            return data.entryChar, data.entryRealm, nil
        end
    end
    if type(key) == "string" and key:find(DB_KEY_SEP, 1, true) then
        local a, b, c = strsplit(DB_KEY_SEP, key)
        if c and c:sub(1, #MOXIE_ONLY_KEY_PREFIX) == MOXIE_ONLY_KEY_PREFIX then
            return a, b, nil
        end
        return a, b, tonumber(c)
    end
    if not key or type(key) ~= "string" then
        return nil, nil, nil
    end
    local sid = key:match("_([0-9]+)$")
    if not sid then
        return nil, nil, nil
    end
    local skillLineID = tonumber(sid)
    local rest = key:sub(1, #key - #sid - 1)
    local charName, realm = strsplit("_", rest, 2)
    realm = realm or ""
    if not charName or charName == "" then
        return nil, nil, nil
    end
    return charName, realm, skillLineID
end

local function IsCurrentPlayerEntry(charName, realm)
    local playerCn = UnitName("player")
    if not playerCn or playerCn == "" or charName ~= playerCn then
        return false
    end
    local playerRm = GetRealmName() or "Unknown"
    realm = realm or ""
    return realm == "" or realm == playerRm
end

local function MigrateConcentrationDB()
    if not ConcentrationTrackerDB then
        return
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(key) == "string" and type(data) == "table" then
            local cn, rm, sid = GetEntryIdentity(key, data)
            if cn and rm and sid then
                data.entryChar = cn
                data.entryRealm = rm
                data.entrySkillLine = sid
                if not key:find(DB_KEY_SEP, 1, true) then
                    local newKey = MakeStorageKey(cn, rm, sid)
                    if newKey ~= key then
                        local existing = ConcentrationTrackerDB[newKey]
                        if not existing then
                            ConcentrationTrackerDB[newKey] = data
                            ConcentrationTrackerDB[key] = nil
                        else
                            if (data.lastUpdate or 0) > (existing.lastUpdate or 0) then
                                for k, v in pairs(data) do
                                    existing[k] = v
                                end
                            end
                            ConcentrationTrackerDB[key] = nil
                        end
                    end
                end
            end
        end
    end
end

-- Швидкий пошук ігнорованих ліній навичок (та сама SavedVariables — лише кеш у пам’яті)
local ignoredSkillLineSet = {}

local function RebuildIgnoredSkillLineSet()
    wipe(ignoredSkillLineSet)
    if not ConcentrationTrackerSettings or type(ConcentrationTrackerSettings.ignoredSkillLines) ~= "table" then
        return
    end
    for _, v in ipairs(ConcentrationTrackerSettings.ignoredSkillLines) do
        local id = tonumber(v)
        if id then
            ignoredSkillLineSet[id] = true
        end
    end
end

local function EnsureIgnoredSkillLinesTable()
    if not ConcentrationTrackerSettings then return end
    if type(ConcentrationTrackerSettings.ignoredSkillLines) ~= "table" then
        ConcentrationTrackerSettings.ignoredSkillLines = {}
        RebuildIgnoredSkillLineSet()
    end
end

local function IsSkillLineIgnored(skillLineID)
    EnsureIgnoredSkillLinesTable()
    local id = tonumber(skillLineID)
    if not id then return false end
    return ignoredSkillLineSet[id] == true
end

local function AddIgnoredSkillLine(skillLineID)
    EnsureIgnoredSkillLinesTable()
    local id = tonumber(skillLineID)
    if not id or ignoredSkillLineSet[id] then return end
    table.insert(ConcentrationTrackerSettings.ignoredSkillLines, id)
    ignoredSkillLineSet[id] = true
end

local function ClearAllIgnoredSkillLines()
    EnsureIgnoredSkillLinesTable()
    wipe(ConcentrationTrackerSettings.ignoredSkillLines)
    wipe(ignoredSkillLineSet)
end

local function IgnoredSkillLineCount()
    EnsureIgnoredSkillLinesTable()
    return #ConcentrationTrackerSettings.ignoredSkillLines
end

local function GetRestoreRate()
    if not ConcentrationTrackerSettings then
        return 10
    end
    local r = tonumber(ConcentrationTrackerSettings.restoreRatePerHour)
    if not r or r < 0.1 then
        return 10
    end
    return math.min(r, 100)
end

local function FormatDurationHoursMinutes(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%d %s %d %s", hours, LOr("hour", "h"), minutes, LOr("minute", "m"))
end

--- Формат «час до повного»: повний (з секундами) або компактний.
local function FormatTimeToFullString(remainingSeconds)
    local hourStr = LOr("hour", "h")
    local minStr = LOr("minute", "m")
    local secStr = LOr("second", "s")
    remainingSeconds = math.max(0, tonumber(remainingSeconds) or 0)
    local hours = math.floor(remainingSeconds / 3600)
    local minutes = math.floor((remainingSeconds % 3600) / 60)
    local seconds = math.floor(remainingSeconds % 60)
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.compactTimeFormat then
        return string.format("%d %s %d %s", hours, hourStr, minutes, minStr)
    end
    return string.format("%d %s %d %s %d %s", hours, hourStr, minutes, minStr, seconds, secStr)
end

local function FormatConcentrationAmount(quantity, maxQuantity)
    local maxQ = GetEffectiveMaxQuantity(maxQuantity)
    local q = tonumber(quantity) or 0
    local text = string.format("%.0f/%d", q, maxQ)
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showConcentrationPercent then
        local pct = 0
        if maxQ > 0 then
            pct = math.floor((q / maxQ) * 100 + 0.5)
        end
        text = text .. string.format(" · %d%%", pct)
    end
    return text
end

local function MakeCharacterFilterKey(charName, realm)
    if not charName or charName == "" then
        return nil
    end
    return tostring(charName) .. DB_KEY_SEP .. tostring(realm or "Unknown")
end

local function GetCurrentPlayerFilterKey()
    local cn = UnitName("player")
    if not cn or cn == "" then
        return nil
    end
    return MakeCharacterFilterKey(cn, GetRealmName() or "Unknown")
end

--- Колір заповнення концентрації (низький / середній / високий).
local function GetConcentrationFillColor(percentage)
    percentage = tonumber(percentage) or 0
    if percentage < 30 then
        return 0.95, 0.4, 0.4
    elseif percentage < 70 then
        return 0.95, 0.78, 0.25
    end
    return 0.35, 0.85, 0.4
end

local function FormatCharacterFilterLabel(charName, realm)
    if not charName then
        return "?"
    end
    if realm and realm ~= "" and realm ~= "Unknown" then
        return charName .. "-" .. realm
    end
    return charName
end

local function EntryPassesCharacterFilter(charName, realm)
    if not ConcentrationTrackerSettings then
        return true
    end
    local selected = ConcentrationTrackerSettings.selectedCharacter
    if not selected or selected == "All" then
        return true
    end
    return MakeCharacterFilterKey(charName, realm) == selected
end

local function IsDataStale(lastUpdate)
    local ts = tonumber(lastUpdate)
    if not ts or ts <= 0 then
        return true
    end
    local age = time() - ts
    if age < 0 then
        return false
    end
    return age >= STALE_DATA_SECONDS
end

local function FormatDataAgeShort(lastUpdate)
    local ts = tonumber(lastUpdate)
    if not ts or ts <= 0 then
        return LOr("data_age_unknown", "unknown")
    end
    local age = math.max(0, time() - ts)
    if age < 3600 then
        local mins = math.max(1, math.floor(age / 60))
        return string.format(LOr("data_age_minutes", "%d min ago"), mins)
    end
    if age < STALE_DATA_SECONDS then
        local hours = math.floor(age / 3600)
        return string.format(LOr("data_age_hours", "%d h ago"), hours)
    end
    local days = math.floor(age / STALE_DATA_SECONDS)
    return string.format(LOr("data_age_days", "%d d ago"), math.max(1, days))
end

local function MarkLayoutDirty()
    if ConcentrationWindow then
        ConcentrationWindow.layoutDirty = true
    end
end

local function ApplyMinimapButtonVisibility()
    local btn = _G.ConcentrationTrackerMinimapButton
    if not btn or not ConcentrationTrackerSettings then
        return
    end
    EnsureMinimapSettings()
    if ConcentrationTrackerSettings.minimap.hide then
        btn:Hide()
    else
        btn:Show()
    end
end

-- ===========================================================
-- 3. РОБОТА З ДАНИМИ (КОНЦЕНТРАЦІЯ)
-- ===========================================================
local CheckConcentrationNotifications -- forward declaration (defined below)
local RefreshProfessionDropdown
local RefreshCharacterDropdown
local RefreshExpansionDropdowns
local ApplyCurrencyUpdateToRow
local AfterConcentrationDataChanged
local InitializeProfessionDropdown
local InitializeCharacterDropdown
local UpdateConcentrationTimes
local GetCurrentPlayerProfessionCache -- used by ResolveSkillLineIDFromOpenProfession before definition

local function IsMoxieCurrencyID(currencyID)
    currencyID = tonumber(currencyID)
    return currencyID and currencyID >= MOXIE_CURRENCY_MIN and currencyID <= MOXIE_CURRENCY_MAX
end

local function GetProfessionEnumForMoxieCurrency(moxieCurrencyID)
    moxieCurrencyID = tonumber(moxieCurrencyID)
    if not moxieCurrencyID then
        return nil
    end
    for profEnum, cid in pairs(MOXIE_CURRENCY_BY_PROFESSION) do
        if cid == moxieCurrencyID then
            return profEnum
        end
    end
    return nil
end

--- Enum.Profession for a skill line, parent line, or stored profession ID.
local function GetProfessionEnumForSkillLine(skillLineID)
    skillLineID = tonumber(skillLineID)
    if not skillLineID then
        return nil
    end
    local baseEnums = {[164]=1,[165]=2,[171]=3,[182]=4,[186]=6,[197]=7,
        [202]=8,[333]=9,[393]=11,[755]=12,[773]=13}
    if baseEnums[skillLineID] then return baseEnums[skillLineID] end
    if MOXIE_CURRENCY_BY_PROFESSION[skillLineID] then
        return skillLineID
    end
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if pinfo and pinfo.profession then
            return pinfo.profession
        end
    end
    return nil
end

--- Child skill line from the open profession window (not parent professionID).
local function ResolveSkillLineIDFromOpenProfession(professionInfo)
    if type(professionInfo) ~= "table" then
        return nil
    end
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function" then
        local childLine = tonumber(C_TradeSkillUI.GetProfessionChildSkillLineID())
        if childLine then
            return childLine
        end
    end
    local profEnum = professionInfo.profession
    if profEnum then
        for skillLine in pairs(GetCurrentPlayerProfessionCache().skillLines) do
            if GetProfessionEnumForSkillLine(skillLine) == profEnum then
                return skillLine
            end
        end
    end
    return tonumber(professionInfo.professionID)
end

local function GetMoxieCurrencyIDForSkillLine(skillLineID)
    skillLineID = tonumber(skillLineID)
    if not skillLineID then
        return nil
    end
    if type(C_TradeSkillUI) == "table" then
        if type(C_TradeSkillUI.GetArtisanMoxieCurrencyID) == "function" then
            local id = tonumber(C_TradeSkillUI.GetArtisanMoxieCurrencyID(skillLineID))
            if id then
                return id
            end
        end
        if type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
            local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
            if pinfo and pinfo.profession then
                return MOXIE_CURRENCY_BY_PROFESSION[pinfo.profession]
            end
        end
    end
    return nil
end

local function GetEntryMoxieCurrencyID(data, skillLineID)
    if type(data) ~= "table" then
        return nil
    end
    skillLineID = tonumber(skillLineID) or tonumber(data.entrySkillLine or data.professionID)
    local fromSkillLine = skillLineID and GetMoxieCurrencyIDForSkillLine(skillLineID)
    if fromSkillLine then
        return fromSkillLine
    end
    return tonumber(data.moxieCurrencyID)
end

local function ReconcileRowMoxieCurrency(data, skillLineID)
    if type(data) ~= "table" then
        return false
    end
    skillLineID = tonumber(skillLineID) or tonumber(data.entrySkillLine or data.professionID)
    if not skillLineID then
        return false
    end
    local expected = GetMoxieCurrencyIDForSkillLine(skillLineID)
    if not expected then
        return false
    end
    local stored = tonumber(data.moxieCurrencyID)
    if stored == expected then
        return false
    end
    -- Currency ID змінився (напр. виправлення мапи професій) — скинути кількість,
    -- щоб не показувати чужу Moxie; актуальне значення підтягнеться з API.
    data.moxieCurrencyID = expected
    data.moxieQuantity = nil
    return true
end

--- Пройтись по всьому SavedVariables і виправити застарілі moxieCurrencyID.
local function ReconcileAllStoredMoxieCurrencies()
    if not ConcentrationTrackerDB then
        return false
    end
    local changed = false
    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            if ReconcileRowMoxieCurrency(data, sid) then
                changed = true
            end
        end
    end
    return changed
end

local playerProfessionSkillLineCache

local function InvalidatePlayerProfessionCache()
    playerProfessionSkillLineCache = nil
end

GetCurrentPlayerProfessionCache = function()
    if playerProfessionSkillLineCache then
        return playerProfessionSkillLineCache
    end
    local skillLines = {}
    local professionEnums = {}
    local moxieCurrencies = {}
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local p1, p2 = GetProfessions()
        for _, profIndex in ipairs({ p1, p2 }) do
            if profIndex then
                local _, _, _, _, _, _, skillLine = GetProfessionInfo(profIndex)
                skillLine = tonumber(skillLine)
                if skillLine then
                    skillLines[skillLine] = true
                    local enum = GetProfessionEnumForSkillLine(skillLine)
                    if enum then
                        professionEnums[enum] = true
                    end
                    local moxieCID = GetMoxieCurrencyIDForSkillLine(skillLine)
                    if moxieCID then
                        moxieCurrencies[moxieCID] = true
                    end
                end
            end
        end
    end
    playerProfessionSkillLineCache = {
        skillLines = skillLines,
        professionEnums = professionEnums,
        moxieCurrencies = moxieCurrencies,
    }
    return playerProfessionSkillLineCache
end

--- Лінії навичок професій поточного персонажа (2 основні).
local function GetCurrentPlayerProfessionSkillLineSet()
    return GetCurrentPlayerProfessionCache().skillLines
end

local function HasKnownActiveProfessionsForCurrentPlayer()
    for _ in pairs(GetCurrentPlayerProfessionCache().skillLines) do
        return true
    end
    return false
end

local function IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
    if not IsCurrentPlayerEntry(charName, realm) then
        return true
    end
    skillLineID = tonumber(skillLineID)
    if not skillLineID then
        return true
    end
    if not HasKnownActiveProfessionsForCurrentPlayer() then
        return true
    end
    local cache = GetCurrentPlayerProfessionCache()
    if cache.skillLines[skillLineID] then
        return true
    end
    local rowEnum = GetProfessionEnumForSkillLine(skillLineID)
    if not rowEnum then
        return true
    end
    return cache.professionEnums[rowEnum] == true
end

--- Чи рядок проходить ті самі фільтри, що й головна таблиця (для прогнозу тощо).
local function EntryPassesMainTableFilters(key, data)
    if type(data) ~= "table" or not ConcentrationTrackerSettings then
        return false
    end
    local charName, realm, skillLineID = GetEntryIdentity(key, data)
    if not charName then
        return false
    end
    local professionName = data.professionName
    if ConcentrationTrackerSettings.selectedProfession ~= "All"
        and ConcentrationTrackerSettings.selectedProfession ~= professionName then
        return false
    end
    if not EntryPassesCharacterFilter(charName, realm) then
        return false
    end
    if not EntryPassesExpansionFilter(data, skillLineID) then
        return false
    end
    if IsSkillLineIgnored(skillLineID) then
        return false
    end
    if not IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
        return false
    end
    if not ns.EntryPassesSearchFilter(charName, professionName, realm) then
        return false
    end
    return true
end

local function GetCurrentPlayerMoxieCurrencySet()
    return GetCurrentPlayerProfessionCache().moxieCurrencies
end

--- Чи враховувати рядок у LDB-підсумку та сповіщеннях про повну концентрацію.
local function EntryEligibleForConcentrationNotify(key, data)
    if not EntryHasConcentration(data) then
        return false
    end
    local charName, realm, skillLineID = GetEntryIdentity(key, data)
    if skillLineID and IsSkillLineIgnored(skillLineID) then
        return false
    end
    if not IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
        return false
    end
    return true
end

--- Чи варто зберігати/показувати Moxie (лише активні професії поточного персонажа).
local function ShouldTrackMoxieForCharacter(charName, realm, moxieCurrencyID, moxieQuantity, skillLineID)
    moxieCurrencyID = tonumber(moxieCurrencyID)
    if not moxieCurrencyID then
        return false
    end
    skillLineID = tonumber(skillLineID)

    if IsCurrentPlayerEntry(charName, realm) then
        local cache = GetCurrentPlayerProfessionCache()
        local activeMoxie = GetCurrentPlayerMoxieCurrencySet()
        if activeMoxie[moxieCurrencyID] then
            return true
        end
        if skillLineID then
            if cache.skillLines[skillLineID] then
                return true
            end
            local rowEnum = GetProfessionEnumForSkillLine(skillLineID)
            if rowEnum and cache.professionEnums[rowEnum] then
                return true
            end
        end
        local profEnum = GetProfessionEnumForMoxieCurrency(moxieCurrencyID)
        if profEnum and cache.professionEnums[profEnum] then
            return true
        end
        return false
    end

    -- Інші персонажі: збережений знімок (оновлюється при їхньому вході в гру).
    moxieQuantity = tonumber(moxieQuantity) or 0
    if moxieQuantity > 0 then
        return true
    end
    return skillLineID ~= nil
end

local function PurgeAbandonedProfessionMoxieForCurrentPlayer()
    if not ConcentrationTrackerDB then
        return false
    end
    local cn = UnitName("player")
    if not cn or cn == "" then
        return false
    end
    local rm = GetRealmName() or "Unknown"
    local changed = false
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and IsCurrentPlayerEntry(data.entryChar, data.entryRealm) then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            if ReconcileRowMoxieCurrency(data, sid) then
                changed = true
            end
            local cid = GetEntryMoxieCurrencyID(data, sid)
            local mq = tonumber(data.moxieQuantity) or 0
            if sid and not IsCurrentPlayerActiveProfessionRow(data.entryChar, data.entryRealm, sid) then
                if data.moxieOnly then
                    ConcentrationTrackerDB[key] = nil
                    changed = true
                elseif data.moxieQuantity ~= nil or data.moxieCurrencyID ~= nil then
                    data.moxieQuantity = nil
                    data.moxieCurrencyID = nil
                    data.notifiedAtMoxie600 = nil
                    changed = true
                end
            elseif cid and not ShouldTrackMoxieForCharacter(cn, rm, cid, mq, sid) then
                if data.moxieOnly then
                    ConcentrationTrackerDB[key] = nil
                    changed = true
                elseif data.moxieQuantity ~= nil or data.moxieCurrencyID ~= nil then
                    data.moxieQuantity = nil
                    data.moxieCurrencyID = nil
                    data.notifiedAtMoxie600 = nil
                    changed = true
                end
            end
        end
    end
    return changed
end

local function DeleteMoxieOnlyStorageRow(charName, realm, moxieCurrencyID, skillLineID)
    if not ConcentrationTrackerDB then
        return false
    end
    local removed = false
    skillLineID = tonumber(skillLineID)
    moxieCurrencyID = tonumber(moxieCurrencyID)
    if skillLineID then
        local key = MakeStorageKey(charName, realm, skillLineID)
        local row = ConcentrationTrackerDB[key]
        if type(row) == "table" and row.moxieOnly then
            ConcentrationTrackerDB[key] = nil
            removed = true
        end
    end
    if moxieCurrencyID then
        local key = MakeMoxieOnlyStorageKey(charName, realm, moxieCurrencyID)
        if ConcentrationTrackerDB[key] then
            ConcentrationTrackerDB[key] = nil
            removed = true
        end
    end
    return removed
end

local function FindConcentrationRowForMoxieCurrency(charName, realm, moxieCurrencyID)
    moxieCurrencyID = tonumber(moxieCurrencyID)
    if not moxieCurrencyID or not ConcentrationTrackerDB then
        return nil, nil
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.entryChar == charName and data.entryRealm == realm and EntryHasConcentration(data) then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            if sid and GetMoxieCurrencyIDForSkillLine(sid) == moxieCurrencyID then
                return key, data
            end
        end
    end
    return nil, nil
end

local function PurgeDuplicateMoxieOnlyRows()
    if not ConcentrationTrackerDB then
        return
    end
    local toDelete = {}
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.moxieOnly and data.entryChar and data.entryRealm then
            local moxieCID = tonumber(data.moxieCurrencyID)
            if not moxieCID and type(key) == "string" and key:find(DB_KEY_SEP, 1, true) then
                local _, _, third = strsplit(DB_KEY_SEP, key)
                if third and third:sub(1, #MOXIE_ONLY_KEY_PREFIX) == MOXIE_ONLY_KEY_PREFIX then
                    moxieCID = tonumber(third:sub(#MOXIE_ONLY_KEY_PREFIX + 1))
                end
            end
            if moxieCID and FindConcentrationRowForMoxieCurrency(data.entryChar, data.entryRealm, moxieCID) then
                toDelete[#toDelete + 1] = key
            end
        end
    end
    for _, key in ipairs(toDelete) do
        ConcentrationTrackerDB[key] = nil
    end
end

local function PurgeStaleMoxieOnlyRows()
    if not ConcentrationTrackerDB then
        return false
    end
    local toDelete = {}
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.moxieOnly and data.entryChar and data.entryRealm then
            local moxieCID = tonumber(data.moxieCurrencyID)
            if not moxieCID and type(key) == "string" and key:find(DB_KEY_SEP, 1, true) then
                local _, _, third = strsplit(DB_KEY_SEP, key)
                if third and third:sub(1, #MOXIE_ONLY_KEY_PREFIX) == MOXIE_ONLY_KEY_PREFIX then
                    moxieCID = tonumber(third:sub(#MOXIE_ONLY_KEY_PREFIX + 1))
                end
            end
            local sid = tonumber(data.entrySkillLine or data.professionID)
            local mq = tonumber(data.moxieQuantity) or 0
            if not ShouldTrackMoxieForCharacter(data.entryChar, data.entryRealm, moxieCID, mq, sid) then
                toDelete[#toDelete + 1] = key
            end
        end
    end
    for _, key in ipairs(toDelete) do
        ConcentrationTrackerDB[key] = nil
    end
    return #toDelete > 0
end

--- Іконка професії: skill line API → enum за Moxie → іконка валюти.
local function ResolveProfessionIconTexture(skillLineID, moxieCurrencyID)
    skillLineID = tonumber(skillLineID)
    moxieCurrencyID = tonumber(moxieCurrencyID)

    if skillLineID and type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if pinfo and pinfo.profession and PROFESSION_ICON_BY_ENUM[pinfo.profession] then
            return PROFESSION_ICON_BY_ENUM[pinfo.profession]
        end
        local parentID = pinfo and tonumber(pinfo.professionID)
        if parentID and parentID ~= skillLineID then
            local parentInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(parentID)
            if parentInfo and parentInfo.profession and PROFESSION_ICON_BY_ENUM[parentInfo.profession] then
                return PROFESSION_ICON_BY_ENUM[parentInfo.profession]
            end
        end
    end

    if skillLineID and C_Professions and type(C_Professions.GetProfessionInfoForSkillLine) == "function" then
        local ok, info = pcall(C_Professions.GetProfessionInfoForSkillLine, skillLineID)
        if ok and info then
            if info.icon then
                return info.icon
            end
            if info.profession and PROFESSION_ICON_BY_ENUM[info.profession] then
                return PROFESSION_ICON_BY_ENUM[info.profession]
            end
        end
    end

    if not moxieCurrencyID and skillLineID then
        moxieCurrencyID = GetMoxieCurrencyIDForSkillLine(skillLineID)
    end

    local profEnum = GetProfessionEnumForMoxieCurrency(moxieCurrencyID)
    if profEnum and PROFESSION_ICON_BY_ENUM[profEnum] then
        return PROFESSION_ICON_BY_ENUM[profEnum]
    end

    if moxieCurrencyID and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local cinfo = C_CurrencyInfo.GetCurrencyInfo(moxieCurrencyID)
        if cinfo and cinfo.iconFileID and cinfo.iconFileID > 0 then
            return cinfo.iconFileID
        end
    end

    return nil
end

local function ApplyRowProfessionIcon(row, entry)
    if not row.profIcon then
        return
    end
    local tex = ResolveProfessionIconTexture(entry.professionID, entry.moxieCurrencyID)
    if tex then
        row.profIcon:SetTexture(tex)
        row.profIcon:Show()
    else
        row.profIcon:Hide()
    end
end

local function GetMoxieQuantityForEntry(data, skillLineID)
    if not data then
        return nil
    end
    skillLineID = tonumber(skillLineID) or tonumber(data.entrySkillLine or data.professionID)
    ReconcileRowMoxieCurrency(data, skillLineID)
    local cid = GetEntryMoxieCurrencyID(data, skillLineID)
    if not cid then
        return nil
    end
    local cn, rm = data.entryChar, data.entryRealm
    if IsCurrentPlayerEntry(cn, rm) and not ShouldTrackMoxieForCharacter(cn, rm, cid, data.moxieQuantity or 0, skillLineID) then
        return nil
    end
    local playerCn = UnitName("player")
    local playerRm = GetRealmName() or "Unknown"
    if cn == playerCn and rm == playerRm and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local info = C_CurrencyInfo.GetCurrencyInfo(cid)
        if info and info.quantity ~= nil then
            local q = tonumber(info.quantity) or 0
            data.moxieCurrencyID = cid
            data.moxieQuantity = q
            return q
        end
    end
    local stored = tonumber(data.moxieQuantity)
    if stored ~= nil then
        data.moxieCurrencyID = cid
        return stored
    end
    return nil
end

local function EnsureMoxieNotifiedTable()
    if not ConcentrationTrackerSettings then
        return
    end
    if type(ConcentrationTrackerSettings.moxieNotifiedAt600) ~= "table" then
        ConcentrationTrackerSettings.moxieNotifiedAt600 = {}
    end
    if type(ConcentrationTrackerSettings.moxieLastQuantity) ~= "table" then
        ConcentrationTrackerSettings.moxieLastQuantity = {}
    end
end

local function MoxieNotifySettingsKey(charName, realm, currencyID)
    return charName .. DB_KEY_SEP .. realm .. DB_KEY_SEP .. tostring(currencyID)
end

local function GetProfessionLabelForMoxieCurrency(moxieCurrencyID, fallbackName)
    if type(fallbackName) == "string" and fallbackName ~= "" then
        return fallbackName
    end
    moxieCurrencyID = tonumber(moxieCurrencyID)
    if moxieCurrencyID and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local info = C_CurrencyInfo.GetCurrencyInfo(moxieCurrencyID)
        if info and info.name and info.name ~= "" then
            return info.name
        end
    end
    return fallbackName or (L and L["profession"]) or "Profession"
end

--- Запис або оновлення рядка без концентрації (лише Moxie). Повертає true, якщо дані змінились.
local function UpsertMoxieOnlyRow(charName, realm, skillLineID, professionName, moxieCurrencyID, moxieQuantity)
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return false
    end
    moxieCurrencyID = tonumber(moxieCurrencyID)
    moxieQuantity = tonumber(moxieQuantity)
    if not moxieCurrencyID or moxieQuantity == nil or not IsMoxieCurrencyID(moxieCurrencyID) then
        return false
    end
    skillLineID = tonumber(skillLineID)
    if skillLineID and IsSkillLineIgnored(skillLineID) then
        return false
    end

    if not ShouldTrackMoxieForCharacter(charName, realm, moxieCurrencyID, moxieQuantity, skillLineID) then
        return DeleteMoxieOnlyStorageRow(charName, realm, moxieCurrencyID, skillLineID)
    end

    local key
    if skillLineID then
        key = MakeStorageKey(charName, realm, skillLineID)
    else
        key = MakeMoxieOnlyStorageKey(charName, realm, moxieCurrencyID)
    end

    local concKey, concRow = FindConcentrationRowForMoxieCurrency(charName, realm, moxieCurrencyID)
    if concRow then
        local sid = tonumber(concRow.entrySkillLine or concRow.professionID)
        if IsCurrentPlayerEntry(charName, realm) and sid and not IsCurrentPlayerActiveProfessionRow(charName, realm, sid) then
            concKey, concRow = nil, nil
        end
    end
    if concRow then
        local changed = (tonumber(concRow.moxieQuantity) or -1) ~= moxieQuantity
            or tonumber(concRow.moxieCurrencyID) ~= moxieCurrencyID
        concRow.moxieCurrencyID = moxieCurrencyID
        concRow.moxieQuantity = moxieQuantity
        concRow.moxieOnly = nil
        concRow.expansionKey = GetExpansionKeyForSkillLine(
            tonumber(concRow.entrySkillLine or concRow.professionID),
            professionName or concRow.professionName
        ) or "Midnight"
        if professionName and professionName ~= "" then
            concRow.professionName = professionName
        end
        if key ~= concKey and type(ConcentrationTrackerDB[key]) == "table" and ConcentrationTrackerDB[key].moxieOnly then
            ConcentrationTrackerDB[key] = nil
        end
        return changed
    end

    local row = ConcentrationTrackerDB[key]
    if type(row) ~= "table" then
        row = {}
        ConcentrationTrackerDB[key] = row
    end

    if EntryHasConcentration(row) then
        local changed = (tonumber(row.moxieQuantity) or -1) ~= moxieQuantity
            or tonumber(row.moxieCurrencyID) ~= moxieCurrencyID
        row.moxieCurrencyID = moxieCurrencyID
        row.moxieQuantity = moxieQuantity
        if professionName and professionName ~= "" then
            row.professionName = professionName
        end
        return changed
    end

    local label = professionName
    if not label or label == "" then
        label = row.professionName
    end
    label = GetProfessionLabelForMoxieCurrency(moxieCurrencyID, label)

    local changed = row.moxieOnly ~= true
        or row.moxieCurrencyID ~= moxieCurrencyID
        or (tonumber(row.moxieQuantity) or -1) ~= moxieQuantity
        or row.professionName ~= label
        or row.entryChar ~= charName
        or row.entryRealm ~= realm

    row.moxieOnly = true
    row.entryChar = charName
    row.entryRealm = realm
    if skillLineID then
        row.entrySkillLine = skillLineID
        row.professionID = skillLineID
    end
    row.professionName = label
    row.expansionKey = GetExpansionKeyForSkillLine(skillLineID, label)
    if row.moxieOnly or IsMoxieCurrencyID(moxieCurrencyID) then
        row.expansionKey = row.expansionKey or "Midnight"
    end
    row.moxieCurrencyID = moxieCurrencyID
    row.moxieQuantity = moxieQuantity
    row.currencyID = nil
    row.quantity = nil
    row.maxQuantity = nil
    row.lastUpdate = nil
    row.notifiedAtFull = nil

    if moxieQuantity >= MOXIE_NOTIFY_THRESHOLD then
        row.notifiedAtMoxie600 = true
        EnsureMoxieNotifiedTable()
        ConcentrationTrackerSettings.moxieNotifiedAt600[MoxieNotifySettingsKey(charName, realm, moxieCurrencyID)] = true
    end
    EnsureMoxieNotifiedTable()
    ConcentrationTrackerSettings.moxieLastQuantity[MoxieNotifySettingsKey(charName, realm, moxieCurrencyID)] = moxieQuantity

    return changed
end

local function DeliverNotification(message)
    if not ConcentrationTrackerSettings or not ConcentrationTrackerSettings.enableNotifications then
        return
    end
    if ConcentrationTrackerSettings.notificationRaidWarning ~= false then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    end
    if ConcentrationTrackerSettings.notificationChat then
        print(ADDON_TAG .. message)
    end
    if ConcentrationTrackerSettings.notificationSound ~= false then
        PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
    end
end

local function MarkMoxieNotified(charName, realm, currencyID, rowData, quantity)
    if rowData then
        rowData.notifiedAtMoxie600 = true
        rowData.moxieCurrencyID = currencyID
        rowData.moxieQuantity = quantity
    end
    EnsureMoxieNotifiedTable()
    ConcentrationTrackerSettings.moxieNotifiedAt600[MoxieNotifySettingsKey(charName, realm, currencyID)] = true
end

local function TryMoxieNotification(charName, professionName, currencyID, quantity, rowData)
    if not ConcentrationTrackerSettings then
        return
    end
    quantity = tonumber(quantity) or 0
    currencyID = tonumber(currencyID)
    if not currencyID or not IsMoxieCurrencyID(currencyID) then
        return
    end
    local rm = GetRealmName() or "Unknown"
    EnsureMoxieNotifiedTable()
    local skey = MoxieNotifySettingsKey(charName, rm, currencyID)

    local prevQ = ConcentrationTrackerSettings.moxieLastQuantity[skey]
    if prevQ == nil and rowData and rowData.moxieQuantity ~= nil then
        prevQ = tonumber(rowData.moxieQuantity)
    end
    prevQ = prevQ and tonumber(prevQ) or nil

    if quantity < MOXIE_NOTIFY_THRESHOLD then
        if rowData then
            rowData.notifiedAtMoxie600 = nil
            rowData.moxieCurrencyID = currencyID
            rowData.moxieQuantity = quantity
        end
        ConcentrationTrackerSettings.moxieNotifiedAt600[skey] = nil
        ConcentrationTrackerSettings.moxieLastQuantity[skey] = quantity
        return
    end

    local alreadyNotified = (rowData and rowData.notifiedAtMoxie600) or ConcentrationTrackerSettings.moxieNotifiedAt600[skey]
    local crossedThreshold = (prevQ == nil or prevQ < MOXIE_NOTIFY_THRESHOLD)

    if rowData then
        rowData.moxieCurrencyID = currencyID
        rowData.moxieQuantity = quantity
    end
    ConcentrationTrackerSettings.moxieLastQuantity[skey] = quantity

    if alreadyNotified or not crossedThreshold then
        if alreadyNotified or quantity >= MOXIE_NOTIFY_THRESHOLD then
            MarkMoxieNotified(charName, rm, currencyID, rowData, quantity)
        end
        return
    end

    if not ConcentrationTrackerSettings.enableNotifications
        or ConcentrationTrackerSettings.notifyMoxieAt600 == false then
        MarkMoxieNotified(charName, rm, currencyID, rowData, quantity)
        return
    end

    if not L or not L["notification_moxie_message"] then
        EnsureLocalization()
    end
    local msg = string.format(
        L["notification_moxie_message"] or "%s (%s): Reached %d Moxie!",
        charName or "?",
        professionName or "?",
        MOXIE_NOTIFY_THRESHOLD
    )
    MarkMoxieNotified(charName, rm, currencyID, rowData, quantity)
    DeliverNotification(msg)
end

local function SyncMoxieFromCurrencyDisplay(currencyID)
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    if not IsMoxieCurrencyID(currencyID) or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return
    end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or info.quantity == nil then
        return
    end
    local q = tonumber(info.quantity) or 0
    local cn = UnitName("player")
    if not cn or cn == "" then
        return
    end
    local rm = GetRealmName() or "Unknown"
    local label = info.name or "?"
    local matchedRow = false
    local changed = false

    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.entryChar == cn and data.entryRealm == rm then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            ReconcileRowMoxieCurrency(data, sid)
            local rowCurrency = sid and GetMoxieCurrencyIDForSkillLine(sid) or tonumber(data.moxieCurrencyID)
            if rowCurrency == currencyID then
                if ShouldTrackMoxieForCharacter(cn, rm, currencyID, q, sid) then
                    matchedRow = true
                    local prevQ = tonumber(data.moxieQuantity)
                    TryMoxieNotification(cn, data.professionName or label, currencyID, q, data)
                    if prevQ ~= q then
                        data.moxieCurrencyID = currencyID
                        data.moxieQuantity = q
                        changed = true
                    end
                elseif data.moxieOnly then
                    ConcentrationTrackerDB[key] = nil
                    changed = true
                elseif data.moxieQuantity ~= nil or data.moxieCurrencyID ~= nil then
                    data.moxieQuantity = nil
                    data.moxieCurrencyID = nil
                    data.notifiedAtMoxie600 = nil
                    changed = true
                end
            end
        end
    end

    if not matchedRow then
        if ShouldTrackMoxieForCharacter(cn, rm, currencyID, q, nil) then
            TryMoxieNotification(cn, label, currencyID, q, nil)
            if UpsertMoxieOnlyRow(cn, rm, nil, label, currencyID, q) then
                changed = true
            end
        else
            if DeleteMoxieOnlyStorageRow(cn, rm, currencyID, nil) then
                changed = true
            end
        end
    end

    return changed
end

local function CollectMoxieCurrencyIDsForCurrentPlayer()
    local ids = {}
    for cid in pairs(GetCurrentPlayerMoxieCurrencySet()) do
        ids[cid] = true
    end
    local cn = UnitName("player")
    local rm = GetRealmName() or "Unknown"
    if ConcentrationTrackerDB and cn then
        local activeSkillLines = GetCurrentPlayerProfessionSkillLineSet()
        for _, data in pairs(ConcentrationTrackerDB) do
            if type(data) == "table" and data.entryChar == cn and data.entryRealm == rm and EntryHasConcentration(data) then
                local sid = tonumber(data.entrySkillLine or data.professionID)
                if sid and activeSkillLines[sid] then
                    local cid = GetMoxieCurrencyIDForSkillLine(sid)
                    if cid then
                        ids[cid] = true
                    end
                end
            end
        end
    end
    return ids
end

local function RefreshCurrentCharacterMoxieFromAPI()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    if type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return
    end
    if PurgeAbandonedProfessionMoxieForCurrentPlayer() then
        AfterConcentrationDataChanged()
    end
    local changed = false
    for id in pairs(CollectMoxieCurrencyIDsForCurrentPlayer()) do
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info and info.quantity ~= nil then
            if SyncMoxieFromCurrencyDisplay(id) then
                changed = true
            end
        end
    end
    if PurgeStaleMoxieOnlyRows() then
        changed = true
    end
    if changed then
        PurgeDuplicateMoxieOnlyRows()
        AfterConcentrationDataChanged()
    end
end

local function RecordConcentration()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        print(ADDON_TAG .. "Database or settings not initialized yet.")
        return
    end
    EnsureLocalization()
    if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetChildProfessionInfo) ~= "function" then
        return
    end
    local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
    if not professionInfo or not professionInfo.professionID then
        print(ADDON_TAG .. (L["error_profession_info_unavailable"] or "Profession info unavailable."))
        return
    end
    if type(C_TradeSkillUI.GetConcentrationCurrencyID) ~= "function" then
        print(ADDON_TAG .. (L["msg_error_currency"] or "Concentration currency API is unavailable."))
        return
    end

    local skillLineID = ResolveSkillLineIDFromOpenProfession(professionInfo)
    local professionName = professionInfo.professionName
    if not skillLineID or IsSkillLineIgnored(skillLineID) then
        return
    end

    local charName = UnitName("player")
    if not charName or charName == "" then
        print(ADDON_TAG .. (L["error_character_name"] or "Character name error."))
        return
    end
    local _, charClass = UnitClass("player")
    local realm = GetRealmName() or "Unknown"

    local legacyKey = tonumber(professionInfo.professionID) and MakeStorageKey(charName, realm, professionInfo.professionID)
    local varId = MakeStorageKey(charName, realm, skillLineID)
    if legacyKey and legacyKey ~= varId and type(ConcentrationTrackerDB[legacyKey]) == "table" and not ConcentrationTrackerDB[varId] then
        ConcentrationTrackerDB[varId] = ConcentrationTrackerDB[legacyKey]
        ConcentrationTrackerDB[legacyKey] = nil
    end

    local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(skillLineID)
    local moxieID = GetMoxieCurrencyIDForSkillLine(skillLineID)

    if not currencyID then
        if moxieID and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
            local moxieInfo = C_CurrencyInfo.GetCurrencyInfo(moxieID)
            if moxieInfo and moxieInfo.quantity ~= nil then
                local mq = tonumber(moxieInfo.quantity) or 0
                local rowKey = MakeStorageKey(charName, realm, skillLineID)
                if UpsertMoxieOnlyRow(charName, realm, skillLineID, professionName, moxieID, mq) then
                    AfterConcentrationDataChanged()
                end
                TryMoxieNotification(charName, professionName, moxieID, mq, ConcentrationTrackerDB[rowKey])
                if ConcentrationTrackerSettings.logUpdatesToChat then
                    print(string.format(ADDON_TAG .. (L["update_moxie_message"] or "Updated Moxie: %s (%s): %d"), charName, professionName, mq))
                end
                return
            end
        end
        print(ADDON_TAG .. (L["error_currency_id"] or "Currency ID error."))
        return
    end

    local concentration = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not concentration or not concentration.quantity then return end

    local conQuantity = concentration.quantity
    local maxQuantity = GetEffectiveMaxQuantity(concentration.maxQuantity)
    if type(conQuantity) ~= "number" or conQuantity < 0 then
        print(ADDON_TAG .. (L["error_invalid_concentration"] or "Invalid concentration."))
        return
    end
    ConcentrationTrackerDB[varId] = ConcentrationTrackerDB[varId] or {}

    ConcentrationTrackerDB[varId].entryChar = charName
    ConcentrationTrackerDB[varId].entryRealm = realm
    ConcentrationTrackerDB[varId].entrySkillLine = skillLineID
    ConcentrationTrackerDB[varId].moxieOnly = nil

    if conQuantity ~= ConcentrationTrackerDB[varId].quantity or maxQuantity ~= ConcentrationTrackerDB[varId].maxQuantity then
        ConcentrationTrackerDB[varId].quantity = conQuantity
        ConcentrationTrackerDB[varId].maxQuantity = maxQuantity
        ConcentrationTrackerDB[varId].lastUpdate = time()
        ConcentrationTrackerDB[varId].charClass = charClass
        if conQuantity < maxQuantity then
            ConcentrationTrackerDB[varId].notifiedAtFull = nil
        end
        if ConcentrationTrackerSettings.logUpdatesToChat then
            print(string.format(ADDON_TAG .. (L["update_message"] or "Updated: %s (%s): %d"), charName, professionName, conQuantity))
        end
    end

    ConcentrationTrackerDB[varId].professionID = skillLineID
    ConcentrationTrackerDB[varId].professionName = professionName
    ConcentrationTrackerDB[varId].expansionKey = GetExpansionKeyForSkillLine(skillLineID, professionName)
    ConcentrationTrackerDB[varId].currencyID = currencyID

    if moxieID and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local moxieInfo = C_CurrencyInfo.GetCurrencyInfo(moxieID)
        if moxieInfo and moxieInfo.quantity ~= nil then
            local mq = tonumber(moxieInfo.quantity) or 0
            ConcentrationTrackerDB[varId].moxieCurrencyID = moxieID
            ConcentrationTrackerDB[varId].moxieQuantity = mq
            TryMoxieNotification(charName, professionName, moxieID, mq, ConcentrationTrackerDB[varId])
        end
    end

    ReconcileRowMoxieCurrency(ConcentrationTrackerDB[varId], skillLineID)

    AfterConcentrationDataChanged()
end

local function GetRestorationTimes(lastUpdate, lastKnownQuantity, maxQuantity)
    local maxQ = GetEffectiveMaxQuantity(maxQuantity)
    local lastQ = tonumber(lastKnownQuantity) or 0
    if lastQ < 0 then
        lastQ = 0
    end
    local rate = GetRestoreRate()
    local now = time()
    local lastT = tonumber(lastUpdate)
    if not lastT or lastT < 0 then
        lastT = now
    end
    if lastT > now then
        lastT = now
    end
    local elapsedTime = now - lastT
    if elapsedTime < 0 then
        elapsedTime = 0
    end
    local restoredAmount = (elapsedTime / 3600) * rate
    local totalQuantity = lastQ + restoredAmount
    local fullLabel = LOr("concentration_full", "Full")

    if totalQuantity >= maxQ then
        return maxQ, 0, fullLabel, fullLabel
    else
        local remainingAmount = maxQ - totalQuantity
        local remainingTime = (remainingAmount / rate) * 3600 -- у секундах
        local timeToFull = FormatTimeToFullString(remainingTime)
        local exactTime = date("%b %d, %I:%M %p", time() + remainingTime)
        local updatedQuantity = math.min(totalQuantity, maxQ)
        return updatedQuantity, remainingTime, timeToFull, exactTime
    end
end

local function LDBConcentrationSummary()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return 0, 0
    end
    local total, notFull = 0, 0
    for key, data in pairs(ConcentrationTrackerDB) do
        if EntryEligibleForConcentrationNotify(key, data) then
            total = total + 1
            local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
            local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
            if q < maxQ then
                notFull = notFull + 1
            end
        end
    end
    return notFull, total
end

local function UpdateLDBText()
    if not ldbObject then
        return
    end
    EnsureLocalization()
    local nf, tot = LDBConcentrationSummary()
    if tot > 0 then
        ldbObject.text = string.format(LOr("ldb_short", "%d/%d"), nf, tot)
    else
        ldbObject.text = L["addon_name"] or "Concentration Tracker"
    end
end

--- Рядки в тултіпі: концентрація та Moxie для поточного персонажа.
local function AddCurrentCharacterStatusToTooltip(tooltip)
    if not tooltip or not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local cn = UnitName("player")
    if not cn or cn == "" then
        return
    end
    local rm = GetRealmName() or "Unknown"
    local naLabel = L["no_concentration"] or "—"
    local rows = {}

    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.entryChar == cn and data.entryRealm == rm then
            local _, _, skillLineID = GetEntryIdentity(key, data)
            if skillLineID and IsSkillLineIgnored(skillLineID) then
                -- skip
            elseif not IsCurrentPlayerActiveProfessionRow(cn, rm, skillLineID) then
                -- skip
            elseif EntryHasConcentration(data) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                local pname = data.professionName or (L["profession"] or "Profession")
                local line = string.format("%s: %.0f/%d", pname, q, maxQ)
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil then
                    line = line .. "  |  " .. string.format(L["moxie_short"] or "Moxie: %d", mq)
                end
                rows[#rows + 1] = { sortKey = pname:lower(), line = line }
            elseif data.moxieOnly then
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil then
                    local pname = data.professionName or (L["profession"] or "Profession")
                    local line = string.format(
                        "%s: %s  |  %s",
                        pname,
                        naLabel,
                        string.format(L["moxie_short"] or "Moxie: %d", mq)
                    )
                    rows[#rows + 1] = { sortKey = pname:lower(), line = line }
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        return a.sortKey < b.sortKey
    end)

    local charLine = cn
    if ConcentrationTrackerSettings.showRealm then
        charLine = charLine .. "-" .. rm
    end
    tooltip:AddLine(charLine, 1, 0.82, 0)

    if #rows == 0 then
        tooltip:AddLine(L["toggle_tooltip_no_data"] or "No profession data for this character yet.", 0.65, 0.65, 0.65)
    else
        for _, row in ipairs(rows) do
            tooltip:AddLine(row.line, 1, 1, 1)
        end
    end
end

local function ShowToggleButtonTooltip(owner)
    EnsureLocalization()
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cFFFFFF00" .. (L["addon_name"] or "Concentration Tracker") .. "|r")
    AddCurrentCharacterStatusToTooltip(GameTooltip)
    GameTooltip:AddLine(L["toggle_tooltip_click"] or "Click to open the window.", 0.55, 0.55, 0.55)
    GameTooltip:Show()
end

-- Функція перевірки нотифікацій (працює навіть коли вікно закрите)
CheckConcentrationNotifications = function()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    ns.CheckWeeklyTurnInAlerts()
    if not ConcentrationTrackerSettings.enableNotifications then
        return
    end
    
    -- Завантажуємо локалізацію якщо потрібно
    if not L or not L["notification_message"] then
        EnsureLocalization()
    end
    
    for key, data in pairs(ConcentrationTrackerDB) do
        if EntryEligibleForConcentrationNotify(key, data) then
            local charName = select(1, GetEntryIdentity(key, data)) or "?"
            local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
            local updatedQuantity = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
            local professionName = data.professionName or (L and L["profession"]) or "Profession"

            if updatedQuantity >= maxQ then
                if not data.notifiedAtFull then
                    data.notifiedAtFull = true
                    local notifMessage = string.format(L["notification_message"] or "%s (%s): Full!", charName, professionName)
                    DeliverNotification(notifMessage)
                end
            else
                data.notifiedAtFull = nil
            end
        end
    end
end

local function SanitizeSelectedProfessionFilter()
    if not ConcentrationTrackerSettings or not ConcentrationTrackerDB then
        return
    end
    local selected = ConcentrationTrackerSettings.selectedProfession
    if not selected or selected == "All" then
        return
    end
    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.professionName == selected then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            if EntryPassesExpansionFilter(data, sid) then
                return
            end
        end
    end
    ConcentrationTrackerSettings.selectedProfession = "All"
end

local function SanitizeSelectedCharacterFilter()
    if not ConcentrationTrackerSettings or not ConcentrationTrackerDB then
        return
    end
    local selected = ConcentrationTrackerSettings.selectedCharacter
    if not selected or selected == "All" then
        return
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm = GetEntryIdentity(key, data)
            if charName and MakeCharacterFilterKey(charName, realm) == selected then
                return
            end
        end
    end
    ConcentrationTrackerSettings.selectedCharacter = "All"
end

local function SanitizeAllFilters()
    SanitizeSelectedExpansionFilter()
    SanitizeSelectedProfessionFilter()
    SanitizeSelectedCharacterFilter()
end

RefreshProfessionDropdown = function()
    pcall(function()
        SanitizeSelectedProfessionFilter()
        if ConcentrationWindow and ConcentrationWindow.professionDropdown and InitializeProfessionDropdown then
            UIDropDownMenu_Initialize(ConcentrationWindow.professionDropdown, InitializeProfessionDropdown)
            if UIDropDownMenu_Refresh then
                UIDropDownMenu_Refresh(ConcentrationWindow.professionDropdown, 1)
            end
            EnsureLocalization()
            if ConcentrationTrackerSettings.selectedProfession == "All" then
                UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, LOr("all_professions", "All Professions"))
            else
                UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, ConcentrationTrackerSettings.selectedProfession)
            end
            UIDropDownMenu_SetSelectedValue(ConcentrationWindow.professionDropdown, ConcentrationTrackerSettings.selectedProfession)
        end
    end)
end

RefreshCharacterDropdown = function()
    pcall(function()
        SanitizeSelectedCharacterFilter()
        if ConcentrationWindow and ConcentrationWindow.characterDropdown and InitializeCharacterDropdown then
            UIDropDownMenu_Initialize(ConcentrationWindow.characterDropdown, InitializeCharacterDropdown)
            if UIDropDownMenu_Refresh then
                UIDropDownMenu_Refresh(ConcentrationWindow.characterDropdown, 1)
            end
            EnsureLocalization()
            if ConcentrationTrackerSettings.selectedCharacter == "All" then
                UIDropDownMenu_SetText(ConcentrationWindow.characterDropdown, LOr("all_characters", "All Characters"))
            else
                local sel = ConcentrationTrackerSettings.selectedCharacter
                local cName, cRealm = strsplit(DB_KEY_SEP, sel or "")
                UIDropDownMenu_SetText(
                    ConcentrationWindow.characterDropdown,
                    FormatCharacterFilterLabel(cName, cRealm)
                )
            end
            UIDropDownMenu_SetSelectedValue(ConcentrationWindow.characterDropdown, ConcentrationTrackerSettings.selectedCharacter)
        end
    end)
end

local function OnExpansionFilterChanged()
    RefreshProfessionDropdown()
    RefreshCharacterDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if ConcentrationWindow and ConcentrationWindow.expansionDropdown then
        UIDropDownMenu_SetText(
            ConcentrationWindow.expansionDropdown,
            GetExpansionDropdownLabel(ConcentrationTrackerSettings.selectedExpansion or "All")
        )
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.expansionDropdown then
        UIDropDownMenu_SetText(
            LanguageSettingsWindow.expansionDropdown,
            GetExpansionDropdownLabel(ConcentrationTrackerSettings.selectedExpansion or "All")
        )
    end
end

RefreshExpansionDropdowns = function()
    pcall(function()
        SanitizeSelectedExpansionFilter()
        if ConcentrationWindow and ConcentrationWindow.expansionDropdown then
            InitializeExpansionDropdown(ConcentrationWindow.expansionDropdown, OnExpansionFilterChanged)
            if UIDropDownMenu_Refresh then
                UIDropDownMenu_Refresh(ConcentrationWindow.expansionDropdown, 1)
            end
        end
        if LanguageSettingsWindow and LanguageSettingsWindow.expansionDropdown then
            InitializeExpansionDropdown(LanguageSettingsWindow.expansionDropdown, OnExpansionFilterChanged)
            if UIDropDownMenu_Refresh then
                UIDropDownMenu_Refresh(LanguageSettingsWindow.expansionDropdown, 1)
            end
        end
    end)
end

--- @return boolean changed
ApplyCurrencyUpdateToRow = function(data, info, logCharName)
    if not data or not info or info.quantity == nil then
        return false
    end
    -- У Lua "0 or x" дає 0 (0 не є false), тому maxQuantity з API не можна брати через "or".
    local maxFromInfo = tonumber(info.maxQuantity)
    local maxQ = (maxFromInfo and maxFromInfo >= 1) and maxFromInfo or GetEffectiveMaxQuantity(data.maxQuantity)
    local q = tonumber(info.quantity) or 0
    if q < 0 then
        q = 0
    end
    if q ~= data.quantity or maxQ ~= tonumber(data.maxQuantity) then
        data.quantity = q
        data.maxQuantity = maxQ
        data.lastUpdate = time()
        if q < maxQ then
            data.notifiedAtFull = nil
        end
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.logUpdatesToChat then
            local prof = data.professionName or (L["profession"] or "?")
            print(string.format(ADDON_TAG .. (L["update_message"] or "Updated: %s (%s): %d"), logCharName, prof, q))
        end
        return true
    end
    return false
end

AfterConcentrationDataChanged = function()
    MarkLayoutDirty()
    CheckConcentrationNotifications()
    UpdateLDBText()
    local mainShown = ConcentrationWindow and ConcentrationWindow:IsShown()
    local settingsShown = LanguageSettingsWindow and LanguageSettingsWindow:IsShown()
    if mainShown or settingsShown then
        RefreshExpansionDropdowns()
        RefreshProfessionDropdown()
        RefreshCharacterDropdown()
    end
    if mainShown and type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
end

-- Оновлення збережених рядків поточного персонажа за подією валюти (реген без відкриття вікна професії)
local function SyncStorageFromCurrencyDisplay(currencyID)
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    currencyID = tonumber(currencyID)
    if not currencyID or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return
    end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or info.quantity == nil then
        return
    end
    local cn = UnitName("player")
    local rm = GetRealmName() or "Unknown"
    EnsureLocalization()
    local changed = false

    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local ec, er = data.entryChar, data.entryRealm
            if ec == cn and er == rm then
                local match = (tonumber(data.currencyID) == currencyID)
                if not match and not data.currencyID
                    and type(C_TradeSkillUI) == "table"
                    and type(C_TradeSkillUI.GetConcentrationCurrencyID) == "function" then
                    local sid = tonumber(data.entrySkillLine or data.professionID)
                    if sid then
                        local cid = C_TradeSkillUI.GetConcentrationCurrencyID(sid)
                        if cid and tonumber(cid) == currencyID then
                            data.currencyID = currencyID
                            match = true
                        end
                    end
                end
                if match then
                    if ApplyCurrencyUpdateToRow(data, info, cn) then
                        changed = true
                    end
                    if info and type(info.quantity) == "number" then data.lastUpdate = time() end
                end
            end
        end
    end

    if changed then
        AfterConcentrationDataChanged()
    end
end

-- Discover learned profession tiers independently of the open tradeskill UI.
-- Existing currency refresh only visited rows that had already been scanned.
local function DiscoverCurrentCharacterConcentration()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then return false end
    if not C_TradeSkillUI or not C_TradeSkillUI.GetConcentrationCurrencyID
        or not C_TradeSkillUI.GetProfessionInfoBySkillLineID
        or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return false end
    local cn, rm = UnitName("player"), GetRealmName() or "Unknown"
    if not cn or cn == "" then return false end
    InvalidatePlayerProfessionCache()
    local active = GetCurrentPlayerProfessionCache()
    local candidates = {}
    if C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        for _, sid in ipairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines() or {}) do
            candidates[sid] = true
        end
    end
    for sid in pairs(active.skillLines) do candidates[sid] = true end
    for key, data in pairs(ConcentrationTrackerDB) do
        local ec, er, sid = GetEntryIdentity(key, data)
        if ec == cn and er == rm and sid then candidates[sid] = true end
    end
    -- Currency IDs are shared definitions; quantities must always be read
    -- from the logged-in character. Seed missing tier IDs from known alts.
    local catalog = {}
    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and not data.moxieOnly and data.currencyID then
            local sid = tonumber(data.entrySkillLine or data.professionID)
            local enum
            for profession, moxie in pairs(MOXIE_CURRENCY_BY_PROFESSION) do
                if moxie == tonumber(data.moxieCurrencyID) then enum = profession; break end
            end
            if sid and enum and active.professionEnums[enum] then
                candidates[sid] = true
                catalog[sid] = data
            end
        end
    end
    ns.loginScanDiagnostics = {}
    local changed = false
    for sid in pairs(candidates) do
        if not IsSkillLineIgnored(sid) then
            local pinfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(sid)
            local key = MakeStorageKey(cn, rm, sid)
            local existing = ConcentrationTrackerDB[key]
            local known = catalog[sid]
            local learned = known or existing or (pinfo and (pinfo.skillLevel or 0) > 0)
            local currentProfession = known or (pinfo and (active.skillLines[sid]
                or active.professionEnums[pinfo.profession]
                or active.skillLines[pinfo.parentProfessionID]))
            ns.loginScanDiagnostics[#ns.loginScanDiagnostics + 1] = string.format(
                "tier %s: skill=%s, known mapping=%s, eligible=%s", sid,
                tostring(pinfo and pinfo.skillLevel), tostring(known ~= nil), tostring(not not (learned and currentProfession)))
            if learned and currentProfession then
                local cid = known and tonumber(known.currencyID) or tonumber(C_TradeSkillUI.GetConcentrationCurrencyID(sid))
                local info = cid and cid > 0 and C_CurrencyInfo.GetCurrencyInfo(cid)
                ns.loginScanDiagnostics[#ns.loginScanDiagnostics + 1] = string.format(
                    "currency %s: quantity=%s, max=%s", tostring(cid),
                    tostring(info and info.quantity), tostring(info and info.maxQuantity))
                if info and type(info.quantity) == "number" and info.quantity >= 0
                    and (tonumber(info.maxQuantity) or 0) > 0 then
                    local row = existing or {}
                    row.entryChar, row.entryRealm, row.entrySkillLine = cn, rm, sid
                    row.professionID, row.currencyID = sid, cid
                    row.professionName = (known and known.professionName) or (pinfo and pinfo.professionName) or row.professionName or info.name
                    row.expansionKey = GetExpansionKeyForSkillLine(sid, row.professionName)
                    row.charClass = select(2, UnitClass("player"))
                    row.moxieOnly = nil
                    row.quantity, row.maxQuantity, row.lastUpdate = info.quantity, info.maxQuantity, time()
                    if row.quantity < row.maxQuantity then row.notifiedAtFull = nil end
                    ConcentrationTrackerDB[key] = row
                    ReconcileRowMoxieCurrency(row, sid)
                    changed = true
                end
            end
        end
    end
    return changed
end

local function RefreshCurrentCharacterConcentrationFromAPI()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    if type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return
    end
    local cn = UnitName("player")
    local rm = GetRealmName() or "Unknown"
    EnsureLocalization()
    local changed = DiscoverCurrentCharacterConcentration()

    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and not data.moxieOnly and data.lastUpdate and data.quantity ~= nil then
            if data.entryChar == cn and data.entryRealm == rm then
                local cid = tonumber(data.currencyID)
                if not cid and type(C_TradeSkillUI) == "table"
                    and type(C_TradeSkillUI.GetConcentrationCurrencyID) == "function" then
                    local sid = tonumber(data.entrySkillLine or data.professionID)
                    if sid then
                        local resolved = C_TradeSkillUI.GetConcentrationCurrencyID(sid)
                        cid = tonumber(resolved)
                        if cid then
                            data.currencyID = cid
                        end
                    end
                end
                cid = tonumber(data.currencyID)
                if cid then
                    local info = C_CurrencyInfo.GetCurrencyInfo(cid)
                    if ApplyCurrencyUpdateToRow(data, info, cn) then
                        changed = true
                    end
                    if info and type(info.quantity) == "number" then data.lastUpdate = time() end
                end
            end
        end
    end

    if changed then
        AfterConcentrationDataChanged()
    end
end

local function ScheduleWorldSyncRefresh()
    if not ConcentrationTrackerDB then
        return
    end
    if frame.worldSyncTimer then
        frame.worldSyncTimer:Cancel()
        frame.worldSyncTimer = nil
    end
    local delays, attempt = {0.75, 1.5, 3, 5}, 0
    local function sync()
        attempt = attempt + 1
        frame.worldSyncTimer = nil
        RefreshCurrentCharacterConcentrationFromAPI()
        RefreshCurrentCharacterMoxieFromAPI()
        if delays[attempt + 1] then
            frame.worldSyncTimer = C_Timer.NewTimer(delays[attempt + 1], sync)
        end
    end
    frame.worldSyncTimer = C_Timer.NewTimer(delays[1], sync)
end

--- Оновлення з API для поточного персонажа; якщо відкрито вікно професії — додатковий збір через RecordConcentration.
local function PerformConcentrationRefresh(opts)
    opts = opts or {}
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    RefreshCurrentCharacterConcentrationFromAPI()
    RefreshCurrentCharacterMoxieFromAPI()
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetChildProfessionInfo) == "function" then
        local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
        if professionInfo and professionInfo.professionID then
            RecordConcentration()
        end
    end
    if ConcentrationWindow and ConcentrationWindow:IsShown() and type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        print(ADDON_TAG .. (L["msg_refresh_done"] or "Concentration data refreshed."))
    end
end

local function TrimSlashMsg(msg)
    if not msg then
        return ""
    end
    return (tostring(msg):match("^%s*(.-)%s*$")) or ""
end

--- Перший аргумент після /conc (ігнорує зайві слова: «refresh now» → refresh).
local function FirstSlashArg(msg)
    local s = TrimSlashMsg(msg)
    if s == "" then
        return ""
    end
    return (s:match("^(%S+)") or s):lower()
end

--- Рядки статусу поточного персонажа (чат і копіювання в поле вводу).
function ns.CollectCurrentCharacterStatusLines()
    EnsureLocalization()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return nil, nil, L["empty_state"] or "No data yet."
    end
    local cn = UnitName("player")
    if not cn or cn == "" then
        return nil, nil, L["error_character_name"] or "Unable to retrieve character name."
    end
    local rm = GetRealmName() or "Unknown"
    local naLabel = L["no_concentration"] or "—"
    local lines = {}

    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.entryChar == cn and data.entryRealm == rm then
            local _, _, skillLineID = GetEntryIdentity(key, data)
            if skillLineID and IsSkillLineIgnored(skillLineID) then
                -- skip
            elseif not IsCurrentPlayerActiveProfessionRow(cn, rm, skillLineID) then
                -- skip
            elseif EntryHasConcentration(data) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                local pname = data.professionName or (L["profession"] or "Profession")
                local line = string.format("%s: %.0f/%d", pname, q, maxQ)
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil then
                    line = line .. "  |  " .. string.format(L["moxie_short"] or "Moxie: %d", mq)
                end
                lines[#lines + 1] = { sortKey = pname:lower(), line = line }
            elseif data.moxieOnly then
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil then
                    local pname = data.professionName or (L["profession"] or "Profession")
                    lines[#lines + 1] = {
                        sortKey = pname:lower(),
                        line = string.format(
                            "%s: %s  |  %s",
                            pname,
                            naLabel,
                            string.format(L["moxie_short"] or "Moxie: %d", mq)
                        ),
                    }
                end
            end
        end
    end

    table.sort(lines, function(a, b)
        return a.sortKey < b.sortKey
    end)

    local header = cn
    if ConcentrationTrackerSettings.showRealm then
        header = header .. "-" .. rm
    end
    return header, lines, nil
end

local function PrintCurrentCharacterStatus()
    local header, lines, err = ns.CollectCurrentCharacterStatusLines()
    if err then
        print(ADDON_TAG .. err)
        return
    end
    print(ADDON_TAG .. header)
    if #lines == 0 then
        print("  " .. (L["toggle_tooltip_no_data"] or "No profession data for this character yet."))
    else
        for _, row in ipairs(lines) do
            print("  " .. row.line)
        end
    end
end

local function PrintSlashHelp()
    EnsureLocalization()
    print(ADDON_TAG .. (L["slash_help_header"] or "Commands:"))
    print("  " .. (L["slash_hint"] or "/conc — window  |  /conclanguage — settings"))
    if L["slash_toggle"] then
        print("  " .. L["slash_toggle"])
    end
    if L["slash_refresh"] then
        print("  " .. L["slash_refresh"])
    end
    print("  " .. (L["slash_status"] or "|cFFAAAAAA/conc status|r or |cFFAAAAAA/conc s|r — print this character's concentration and Moxie to chat."))
    print("  " .. (L["slash_me"] or "|cFFAAAAAA/conc me|r — open the window filtered to this character."))
    print("  " .. (L["slash_next"] or "|cFFAAAAAA/conc next|r or |cFFAAAAAA/conc n|r — show which tracked line fills next."))
    print("  " .. (L["slash_clear"] or "|cFFAAAAAA/conc clear|r — reset expansion, profession, and character filters."))
    print("  " .. (L["slash_moxie"] or "|cFFAAAAAA/conc moxie|r or |cFFAAAAAA/conc mx|r — print this character's Artisan's Moxie."))
    print("  " .. (L["slash_lowest"] or "|cFFAAAAAA/conc lowest|r or |cFFAAAAAA/conc lo|r — show the lowest concentration line."))
    print("  " .. (L["slash_stale"] or "|cFFAAAAAA/conc stale|r — list rows not synced in over 24 hours."))
    print("  " .. (L["slash_chars"] or "|cFFAAAAAA/conc chars|r — list tracked characters."))
    print("  " .. (L["slash_full"] or "|cFFAAAAAA/conc full|r — list rows already at maximum concentration."))
    print("  " .. (L["slash_soon"] or "|cFFAAAAAA/conc soon|r — list rows that fill within 2 hours (or /conc soon 4)."))
    print("  " .. (L["slash_list"] or "|cFFAAAAAA/conc list|r — print the currently visible table rows."))
    print("  " .. (L["slash_combat"] or "|cFFAAAAAA/conc combat|r — toggle hiding the window in combat."))
    print("  " .. (L["slash_search"] or "|cFFAAAAAA/conc search|r — filter the table by name (empty clears)."))
    print("  " .. (L["slash_export"] or "|cFFAAAAAA/conc export|r — copy visible rows into the chat box."))
    print("  " .. (L["slash_oldest"] or "|cFFAAAAAA/conc oldest|r — show the least recently synced row."))
    print("  " .. (L["slash_ignored"] or "|cFFAAAAAA/conc ignored|r — list ignored profession variants."))
    print("  " .. (L["slash_notify"] or "|cFFAAAAAA/conc notify|r — toggle cap / Moxie notifications."))
    print("  " .. (L["slash_weekly"] or "|cFFAAAAAA/conc weekly|r — list profession weeklies ready to turn in."))
    print("  " .. (L["slash_focus"] or "|cFFAAAAAA/conc focus|r — open the window on the next line to fill."))
    print("  " .. (L["slash_hidefull"] or "|cFFAAAAAA/conc hidefull|r — hide or show full concentration rows."))
    print("  " .. (L["slash_percent"] or "|cFFAAAAAA/conc percent|r — show or hide concentration percent."))
    print("  " .. (L["slash_compact"] or "|cFFAAAAAA/conc compact|r — toggle compact time format."))
    print("  " .. (L["slash_today"] or "|cFFAAAAAA/conc today|r — list rows that fill before daily reset."))
    print("  " .. (L["slash_totals"] or "|cFFAAAAAA/conc totals|r — print account-wide concentration and Moxie totals."))
    print("  " .. (L["slash_focuslow"] or "|cFFAAAAAA/conc focuslow|r — open the window on the lowest concentration line."))
    print("  " .. (L["slash_hidestale"] or "|cFFAAAAAA/conc hidestale|r — hide or show stale rows."))
    print("  " .. (L["slash_highlight"] or "|cFFAAAAAA/conc highlight|r — toggle soon-to-fill row highlight."))
    print("  " .. (L["slash_week"] or "|cFFAAAAAA/conc week|r — list rows that fill before weekly reset."))
    print("  " .. (L["slash_missing"] or "|cFFAAAAAA/conc missing|r — concentration still needed to reach cap."))
    print("  " .. (L["slash_moxiecap"] or "|cFFAAAAAA/conc moxiecap|r — list rows at or above a Moxie threshold."))
    print("  " .. (L["slash_spend"] or "|cFFAAAAAA/conc spend|r — list rows with concentration ready to spend."))
    print("  " .. (L["slash_prof"] or "|cFFAAAAAA/conc prof|r — list a profession across characters."))
    print("  " .. (L["slash_hidemoxie"] or "|cFFAAAAAA/conc hidemoxie|r — hide or show Moxie-only rows."))
    print("  " .. (L["slash_lowlight"] or "|cFFAAAAAA/conc lowlight|r — toggle low-concentration row highlight."))
    print("  " .. (L["slash_below"] or "|cFFAAAAAA/conc below|r — list rows under a fill percent (default 25)."))
    print("  " .. (L["slash_char"] or "|cFFAAAAAA/conc char|r — one character across professions."))
    print("  " .. (L["slash_autoself"] or "|cFFAAAAAA/conc autoself|r — auto-filter the window to this character."))
    print("  " .. (L["slash_refreshopen"] or "|cFFAAAAAA/conc refreshopen|r — sync this character when the window opens."))
    print("  " .. (L["slash_reach"] or "|cFFAAAAAA/conc reach|r — time until rows hit a concentration amount."))
    print("  " .. (L["slash_exp"] or "|cFFAAAAAA/conc exp|r — list one expansion across characters."))
    print("  " .. (L["slash_sort"] or "|cFFAAAAAA/conc sort|r — set or flip the table sort."))
    print("  " .. (L["slash_col"] or "|cFFAAAAAA/conc col|r — show or hide a table column."))
    print("  " .. (L["slash_rate"] or "|cFFAAAAAA/conc rate|r — show or set the restore rate per hour."))
    print("  " .. (L["slash_chatlog"] or "|cFFAAAAAA/conc chatlog|r — print concentration updates to chat."))
    print("  " .. (L["slash_sound"] or "|cFFAAAAAA/conc sound|r — play a sound with notifications."))
    print("  " .. (L["slash_top"] or "|cFFAAAAAA/conc top|r — highest concentration rows (default 5)."))
    print("  " .. (L["slash_avg"] or "|cFFAAAAAA/conc avg|r — average fill across tracked rows."))
    print("  " .. (L["slash_scale"] or "|cFFAAAAAA/conc scale|r — show or set window scale (50–150)."))
    print("  " .. (L["slash_font"] or "|cFFAAAAAA/conc font|r — show or set font size (10–18)."))
    print("  " .. (L["slash_showmoxie"] or "|cFFAAAAAA/conc showmoxie|r — show or hide Moxie in the profession list."))
    print("  " .. (L["slash_last"] or "|cFFAAAAAA/conc last|r — the tracked line that fills last."))
    print("  " .. (L["slash_alpha"] or "|cFFAAAAAA/conc alpha|r — window opacity (0–100)."))
    print("  " .. (L["slash_markme"] or "|cFFAAAAAA/conc markme|r — mark this character's rows."))
    print("  " .. (L["slash_fullhl"] or "|cFFAAAAAA/conc fullhl|r — tint rows that are already full."))
    print("  " .. (L["slash_realm"] or "|cFFAAAAAA/conc realm|r — show or hide realm names."))
    print("  " .. (L["slash_copy"] or "|cFFAAAAAA/conc copy|r — copy this character's status into the chat box."))
    print("  " .. (L["slash_minimap"] or "|cFFAAAAAA/conc minimap|r — show or hide the minimap button."))
    print("  " .. (L["slash_lock"] or "|cFFAAAAAA/conc lock|r — lock or unlock the main window."))
    print("  " .. (L["slash_settings"] or "|cFFAAAAAA/conc settings|r — open settings."))
    print("  " .. (L["slash_resetui"] or "|cFFAAAAAA/conc resetui|r — reset window position and size."))
    print("  " .. (L["slash_version"] or "|cFFAAAAAA/conc version|r or |cFFAAAAAA/conc v|r — show addon version."))
    print("  " .. (L["slash_help"] or "|cFFAAAAAA/conc help|r or |cFFAAAAAA/conc ?|r — show this help."))
end

local function PrintAddonVersion()
    EnsureLocalization()
    print(ADDON_TAG .. string.format(LOr("version_label", "Version %s"), ADDON_VERSION or "?"))
end

--- Скидає фільтри доповнення / професії / персонажа на «Усі».
local function ResetAllFilters(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.selectedExpansion = "All"
    ConcentrationTrackerSettings.selectedProfession = "All"
    ConcentrationTrackerSettings.selectedCharacter = "All"
    ns.searchText = ""
    if ns.SyncSearchBox then
        ns.SyncSearchBox()
    end
    RefreshExpansionDropdowns()
    RefreshProfessionDropdown()
    RefreshCharacterDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        print(ADDON_TAG .. (L["msg_filters_cleared"] or "Filters reset to All."))
    end
end

--- Найближчий рядок до повної концентрації (з урахуванням або без фільтрів таблиці).
local function FindNextToFullEntry(useMainFilters)
    if not ConcentrationTrackerDB then
        return nil
    end
    local best, bestSec
    for key, data in pairs(ConcentrationTrackerDB) do
        if EntryHasConcentration(data) then
            local ok = true
            if useMainFilters then
                ok = EntryPassesMainTableFilters(key, data)
            else
                local _, _, skillLineID = GetEntryIdentity(key, data)
                if IsSkillLineIgnored(skillLineID) then
                    ok = false
                end
            end
            if ok then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    remSec = tonumber(remSec) or 0
                    if q < maxQ and remSec > 0 then
                        if not bestSec or remSec < bestSec then
                            bestSec = remSec
                            best = {
                                charName = charName,
                                realm = realm,
                                professionName = data.professionName or (L and L["profession"]) or "Profession",
                                quantity = q,
                                maxQuantity = maxQ,
                                remainingSeconds = remSec,
                                timeToFull = FormatTimeToFullString(remSec),
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

local function PrintNextToFull()
    EnsureLocalization()
    local nextEntry = FindNextToFullEntry(false)
    if not nextEntry then
        print(ADDON_TAG .. (L["msg_next_none"] or "Nothing waiting to fill — all tracked concentration is full, or there is no data."))
        return
    end
    local who = nextEntry.charName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
        who = FormatCharacterFilterLabel(nextEntry.charName, nextEntry.realm)
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_next_fill", "Next full: %s (%s) — %s (%.0f/%d)"),
        who,
        nextEntry.professionName,
        nextEntry.timeToFull,
        nextEntry.quantity,
        nextEntry.maxQuantity
    ))
end

--- Найнижча концентрація (найменший % заповнення серед неповних рядків).
local function FindLowestConcentrationEntry(useMainFilters)
    if not ConcentrationTrackerDB then
        return nil
    end
    local best, bestPct
    for key, data in pairs(ConcentrationTrackerDB) do
        if EntryHasConcentration(data) then
            local ok = true
            if useMainFilters then
                ok = EntryPassesMainTableFilters(key, data)
            else
                local _, _, skillLineID = GetEntryIdentity(key, data)
                if IsSkillLineIgnored(skillLineID) then
                    ok = false
                end
            end
            if ok then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    if maxQ and maxQ > 0 then
                        local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                        if q < maxQ then
                            local pct = q / maxQ
                            remSec = tonumber(remSec) or 0
                            if not bestPct or pct < bestPct or (pct == bestPct and remSec > (best.remainingSeconds or 0)) then
                                bestPct = pct
                                best = {
                                    charName = charName,
                                    realm = realm,
                                    professionName = data.professionName or (L and L["profession"]) or "Profession",
                                    quantity = q,
                                    maxQuantity = maxQ,
                                    remainingSeconds = remSec,
                                    timeToFull = FormatTimeToFullString(remSec),
                                    fillPercent = math.floor(pct * 100 + 0.5),
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function PrintLowestConcentration()
    EnsureLocalization()
    local lowest = FindLowestConcentrationEntry(false)
    if not lowest then
        print(ADDON_TAG .. (L["msg_lowest_none"] or "No incomplete concentration rows — everything is full, or there is no data."))
        return
    end
    local who = lowest.charName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
        who = FormatCharacterFilterLabel(lowest.charName, lowest.realm)
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_lowest_fill", "Lowest: %s (%s) — %.0f/%d (%d%%)  %s"),
        who,
        lowest.professionName,
        lowest.quantity,
        lowest.maxQuantity,
        lowest.fillPercent or 0,
        lowest.timeToFull or ""
    ))
end

local function CollectVisibleIdentityRows()
    local rows = {}
    if not ConcentrationTrackerDB then
        return rows
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                if not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                    rows[#rows + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        lastUpdate = data.lastUpdate,
                        stale = IsDataStale(data.lastUpdate),
                        moxieOnly = data.moxieOnly == true,
                        hasConc = EntryHasConcentration(data),
                    }
                end
            end
        end
    end
    return rows
end

local function PrintStaleRows()
    EnsureLocalization()
    local rows = CollectVisibleIdentityRows()
    local stale = {}
    for _, row in ipairs(rows) do
        if row.stale then
            stale[#stale + 1] = row
        end
    end
    if #stale == 0 then
        print(ADDON_TAG .. (L["msg_stale_none"] or "No stale rows — all tracked data was synced within 24 hours."))
        return
    end
    table.sort(stale, function(a, b)
        local ak = (a.charName or "") .. "\0" .. (a.professionName or "")
        local bk = (b.charName or "") .. "\0" .. (b.professionName or "")
        return ak < bk
    end)
    print(ADDON_TAG .. string.format(LOr("msg_stale_header", "Stale rows (%d):"), #stale))
    for _, row in ipairs(stale) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_stale_line", "%s (%s) — %s"),
            who,
            row.professionName,
            FormatDataAgeShort(row.lastUpdate)
        ))
    end
end

function ns.PrintFullRows()
    EnsureLocalization()
    if not ConcentrationTrackerDB then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    local full = {}
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                if not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                    if q >= maxQ then
                        full[#full + 1] = {
                            charName = charName,
                            realm = realm,
                            professionName = data.professionName or (L and L["profession"]) or "Profession",
                        }
                    end
                end
            end
        end
    end
    if #full == 0 then
        print(ADDON_TAG .. (L["msg_full_none"] or "No rows are at maximum concentration."))
        return
    end
    table.sort(full, function(a, b)
        local ak = (a.charName or "") .. "\0" .. (a.professionName or "")
        local bk = (b.charName or "") .. "\0" .. (b.professionName or "")
        return ak < bk
    end)
    print(ADDON_TAG .. string.format(LOr("msg_full_header", "Full concentration (%d):"), #full))
    for _, row in ipairs(full) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format("%s (%s)", who, row.professionName))
    end
end

function ns.NormalizeSoonHours(hours)
    hours = tonumber(hours)
    if not hours or hours <= 0 then
        hours = 2
    end
    if hours < 0.25 then
        hours = 0.25
    elseif hours > 48 then
        hours = 48
    end
    return hours
end

function ns.IsSoonFill(remainingSeconds, hours)
    remainingSeconds = tonumber(remainingSeconds) or 0
    hours = ns.NormalizeSoonHours(hours)
    return remainingSeconds > 0 and remainingSeconds <= (hours * 3600)
end

function ns.CollectSoonRows(hours, useMainFilters)
    hours = ns.NormalizeSoonHours(hours)
    local list = {}
    if not ConcentrationTrackerDB then
        return list, hours
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local ok = true
            if useMainFilters then
                ok = EntryPassesMainTableFilters(key, data)
            else
                local _, _, skillLineID = GetEntryIdentity(key, data)
                if skillLineID and IsSkillLineIgnored(skillLineID) then
                    ok = false
                end
            end
            if ok then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    remSec = tonumber(remSec) or 0
                    if q < maxQ and ns.IsSoonFill(remSec, hours) then
                        list[#list + 1] = {
                            charName = charName,
                            realm = realm,
                            professionName = data.professionName or (L and L["profession"]) or "Profession",
                            quantity = q,
                            maxQuantity = maxQ,
                            remainingSeconds = remSec,
                            timeToFull = FormatTimeToFullString(remSec),
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.remainingSeconds or 0) < (b.remainingSeconds or 0)
    end)
    return list, hours
end

function ns.PrintSoonRows(hours)
    EnsureLocalization()
    local list, usedHours = ns.CollectSoonRows(hours, false)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_soon_none", "No rows fill within %.2g hours."),
            usedHours
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_soon_header", "Fills within %.2g hours (%d):"),
        usedHours,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_soon_line", "%s (%s) — %s (%.0f/%d)"),
            who,
            row.professionName,
            row.timeToFull or "",
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.GetSecondsUntilDailyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local s = tonumber(C_DateAndTime.GetSecondsUntilDailyReset())
        if s and s > 0 then
            return s
        end
    end
    if GetQuestResetTime then
        local s = tonumber(GetQuestResetTime())
        if s and s > 0 then
            return s
        end
    end
    return 24 * 3600
end

function ns.IsFillBeforeReset(remainingSeconds, secondsUntilReset)
    remainingSeconds = tonumber(remainingSeconds) or 0
    secondsUntilReset = tonumber(secondsUntilReset) or 0
    return remainingSeconds > 0 and secondsUntilReset > 0 and remainingSeconds <= secondsUntilReset
end

function ns.CollectTodayRows(useMainFilters)
    local resetSec = ns.GetSecondsUntilDailyReset()
    local list = {}
    if not ConcentrationTrackerDB then
        return list, resetSec
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local ok = true
            if useMainFilters then
                ok = EntryPassesMainTableFilters(key, data)
            else
                local _, _, skillLineID = GetEntryIdentity(key, data)
                if skillLineID and IsSkillLineIgnored(skillLineID) then
                    ok = false
                end
            end
            if ok then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    remSec = tonumber(remSec) or 0
                    if q < maxQ and ns.IsFillBeforeReset(remSec, resetSec) then
                        list[#list + 1] = {
                            charName = charName,
                            realm = realm,
                            professionName = data.professionName or (L and L["profession"]) or "Profession",
                            quantity = q,
                            maxQuantity = maxQ,
                            remainingSeconds = remSec,
                            timeToFull = FormatTimeToFullString(remSec),
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.remainingSeconds or 0) < (b.remainingSeconds or 0)
    end)
    return list, resetSec
end

function ns.PrintTodayRows()
    EnsureLocalization()
    local list, resetSec = ns.CollectTodayRows(false)
    local resetLabel = FormatTimeToFullString(resetSec)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_today_none", "No rows fill before daily reset (%s)."),
            resetLabel
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_today_header", "Fills before daily reset in %s (%d):"),
        resetLabel,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_soon_line", "%s (%s) — %s (%.0f/%d)"),
            who,
            row.professionName,
            row.timeToFull or "",
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.CollectAccountTotals()
    local t = {
        chars = 0,
        concRows = 0,
        full = 0,
        notFull = 0,
        stale = 0,
        quantity = 0,
        maxQuantity = 0,
        moxie = 0,
        soon = 0,
        today = 0,
        weekly = 0,
        resetSeconds = ns.GetSecondsUntilDailyReset(),
    }
    local seenChar = {}
    if ConcentrationTrackerDB then
        for key, data in pairs(ConcentrationTrackerDB) do
            if type(data) == "table" then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                    and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                    local ck = MakeCharacterFilterKey(charName, realm)
                    if ck and not seenChar[ck] then
                        seenChar[ck] = true
                        t.chars = t.chars + 1
                    end
                    local mq = GetMoxieQuantityForEntry(data, skillLineID)
                    if mq ~= nil then
                        t.moxie = t.moxie + mq
                    end
                    if EntryHasConcentration(data) then
                        t.concRows = t.concRows + 1
                        local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                        local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                        remSec = tonumber(remSec) or 0
                        t.quantity = t.quantity + q
                        t.maxQuantity = t.maxQuantity + maxQ
                        if q >= maxQ then
                            t.full = t.full + 1
                        else
                            t.notFull = t.notFull + 1
                            if ns.IsSoonFill(remSec, 2) then
                                t.soon = t.soon + 1
                            end
                            if ns.IsFillBeforeReset(remSec, t.resetSeconds) then
                                t.today = t.today + 1
                            end
                        end
                        if IsDataStale(data.lastUpdate) then
                            t.stale = t.stale + 1
                        end
                    elseif data.moxieOnly and IsDataStale(data.lastUpdate) then
                        t.stale = t.stale + 1
                    end
                end
            end
        end
    end
    t.weekly = #ns.CollectReadyProfessionWeeklies()
    return t
end

function ns.PrintAccountTotals()
    EnsureLocalization()
    if not ConcentrationTrackerDB then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    local t = ns.CollectAccountTotals()
    if t.concRows == 0 and t.chars == 0 then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_totals_line1", "Account: %d chars  |  %.0f/%d  (%d not full, %d full)  |  Moxie: %d"),
        t.chars,
        t.quantity,
        t.maxQuantity,
        t.notFull,
        t.full,
        t.moxie
    ))
    print("  " .. string.format(
        LOr("msg_totals_line2", "Soon (2h): %d  |  Before reset: %d  |  Stale: %d  |  Turn in: %d"),
        t.soon,
        t.today,
        t.stale,
        t.weekly
    ))
end

function ns.GetSecondsUntilWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local s = tonumber(C_DateAndTime.GetSecondsUntilWeeklyReset())
        if s and s > 0 then
            return s
        end
    end
    return 7 * 24 * 3600
end

function ns.CollectWeekRows(useMainFilters)
    local resetSec = ns.GetSecondsUntilWeeklyReset()
    local list = {}
    if not ConcentrationTrackerDB then
        return list, resetSec
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local ok = true
            if useMainFilters then
                ok = EntryPassesMainTableFilters(key, data)
            else
                local _, _, skillLineID = GetEntryIdentity(key, data)
                if skillLineID and IsSkillLineIgnored(skillLineID) then
                    ok = false
                end
            end
            if ok then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    remSec = tonumber(remSec) or 0
                    if q < maxQ and ns.IsFillBeforeReset(remSec, resetSec) then
                        list[#list + 1] = {
                            charName = charName,
                            realm = realm,
                            professionName = data.professionName or (L and L["profession"]) or "Profession",
                            quantity = q,
                            maxQuantity = maxQ,
                            remainingSeconds = remSec,
                            timeToFull = FormatTimeToFullString(remSec),
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.remainingSeconds or 0) < (b.remainingSeconds or 0)
    end)
    return list, resetSec
end

function ns.PrintWeekRows()
    EnsureLocalization()
    local list, resetSec = ns.CollectWeekRows(false)
    local resetLabel = FormatTimeToFullString(resetSec)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_week_none", "No rows fill before weekly reset (%s)."),
            resetLabel
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_week_header", "Fills before weekly reset in %s (%d):"),
        resetLabel,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_soon_line", "%s (%s) — %s (%.0f/%d)"),
            who,
            row.professionName,
            row.timeToFull or "",
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.CollectMissingConcentration()
    local list = {}
    local total = 0
    if not ConcentrationTrackerDB then
        return list, total
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                local gap = (tonumber(maxQ) or 0) - (tonumber(q) or 0)
                if gap > 0 then
                    total = total + gap
                    list[#list + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        quantity = q,
                        maxQuantity = maxQ,
                        gap = gap,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.gap or 0) > (b.gap or 0)
    end)
    return list, total
end

function ns.PrintMissingConcentration()
    EnsureLocalization()
    local list, total = ns.CollectMissingConcentration()
    if #list == 0 then
        print(ADDON_TAG .. (L["msg_missing_none"] or "Nothing missing — tracked concentration is full, or there is no data."))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_missing_header", "Missing to cap: %.0f across %d rows"),
        total,
        #list
    ))
    local shown = math.min(#list, 8)
    for i = 1, shown do
        local row = list[i]
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_missing_line", "%s (%s) — %.0f to cap (%.0f/%d)"),
            who,
            row.professionName,
            row.gap or 0,
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
    if #list > shown then
        print("  " .. string.format(LOr("msg_missing_more", "(+%d more)"), #list - shown))
    end
end

function ns.NormalizeMoxieListThreshold(n)
    n = tonumber(n)
    if not n or n < 1 then
        return MOXIE_NOTIFY_THRESHOLD
    end
    if n > 100000 then
        n = 100000
    end
    return math.floor(n)
end

function ns.CollectMoxieAtThreshold(threshold)
    threshold = ns.NormalizeMoxieListThreshold(threshold)
    local list = {}
    if not ConcentrationTrackerDB then
        return list, threshold
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil and mq >= threshold then
                    list[#list + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        moxie = mq,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.moxie or 0) > (b.moxie or 0)
    end)
    return list, threshold
end

function ns.PrintMoxieAtThreshold(threshold)
    EnsureLocalization()
    local list, used = ns.CollectMoxieAtThreshold(threshold)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_moxiecap_none", "No tracked rows at %d Moxie or above."),
            used
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_moxiecap_header", "Moxie at %d or above (%d):"),
        used,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_moxiecap_line", "%s (%s) — %d"),
            who,
            row.professionName,
            row.moxie or 0
        ))
    end
end

function ns.NormalizeSpendAmount(amount)
    amount = tonumber(amount)
    if not amount or amount < 1 then
        return 100
    end
    if amount > 100000 then
        amount = 100000
    end
    return math.floor(amount)
end

function ns.IsSpendable(quantity, maxQuantity, amount)
    quantity = tonumber(quantity) or 0
    maxQuantity = tonumber(maxQuantity) or 0
    amount = ns.NormalizeSpendAmount(amount)
    return maxQuantity > 0 and quantity >= amount
end

function ns.ProfessionNameMatches(professionName, query)
    if type(query) ~= "string" then
        return false
    end
    query = query:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if query == "" then
        return false
    end
    return tostring(professionName or ""):lower():find(query, 1, true) ~= nil
end

function ns.CollectSpendableRows(amount)
    amount = ns.NormalizeSpendAmount(amount)
    local list = {}
    if not ConcentrationTrackerDB then
        return list, amount
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                if ns.IsSpendable(q, maxQ, amount) then
                    list[#list + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        quantity = q,
                        maxQuantity = maxQ,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.quantity or 0) > (b.quantity or 0)
    end)
    return list, amount
end

function ns.PrintSpendableRows(amount)
    EnsureLocalization()
    local list, used = ns.CollectSpendableRows(amount)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_spend_none", "No tracked rows have %d concentration or more."),
            used
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_spend_header", "Ready to spend (%d or more) (%d):"),
        used,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_spend_line", "%s (%s) — %.0f/%d"),
            who,
            row.professionName,
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.CollectProfessionRows(query)
    local list = {}
    if type(query) ~= "string" then
        query = ""
    end
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" or not ConcentrationTrackerDB then
        return list, query
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            local pname = data.professionName or ""
            if charName and ns.ProfessionNameMatches(pname, query)
                and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ, q, timeToFull
                if EntryHasConcentration(data) then
                    maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                    timeToFull = FormatTimeToFullString(select(2, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)) or 0)
                end
                list[#list + 1] = {
                    charName = charName,
                    realm = realm,
                    professionName = pname,
                    quantity = q,
                    maxQuantity = maxQ,
                    timeToFull = timeToFull,
                    moxie = GetMoxieQuantityForEntry(data, skillLineID),
                    hasConc = q ~= nil,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.professionName == b.professionName then
            return (a.charName or "") < (b.charName or "")
        end
        return (a.professionName or "") < (b.professionName or "")
    end)
    return list, query
end

function ns.PrintProfessionRows(query)
    EnsureLocalization()
    if type(query) ~= "string" or query:gsub("%s", "") == "" then
        print(ADDON_TAG .. (L["msg_prof_need"] or "Usage: /conc prof Alchemy"))
        return
    end
    local list, used = ns.CollectProfessionRows(query)
    if #list == 0 then
        print(ADDON_TAG .. string.format(LOr("msg_prof_none", "No tracked rows match \"%s\"."), used))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_prof_header", "Profession \"%s\" (%d):"), used, #list))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        local detail
        if row.hasConc then
            detail = string.format("%.0f/%d", row.quantity or 0, row.maxQuantity or 0)
            if row.timeToFull and row.timeToFull ~= "" then
                detail = detail .. "  " .. row.timeToFull
            end
        else
            detail = L["no_concentration"] or "—"
        end
        if row.moxie ~= nil then
            detail = detail .. "  " .. string.format(L["moxie_short"] or "Moxie: %d", row.moxie)
        end
        print("  " .. string.format("%s (%s) — %s", who, row.professionName, detail))
    end
end

function ns.NormalizeFillPercent(pct)
    pct = tonumber(pct)
    if not pct or pct < 1 then
        return 25
    end
    if pct > 100 then
        pct = 100
    end
    return math.floor(pct)
end

function ns.IsBelowFill(quantity, maxQuantity, pct)
    quantity = tonumber(quantity) or 0
    maxQuantity = tonumber(maxQuantity) or 0
    if maxQuantity <= 0 then
        return false
    end
    pct = ns.NormalizeFillPercent(pct)
    return (quantity / maxQuantity) * 100 < pct
end

function ns.CharacterNameMatches(charName, query)
    if type(query) ~= "string" then
        return false
    end
    query = query:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if query == "" then
        return false
    end
    return tostring(charName or ""):lower():find(query, 1, true) ~= nil
end

function ns.CollectBelowFillRows(pct)
    pct = ns.NormalizeFillPercent(pct)
    local list = {}
    if not ConcentrationTrackerDB then
        return list, pct
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                if ns.IsBelowFill(q, maxQ, pct) then
                    list[#list + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        quantity = q,
                        maxQuantity = maxQ,
                        fillPercent = math.floor((q / maxQ) * 100 + 0.5),
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.fillPercent or 0) == (b.fillPercent or 0) then
            return (a.charName or "") < (b.charName or "")
        end
        return (a.fillPercent or 0) < (b.fillPercent or 0)
    end)
    return list, pct
end

function ns.PrintBelowFill(pct)
    EnsureLocalization()
    local list, used = ns.CollectBelowFillRows(pct)
    if #list == 0 then
        print(ADDON_TAG .. string.format(
            LOr("msg_below_none", "No tracked rows are under %d%%."),
            used
        ))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_below_header", "Under %d%% (%d):"),
        used,
        #list
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_below_line", "%s (%s) — %d%% (%.0f/%d)"),
            who,
            row.professionName,
            row.fillPercent or 0,
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.CollectCharacterRows(query)
    local list = {}
    if type(query) ~= "string" then
        query = ""
    end
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" or not ConcentrationTrackerDB then
        return list, query
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            local pname = data.professionName or (L and L["profession"]) or "Profession"
            if charName and ns.CharacterNameMatches(charName, query)
                and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ, q, timeToFull
                if EntryHasConcentration(data) then
                    maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local remSec
                    q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    timeToFull = FormatTimeToFullString(remSec or 0)
                end
                list[#list + 1] = {
                    charName = charName,
                    realm = realm,
                    professionName = pname,
                    quantity = q,
                    maxQuantity = maxQ,
                    timeToFull = timeToFull,
                    moxie = GetMoxieQuantityForEntry(data, skillLineID),
                    hasConc = q ~= nil,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.charName == b.charName then
            return (a.professionName or "") < (b.professionName or "")
        end
        return (a.charName or "") < (b.charName or "")
    end)
    return list, query
end

function ns.PrintCharacterRows(query)
    EnsureLocalization()
    if type(query) ~= "string" or query:gsub("%s", "") == "" then
        print(ADDON_TAG .. (L["msg_char_need"] or "Usage: /conc char Name"))
        return
    end
    local list, used = ns.CollectCharacterRows(query)
    if #list == 0 then
        print(ADDON_TAG .. string.format(LOr("msg_char_none", "No tracked rows match \"%s\"."), used))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_char_header", "Character \"%s\" (%d):"), used, #list))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        local detail
        if row.hasConc then
            detail = string.format("%.0f/%d", row.quantity or 0, row.maxQuantity or 0)
            if row.timeToFull and row.timeToFull ~= "" then
                detail = detail .. "  " .. row.timeToFull
            end
        else
            detail = L["no_concentration"] or "—"
        end
        if row.moxie ~= nil then
            detail = detail .. "  " .. string.format(L["moxie_short"] or "Moxie: %d", row.moxie)
        end
        print("  " .. string.format("%s (%s) — %s", who, row.professionName, detail))
    end
end

function ns.NormalizeReachTarget(amount)
    amount = tonumber(amount)
    if not amount or amount < 1 then
        return nil
    end
    if amount > 100000 then
        amount = 100000
    end
    return math.floor(amount)
end

function ns.SecondsUntilQuantity(current, maxQuantity, target, ratePerHour)
    current = tonumber(current) or 0
    maxQuantity = tonumber(maxQuantity) or 0
    target = tonumber(target) or 0
    ratePerHour = tonumber(ratePerHour) or 0
    if target < 1 or ratePerHour <= 0 or maxQuantity <= 0 or target > maxQuantity then
        return nil
    end
    if current >= target then
        return 0
    end
    return ((target - current) / ratePerHour) * 3600
end

function ns.CollectReachRows(amount)
    local target = ns.NormalizeReachTarget(amount)
    local waiting = {}
    local already = 0
    if not target or not ConcentrationTrackerDB then
        return waiting, target, already
    end
    local rate = GetRestoreRate()
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                local sec = ns.SecondsUntilQuantity(q, maxQ, target, rate)
                if sec == 0 then
                    already = already + 1
                elseif sec then
                    waiting[#waiting + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        quantity = q,
                        maxQuantity = maxQ,
                        seconds = sec,
                        timeLabel = FormatTimeToFullString(sec),
                    }
                end
            end
        end
    end
    table.sort(waiting, function(a, b)
        return (a.seconds or 0) < (b.seconds or 0)
    end)
    return waiting, target, already
end

function ns.PrintReachRows(amount)
    EnsureLocalization()
    if not ns.NormalizeReachTarget(amount) then
        print(ADDON_TAG .. (L["msg_reach_need"] or "Usage: /conc reach 500"))
        return
    end
    local list, target, already = ns.CollectReachRows(amount)
    if #list == 0 then
        if already > 0 then
            print(ADDON_TAG .. string.format(
                LOr("msg_reach_all", "Every tracked row already has %d concentration."),
                target
            ))
        else
            print(ADDON_TAG .. string.format(
                LOr("msg_reach_none", "No tracked row can reach %d concentration."),
                target
            ))
        end
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_reach_header", "Reaches %d (%d waiting, %d already there):"),
        target,
        #list,
        already
    ))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_reach_line", "%s (%s) — %s (%.0f/%d)"),
            who,
            row.professionName,
            row.timeLabel or "",
            row.quantity or 0,
            row.maxQuantity or 0
        ))
    end
end

function ns.ExpansionQueryKey(query)
    if type(query) ~= "string" then
        return ""
    end
    local q = query:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local aliases = {
        tww = "khaz algar",
        ["the war within"] = "khaz algar",
        ["war within"] = "khaz algar",
        khaz = "khaz algar",
        ["khaz'algar"] = "khaz algar",
        df = "dragon isles",
        dragonflight = "dragon isles",
        dragon = "dragon isles",
        sl = "shadowlands",
        bfa = "battle for azeroth",
        wod = "warlords of draenor",
        mop = "mists of pandaria",
        wotlk = "wrath of the lich king",
        wrath = "wrath of the lich king",
        bc = "burning crusade",
        tbc = "burning crusade",
        cata = "cataclysm",
    }
    return aliases[q] or q
end

function ns.ExpansionLabelMatches(expansionKey, query)
    local q = ns.ExpansionQueryKey(query)
    if q == "" then
        return false
    end
    return tostring(expansionKey or ""):lower():find(q, 1, true) ~= nil
end

function ns.CollectExpansionRows(query)
    local list = {}
    if type(query) ~= "string" then
        query = ""
    end
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" or not ConcentrationTrackerDB then
        return list, query
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            local expansionKey = GetExpansionKeyForEntry(data, skillLineID)
            if charName and ns.ExpansionLabelMatches(expansionKey, query)
                and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local pname = data.professionName or (L and L["profession"]) or "Profession"
                local maxQ, q, timeToFull
                if EntryHasConcentration(data) then
                    maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local remSec
                    q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                    timeToFull = FormatTimeToFullString(remSec or 0)
                end
                list[#list + 1] = {
                    charName = charName,
                    realm = realm,
                    professionName = pname,
                    expansionKey = expansionKey,
                    quantity = q,
                    maxQuantity = maxQ,
                    timeToFull = timeToFull,
                    moxie = GetMoxieQuantityForEntry(data, skillLineID),
                    hasConc = q ~= nil,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.expansionKey == b.expansionKey then
            if a.charName == b.charName then
                return (a.professionName or "") < (b.professionName or "")
            end
            return (a.charName or "") < (b.charName or "")
        end
        return (a.expansionKey or "") < (b.expansionKey or "")
    end)
    return list, query
end

function ns.PrintExpansionRows(query)
    EnsureLocalization()
    if type(query) ~= "string" or query:gsub("%s", "") == "" then
        print(ADDON_TAG .. (L["msg_exp_need"] or "Usage: /conc exp Midnight"))
        return
    end
    local list, used = ns.CollectExpansionRows(query)
    if #list == 0 then
        print(ADDON_TAG .. string.format(LOr("msg_exp_none", "No tracked rows match \"%s\"."), used))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_exp_header", "Expansion \"%s\" (%d):"), used, #list))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        local detail
        if row.hasConc then
            detail = string.format("%.0f/%d", row.quantity or 0, row.maxQuantity or 0)
            if row.timeToFull and row.timeToFull ~= "" then
                detail = detail .. "  " .. row.timeToFull
            end
        else
            detail = L["no_concentration"] or "—"
        end
        if row.moxie ~= nil then
            detail = detail .. "  " .. string.format(L["moxie_short"] or "Moxie: %d", row.moxie)
        end
        print("  " .. string.format("%s (%s) — %s", who, row.professionName, detail))
    end
end

function ns.ResolveSortColumn(token)
    if type(token) ~= "string" then
        return nil
    end
    token = token:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local map = {
        character = "character",
        char = "character",
        name = "character",
        profession = "profession",
        prof = "profession",
        moxie = "moxie",
        concentration = "concentration",
        conc = "concentration",
        time = "time_remaining",
        timer = "time_remaining",
        remaining = "time_remaining",
    }
    return map[token]
end

function ns.ResolveColumnSetting(token)
    if type(token) ~= "string" then
        return nil
    end
    token = token:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local map = {
        character = "showColCharacter",
        char = "showColCharacter",
        name = "showColCharacter",
        profession = "showColProfession",
        prof = "showColProfession",
        moxie = "showColMoxie",
        concentration = "showColConcentration",
        conc = "showColConcentration",
        time = "showColTimeToFull",
        timer = "showColTimeToFull",
        remaining = "showColTimeToFull",
        exact = "showColRestoresAt",
        restores = "showColRestoresAt",
        at = "showColRestoresAt",
    }
    return map[token]
end

function ns.NormalizeRestoreRate(rate)
    rate = tonumber(rate)
    if not rate then
        return nil
    end
    rate = math.floor(rate + 0.5)
    if rate < 1 then
        rate = 1
    elseif rate > 25 then
        rate = 25
    end
    return rate
end

function ns.CanHideAnotherColumn(visibleCount)
    return (tonumber(visibleCount) or 0) > 1
end

function ns.CollectVisibleTableRows()
    local list = {}
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        return list
    end
    local showMoxie = ConcentrationTrackerSettings.showMoxie ~= false
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryPassesMainTableFilters(key, data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            local pname = data.professionName or (L and L["profession"]) or "Profession"
            if EntryHasConcentration(data) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                if ConcentrationTrackerSettings.hideFullConcentration and q >= maxQ then
                    -- skip
                elseif ConcentrationTrackerSettings.hideStaleRows and IsDataStale(data.lastUpdate) then
                    -- skip
                else
                    list[#list + 1] = {
                        sortKey = (charName or "") .. "\0" .. pname,
                        charName = charName,
                        realm = realm,
                        professionName = pname,
                        line = string.format("%s  %s", FormatConcentrationAmount(q, maxQ), FormatTimeToFullString(remSec)),
                    }
                end
            elseif showMoxie and not ConcentrationTrackerSettings.hideMoxieOnlyRows and data.moxieOnly then
                if not (ConcentrationTrackerSettings.hideStaleRows and IsDataStale(data.lastUpdate)) then
                    local mq = GetMoxieQuantityForEntry(data, skillLineID)
                    if mq ~= nil then
                        list[#list + 1] = {
                            sortKey = (charName or "") .. "\0" .. pname,
                            charName = charName,
                            realm = realm,
                            professionName = pname,
                            line = string.format(L["moxie_short"] or "Moxie: %d", mq),
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.sortKey or "") < (b.sortKey or "")
    end)
    return list
end

function ns.FormatVisibleRowLine(row)
    local who = row.charName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
        who = FormatCharacterFilterLabel(row.charName, row.realm)
    end
    return string.format("%s (%s) — %s", who, row.professionName, row.line)
end

function ns.PrintVisibleRows()
    EnsureLocalization()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    local list = ns.CollectVisibleTableRows()
    if #list == 0 then
        print(ADDON_TAG .. (L["empty_filtered"] or "No rows match the current filters."))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_list_header", "Visible rows (%d):"), #list))
    for _, row in ipairs(list) do
        print("  " .. ns.FormatVisibleRowLine(row))
    end
end

function ns.ExportVisibleRows()
    EnsureLocalization()
    local list = ns.CollectVisibleTableRows()
    if #list == 0 then
        print(ADDON_TAG .. (L["empty_filtered"] or "No rows match the current filters."))
        return
    end
    local parts = {}
    for _, row in ipairs(list) do
        parts[#parts + 1] = ns.FormatVisibleRowLine(row)
    end
    ns.CopyTextToChat(table.concat(parts, "  |  "))
end

function ns.SyncSearchBox()
    local box = ConcentrationWindow and ConcentrationWindow.searchBox
    if not box then
        return
    end
    local q = ns.GetSearchText()
    if box:GetText() ~= q then
        box:SetText(q)
    end
    if box.Instructions then
        if q == "" then
            box.Instructions:Show()
        else
            box.Instructions:Hide()
        end
        box.Instructions:SetText(LOr("search_placeholder", "Search..."))
    end
end

function ns.SetSearchText(text, opts)
    opts = opts or {}
    if type(text) ~= "string" then
        text = ""
    end
    ns.searchText = text:gsub("^%s+", ""):gsub("%s+$", "")
    ns.SyncSearchBox()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ns.searchText == "" then
            print(ADDON_TAG .. (L["msg_search_cleared"] or "Search filter cleared."))
        else
            print(ADDON_TAG .. string.format(LOr("msg_search_set", "Search: %s"), ns.searchText))
        end
    end
end

function ns.PrintOldestRow()
    EnsureLocalization()
    if not ConcentrationTrackerDB then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    local oldest
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.lastUpdate then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                if not oldest or data.lastUpdate < oldest.lastUpdate then
                    oldest = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        lastUpdate = data.lastUpdate,
                    }
                end
            end
        end
    end
    if not oldest then
        print(ADDON_TAG .. (L["msg_oldest_none"] or "No sync timestamps yet."))
        return
    end
    local who = oldest.charName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
        who = FormatCharacterFilterLabel(oldest.charName, oldest.realm)
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_oldest_line", "Oldest sync: %s (%s) — %s"),
        who,
        oldest.professionName,
        FormatDataAgeShort(oldest.lastUpdate)
    ))
end

function ns.PrintIgnoredSkillLines()
    EnsureLocalization()
    EnsureIgnoredSkillLinesTable()
    local ids = ConcentrationTrackerSettings and ConcentrationTrackerSettings.ignoredSkillLines
    if type(ids) ~= "table" or #ids == 0 then
        print(ADDON_TAG .. (L["msg_ignored_none"] or "No ignored profession variants."))
        return
    end
    local names = {}
    if ConcentrationTrackerDB then
        for key, data in pairs(ConcentrationTrackerDB) do
            if type(data) == "table" and data.professionName then
                local _, _, sid = GetEntryIdentity(key, data)
                if sid then
                    names[sid] = data.professionName
                end
            end
        end
    end
    print(ADDON_TAG .. string.format(LOr("msg_ignored_header", "Ignored profession variants (%d):"), #ids))
    for _, id in ipairs(ids) do
        local label = names[id]
        if not label and type(C_TradeSkillUI) == "table" and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)
            if info and info.professionName then
                label = info.professionName
            end
        end
        print("  " .. string.format(
            LOr("msg_ignored_line", "%s  (skill line %d)"),
            label or (L["profession"] or "Profession"),
            id
        ))
    end
end

function ns.FormatWeeklyTurnInLine(row)
    if row.professionName and row.professionName ~= "" then
        return string.format("%s (%s)", row.title, row.professionName)
    end
    return row.title or "?"
end

function ns.PrintWeeklyTurnIns()
    EnsureLocalization()
    local list = ns.CollectReadyProfessionWeeklies()
    if #list == 0 then
        print(ADDON_TAG .. (L["msg_weekly_none"] or "No profession weekly is complete and waiting to be turned in."))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_weekly_header", "Turn in these profession weeklies (%d):"), #list))
    for _, row in ipairs(list) do
        print("  " .. ns.FormatWeeklyTurnInLine(row))
    end
end

function ns.CopyWeeklyTurnIns()
    EnsureLocalization()
    local list = ns.CollectReadyProfessionWeeklies()
    if #list == 0 then
        print(ADDON_TAG .. (L["msg_weekly_none"] or "No profession weekly is complete and waiting to be turned in."))
        return
    end
    local parts = {}
    for _, row in ipairs(list) do
        parts[#parts + 1] = ns.FormatWeeklyTurnInLine(row)
    end
    ns.CopyTextToChat(table.concat(parts, "  |  "))
end

function ns.UpdateWeeklyTurnInBanner()
    local win = ConcentrationWindow
    if not win or not win.weeklyAlertText then
        return
    end
    EnsureLocalization()
    local list = ns.CollectReadyProfessionWeeklies()
    ns.lastWeeklyReady = list
    local headerH = ns.MAIN_HEADER_HEIGHT or 78
    if #list == 0 or (ConcentrationTrackerSettings and ConcentrationTrackerSettings.notifyWeeklyTurnIn == false) then
        win.weeklyAlertText:SetText("")
        win.weeklyAlertText:Hide()
        if win.weeklyAlertButton then
            win.weeklyAlertButton:Hide()
        end
        if win.scrollFrame then
            win.scrollFrame:SetPoint("TOPLEFT", ns.MAIN_TABLE_LEFT or 24, -headerH)
        end
        return
    end
    local names = {}
    for i = 1, math.min(#list, 3) do
        names[#names + 1] = ns.FormatWeeklyTurnInLine(list[i])
    end
    local extra = #list > 3 and string.format(LOr("weekly_alert_more", " (+%d more)"), #list - 3) or ""
    win.weeklyAlertText:SetText(string.format(
        LOr("weekly_alert", "Turn in: %s%s"),
        table.concat(names, " · "),
        extra
    ))
    win.weeklyAlertText:Show()
    if win.weeklyAlertButton then
        win.weeklyAlertButton:Show()
    end
    if win.scrollFrame then
        win.scrollFrame:SetPoint("TOPLEFT", ns.MAIN_TABLE_LEFT or 24, -(headerH + 18))
    end
end

function ns.CheckWeeklyTurnInAlerts()
    if not ConcentrationTrackerSettings or ConcentrationTrackerSettings.notifyWeeklyTurnIn == false then
        return
    end
    EnsureLocalization()
    if type(ConcentrationTrackerSettings.weeklyTurnInNotified) ~= "table" then
        ConcentrationTrackerSettings.weeklyTurnInNotified = {}
    end
    local list = ns.CollectReadyProfessionWeeklies()
    local seen = {}
    for _, row in ipairs(list) do
        local id = tonumber(row.questID)
        if id then
            seen[id] = true
            if not ConcentrationTrackerSettings.weeklyTurnInNotified[id] then
                ConcentrationTrackerSettings.weeklyTurnInNotified[id] = true
                DeliverNotification(string.format(
                    LOr("weekly_notification", "%s is complete — turn it in!"),
                    ns.FormatWeeklyTurnInLine(row)
                ))
            end
        end
    end
    for id in pairs(ConcentrationTrackerSettings.weeklyTurnInNotified) do
        if not seen[id] then
            ConcentrationTrackerSettings.weeklyTurnInNotified[id] = nil
        end
    end
    ns.UpdateWeeklyTurnInBanner()
end

function ns.ScheduleWeeklyTurnInCheck()
    if ns.weeklyCheckPending then
        return
    end
    ns.weeklyCheckPending = true
    C_Timer.After(0.5, function()
        ns.weeklyCheckPending = false
        ns.CheckWeeklyTurnInAlerts()
        if ConcentrationWindow and ConcentrationWindow:IsShown() and type(UpdateConcentrationTimes) == "function" then
            UpdateConcentrationTimes()
        end
    end)
end

function ns.ToggleNotifications(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.enableNotifications = not ConcentrationTrackerSettings.enableNotifications
    if LanguageSettingsWindow and LanguageSettingsWindow.notificationsCheckbox then
        LanguageSettingsWindow.notificationsCheckbox:SetChecked(ConcentrationTrackerSettings.enableNotifications and true or false)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.enableNotifications then
            print(ADDON_TAG .. (L["msg_notify_on"] or "Notifications enabled."))
        else
            print(ADDON_TAG .. (L["msg_notify_off"] or "Notifications disabled."))
        end
    end
end

function ns.FocusNextToFull(opts)
    opts = opts or {}
    EnsureLocalization()
    local entry = FindNextToFullEntry(false)
    if not entry then
        print(ADDON_TAG .. (L["msg_next_none"] or "Nothing waiting to fill — all tracked concentration is full, or there is no data."))
        return
    end
    if not ConcentrationTrackerSettings then
        return
    end
    ResetAllFilters()
    ns.FilterToCharacter(entry.charName, entry.realm)
    ConcentrationTrackerSettings.selectedProfession = entry.professionName
    RefreshProfessionDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    ShowConcentrationWindow()
    if opts.notifyChat then
        local who = entry.charName
        if ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(entry.charName, entry.realm)
        end
        print(ADDON_TAG .. string.format(
            LOr("msg_focus_next", "Focused: %s (%s) — %s"),
            who,
            entry.professionName,
            entry.timeToFull or ""
        ))
    end
end

function ns.FocusLowest(opts)
    opts = opts or {}
    EnsureLocalization()
    local entry = FindLowestConcentrationEntry(false)
    if not entry then
        print(ADDON_TAG .. (L["msg_lowest_none"] or "No incomplete concentration rows — everything is full, or there is no data."))
        return
    end
    if not ConcentrationTrackerSettings then
        return
    end
    ResetAllFilters()
    ns.FilterToCharacter(entry.charName, entry.realm)
    ConcentrationTrackerSettings.selectedProfession = entry.professionName
    RefreshProfessionDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    ShowConcentrationWindow()
    if opts.notifyChat then
        local who = entry.charName
        if ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(entry.charName, entry.realm)
        end
        print(ADDON_TAG .. string.format(
            LOr("msg_focus_lowest", "Focused lowest: %s (%s) — %d%%"),
            who,
            entry.professionName,
            entry.fillPercent or 0
        ))
    end
end

function ns.ToggleHideFull(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.hideFullConcentration = not ConcentrationTrackerSettings.hideFullConcentration
    if ConcentrationWindow and ConcentrationWindow.SyncHideFullButtonText then
        ConcentrationWindow.SyncHideFullButtonText()
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.hideFullCheckbox then
        LanguageSettingsWindow.hideFullCheckbox:SetChecked(ConcentrationTrackerSettings.hideFullConcentration == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.hideFullConcentration then
            print(ADDON_TAG .. (L["msg_hidefull_on"] or "Full concentration rows hidden."))
        else
            print(ADDON_TAG .. (L["msg_hidefull_off"] or "Full concentration rows shown."))
        end
    end
end

function ns.ToggleConcentrationPercent(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.showConcentrationPercent = not ConcentrationTrackerSettings.showConcentrationPercent
    if LanguageSettingsWindow and LanguageSettingsWindow.showPercentCheckbox then
        LanguageSettingsWindow.showPercentCheckbox:SetChecked(ConcentrationTrackerSettings.showConcentrationPercent == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.showConcentrationPercent then
            print(ADDON_TAG .. (L["msg_percent_on"] or "Concentration percent shown."))
        else
            print(ADDON_TAG .. (L["msg_percent_off"] or "Concentration percent hidden."))
        end
    end
end

function ns.ToggleCompactTime(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.compactTimeFormat = not ConcentrationTrackerSettings.compactTimeFormat
    if LanguageSettingsWindow and LanguageSettingsWindow.compactTimeCheckbox then
        LanguageSettingsWindow.compactTimeCheckbox:SetChecked(ConcentrationTrackerSettings.compactTimeFormat == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.compactTimeFormat then
            print(ADDON_TAG .. (L["msg_compact_on"] or "Compact time format enabled."))
        else
            print(ADDON_TAG .. (L["msg_compact_off"] or "Compact time format disabled."))
        end
    end
end

function ns.ToggleHideStale(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.hideStaleRows = not ConcentrationTrackerSettings.hideStaleRows
    if LanguageSettingsWindow and LanguageSettingsWindow.hideStaleCheckbox then
        LanguageSettingsWindow.hideStaleCheckbox:SetChecked(ConcentrationTrackerSettings.hideStaleRows == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.hideStaleRows then
            print(ADDON_TAG .. (L["msg_hidestale_on"] or "Stale rows hidden."))
        else
            print(ADDON_TAG .. (L["msg_hidestale_off"] or "Stale rows shown."))
        end
    end
end

function ns.ToggleHighlightSoon(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.highlightSoonRows = not ConcentrationTrackerSettings.highlightSoonRows
    if LanguageSettingsWindow and LanguageSettingsWindow.highlightSoonCheckbox then
        LanguageSettingsWindow.highlightSoonCheckbox:SetChecked(ConcentrationTrackerSettings.highlightSoonRows == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.highlightSoonRows then
            print(ADDON_TAG .. (L["msg_highlight_on"] or "Soon-to-fill row highlight enabled."))
        else
            print(ADDON_TAG .. (L["msg_highlight_off"] or "Soon-to-fill row highlight disabled."))
        end
    end
end

function ns.ToggleHideMoxieOnly(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.hideMoxieOnlyRows = not ConcentrationTrackerSettings.hideMoxieOnlyRows
    if LanguageSettingsWindow and LanguageSettingsWindow.hideMoxieOnlyCheckbox then
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetChecked(ConcentrationTrackerSettings.hideMoxieOnlyRows == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.hideMoxieOnlyRows then
            print(ADDON_TAG .. (L["msg_hidemoxie_on"] or "Moxie-only rows hidden."))
        else
            print(ADDON_TAG .. (L["msg_hidemoxie_off"] or "Moxie-only rows shown."))
        end
    end
end

function ns.ToggleHighlightLow(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.highlightLowRows = not ConcentrationTrackerSettings.highlightLowRows
    if LanguageSettingsWindow and LanguageSettingsWindow.highlightLowCheckbox then
        LanguageSettingsWindow.highlightLowCheckbox:SetChecked(ConcentrationTrackerSettings.highlightLowRows == true)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.highlightLowRows then
            print(ADDON_TAG .. (L["msg_lowlight_on"] or "Low-concentration row highlight enabled."))
        else
            print(ADDON_TAG .. (L["msg_lowlight_off"] or "Low-concentration row highlight disabled."))
        end
    end
end

function ns.ToggleAutoFilterThisCharacter(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.autoFilterThisCharacter = not ConcentrationTrackerSettings.autoFilterThisCharacter
    if LanguageSettingsWindow and LanguageSettingsWindow.autoFilterCheckbox then
        LanguageSettingsWindow.autoFilterCheckbox:SetChecked(ConcentrationTrackerSettings.autoFilterThisCharacter == true)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.autoFilterThisCharacter then
            print(ADDON_TAG .. (L["msg_autoself_on"] or "The window will open filtered to this character."))
        else
            print(ADDON_TAG .. (L["msg_autoself_off"] or "The window will open without a character filter."))
        end
    end
end

function ns.ToggleRefreshOnOpen(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.refreshOnOpen = not ConcentrationTrackerSettings.refreshOnOpen
    if LanguageSettingsWindow and LanguageSettingsWindow.refreshOnOpenCheckbox then
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetChecked(ConcentrationTrackerSettings.refreshOnOpen == true)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.refreshOnOpen then
            print(ADDON_TAG .. (L["msg_refreshopen_on"] or "Opening the window will sync this character."))
        else
            print(ADDON_TAG .. (L["msg_refreshopen_off"] or "Opening the window will not sync automatically."))
        end
    end
end

function ns.SetSortColumn(token)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local column
    if type(token) == "string" and token:gsub("%s", "") ~= "" then
        column = ns.ResolveSortColumn(token)
        if not column then
            print(ADDON_TAG .. (L["msg_sort_unknown"] or "Unknown sort column. Use character, profession, moxie, concentration, or time."))
            return
        end
        if ConcentrationTrackerSettings.sortOrder == column then
            ConcentrationTrackerSettings.sortAscending = not ConcentrationTrackerSettings.sortAscending
        else
            ConcentrationTrackerSettings.sortOrder = column
            ConcentrationTrackerSettings.sortAscending = true
        end
    else
        ConcentrationTrackerSettings.sortAscending = not ConcentrationTrackerSettings.sortAscending
        column = ConcentrationTrackerSettings.sortOrder or "character"
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    local labels = {
        character = L["character"] or "Character",
        profession = L["profession"] or "Profession",
        moxie = L["moxie"] or "Moxie",
        concentration = L["concentration"] or "Concentration",
        time_remaining = L["time_remaining_sort"] or "Time to full",
    }
    local direction = ConcentrationTrackerSettings.sortAscending
        and (L["sort_ascending"] or "Sort Ascending")
        or (L["sort_descending"] or "Sort Descending")
    print(ADDON_TAG .. string.format(
        LOr("msg_sort_set", "Sort: %s (%s)"),
        labels[column] or column,
        direction
    ))
end

function ns.PrintOrSetRestoreRate(rate)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local nextRate = ns.NormalizeRestoreRate(rate)
    if not nextRate then
        local current = tonumber(ConcentrationTrackerSettings.restoreRatePerHour) or 10
        print(ADDON_TAG .. string.format(LOr("msg_rate_now", "Restore rate is %d per hour."), current))
        return
    end
    ConcentrationTrackerSettings.restoreRatePerHour = nextRate
    if LanguageSettingsWindow and LanguageSettingsWindow.restoreRateSlider then
        LanguageSettingsWindow.restoreRateSlider:SetValue(nextRate)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.restoreRateValue then
        LanguageSettingsWindow.restoreRateValue:SetText(tostring(nextRate))
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    print(ADDON_TAG .. string.format(LOr("msg_rate_set", "Restore rate: %d per hour."), nextRate))
end

function ns.ToggleLogUpdates(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.logUpdatesToChat = not ConcentrationTrackerSettings.logUpdatesToChat
    if LanguageSettingsWindow and LanguageSettingsWindow.logChatCheckbox then
        LanguageSettingsWindow.logChatCheckbox:SetChecked(ConcentrationTrackerSettings.logUpdatesToChat and true or false)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.logUpdatesToChat then
            print(ADDON_TAG .. (L["msg_chatlog_on"] or "Concentration updates will print to chat."))
        else
            print(ADDON_TAG .. (L["msg_chatlog_off"] or "Concentration updates will not print to chat."))
        end
    end
end

function ns.ToggleNotificationSound(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    if ConcentrationTrackerSettings.notificationSound == false then
        ConcentrationTrackerSettings.notificationSound = true
    else
        ConcentrationTrackerSettings.notificationSound = false
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.notifSoundCheckbox then
        LanguageSettingsWindow.notifSoundCheckbox:SetChecked(ConcentrationTrackerSettings.notificationSound ~= false)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.notificationSound ~= false then
            print(ADDON_TAG .. (L["msg_sound_on"] or "Notification sound enabled."))
        else
            print(ADDON_TAG .. (L["msg_sound_off"] or "Notification sound disabled."))
        end
    end
end

function ns.NormalizeTopCount(count)
    count = tonumber(count)
    if not count or count < 1 then
        return 5
    end
    if count > 20 then
        count = 20
    end
    return math.floor(count)
end

function ns.AverageFillPercent(quantity, maxQuantity)
    quantity = tonumber(quantity) or 0
    maxQuantity = tonumber(maxQuantity) or 0
    if maxQuantity <= 0 then
        return nil
    end
    return math.floor((quantity / maxQuantity) * 100 + 0.5)
end

function ns.NormalizeWindowScale(scale)
    scale = tonumber(scale)
    if not scale then
        return nil
    end
    if scale > 1.5 then
        scale = scale / 100
    end
    scale = math.floor(scale * 20) / 20
    if scale < 0.5 then
        scale = 0.5
    elseif scale > 1.5 then
        scale = 1.5
    end
    return scale
end

function ns.NormalizeFontSize(size)
    size = tonumber(size)
    if not size then
        return nil
    end
    size = math.floor(size + 0.5)
    if size < 10 then
        size = 10
    elseif size > 18 then
        size = 18
    end
    return size
end

function ns.CollectTopRows(count)
    count = ns.NormalizeTopCount(count)
    local list = {}
    if not ConcentrationTrackerDB then
        return list, count
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                if maxQ and maxQ > 0 then
                    list[#list + 1] = {
                        charName = charName,
                        realm = realm,
                        professionName = data.professionName or (L and L["profession"]) or "Profession",
                        quantity = q,
                        maxQuantity = maxQ,
                        fillPercent = ns.AverageFillPercent(q, maxQ) or 0,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.quantity or 0) == (b.quantity or 0) then
            return (a.charName or "") < (b.charName or "")
        end
        return (a.quantity or 0) > (b.quantity or 0)
    end)
    local top = {}
    for i = 1, math.min(count, #list) do
        top[i] = list[i]
    end
    return top, count
end

function ns.PrintTopRows(count)
    EnsureLocalization()
    local list, used = ns.CollectTopRows(count)
    if #list == 0 then
        print(ADDON_TAG .. (L["msg_top_none"] or "No tracked concentration rows."))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_top_header", "Highest concentration (%d):"), used))
    for _, row in ipairs(list) do
        local who = row.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(row.charName, row.realm)
        end
        print("  " .. string.format(
            LOr("msg_top_line", "%s (%s) — %.0f/%d (%d%%)"),
            who,
            row.professionName,
            row.quantity or 0,
            row.maxQuantity or 0,
            row.fillPercent or 0
        ))
    end
end

function ns.CollectFillAverage()
    local quantity, maxQuantity, rows = 0, 0, 0
    if ConcentrationTrackerDB then
        for key, data in pairs(ConcentrationTrackerDB) do
            if type(data) == "table" and EntryHasConcentration(data) then
                local charName, realm, skillLineID = GetEntryIdentity(key, data)
                if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                    and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local q = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                    if maxQ and maxQ > 0 then
                        quantity = quantity + q
                        maxQuantity = maxQuantity + maxQ
                        rows = rows + 1
                    end
                end
            end
        end
    end
    return ns.AverageFillPercent(quantity, maxQuantity), rows, quantity, maxQuantity
end

function ns.PrintFillAverage()
    EnsureLocalization()
    local pct, rows, quantity, maxQuantity = ns.CollectFillAverage()
    if not pct then
        print(ADDON_TAG .. (L["msg_avg_none"] or "No tracked concentration rows."))
        return
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_avg_line", "Average fill: %d%% across %d rows (%.0f/%d)."),
        pct,
        rows,
        quantity,
        maxQuantity
    ))
end

function ns.PrintOrSetWindowScale(scale)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local nextScale = ns.NormalizeWindowScale(scale)
    if not nextScale then
        local current = tonumber(ConcentrationTrackerSettings.windowScale) or 1
        print(ADDON_TAG .. string.format(LOr("msg_scale_now", "Window scale is %d%%."), math.floor(current * 100 + 0.5)))
        return
    end
    ConcentrationTrackerSettings.windowScale = nextScale
    if ConcentrationWindow then
        ConcentrationWindow:SetScale(nextScale)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.windowScaleSlider then
        LanguageSettingsWindow.windowScaleSlider:SetValue(nextScale)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.windowScaleValue then
        LanguageSettingsWindow.windowScaleValue:SetText(string.format("%d%%", nextScale * 100))
    end
    print(ADDON_TAG .. string.format(LOr("msg_scale_set", "Window scale: %d%%."), math.floor(nextScale * 100 + 0.5)))
end

function ns.PrintOrSetFontSize(size)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local nextSize = ns.NormalizeFontSize(size)
    if not nextSize then
        local current = tonumber(ConcentrationTrackerSettings.fontSize) or 12
        print(ADDON_TAG .. string.format(LOr("msg_font_now", "Font size is %d."), current))
        return
    end
    ConcentrationTrackerSettings.fontSize = nextSize
    if LanguageSettingsWindow and LanguageSettingsWindow.fontSizeSlider then
        LanguageSettingsWindow.fontSizeSlider:SetValue(nextSize)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.fontSizeValue then
        LanguageSettingsWindow.fontSizeValue:SetText(tostring(nextSize))
    end
    if type(UpdateLanguageTexts) == "function" then
        UpdateLanguageTexts()
    end
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    print(ADDON_TAG .. string.format(LOr("msg_font_set", "Font size: %d."), nextSize))
end

function ns.ToggleShowMoxie(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.showMoxie = ConcentrationTrackerSettings.showMoxie == false
    if LanguageSettingsWindow and LanguageSettingsWindow.showMoxieCheckbox then
        LanguageSettingsWindow.showMoxieCheckbox:SetChecked(ConcentrationTrackerSettings.showMoxie ~= false)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.showMoxie ~= false then
            print(ADDON_TAG .. (L["msg_showmoxie_on"] or "Moxie is shown in the profession list."))
        else
            print(ADDON_TAG .. (L["msg_showmoxie_off"] or "Moxie is hidden in the profession list."))
        end
    end
end

function ns.NormalizeOpacityPercent(percent)
    percent = tonumber(percent)
    if not percent then
        return nil
    end
    percent = math.floor(percent + 0.5)
    if percent < 0 then
        percent = 0
    elseif percent > 100 then
        percent = 100
    end
    return percent
end

function ns.PickLaterRemaining(currentSeconds, candidateSeconds)
    currentSeconds = tonumber(currentSeconds)
    candidateSeconds = tonumber(candidateSeconds) or 0
    if candidateSeconds <= 0 then
        return currentSeconds
    end
    if not currentSeconds or candidateSeconds > currentSeconds then
        return candidateSeconds
    end
    return currentSeconds
end

function ns.CollectLastToFull()
    local best
    if not ConcentrationTrackerDB then
        return nil
    end
    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and EntryHasConcentration(data) then
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if charName and IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID)
                and not (skillLineID and IsSkillLineIgnored(skillLineID)) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local q, remSec = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                remSec = tonumber(remSec) or 0
                if q < maxQ and remSec > 0 then
                    local bestSec = best and best.remainingSeconds or nil
                    if ns.PickLaterRemaining(bestSec, remSec) == remSec and (not best or remSec > best.remainingSeconds) then
                        best = {
                            charName = charName,
                            realm = realm,
                            professionName = data.professionName or (L and L["profession"]) or "Profession",
                            quantity = q,
                            maxQuantity = maxQ,
                            remainingSeconds = remSec,
                            timeToFull = FormatTimeToFullString(remSec),
                        }
                    end
                end
            end
        end
    end
    return best
end

function ns.PrintLastToFull()
    EnsureLocalization()
    local entry = ns.CollectLastToFull()
    if not entry then
        print(ADDON_TAG .. (L["msg_last_none"] or "Nothing waiting to fill — all tracked concentration is full, or there is no data."))
        return
    end
    local who = entry.charName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
        who = FormatCharacterFilterLabel(entry.charName, entry.realm)
    end
    print(ADDON_TAG .. string.format(
        LOr("msg_last_line", "Last full: %s (%s) — %s (%.0f/%d)"),
        who,
        entry.professionName,
        entry.timeToFull or "",
        entry.quantity or 0,
        entry.maxQuantity or 0
    ))
end

function ns.PrintOrSetOpacity(percent)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    local nextPct = ns.NormalizeOpacityPercent(percent)
    if not nextPct then
        local current = math.floor(((tonumber(ConcentrationTrackerSettings.transparency) or 0.8) * 100) + 0.5)
        print(ADDON_TAG .. string.format(LOr("msg_alpha_now", "Window opacity is %d%%."), current))
        return
    end
    local alpha = nextPct / 100
    ConcentrationTrackerSettings.transparency = alpha
    if ConcentrationWindow and ConcentrationWindow.SetBackdropColor then
        ConcentrationWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.SetBackdropColor then
        LanguageSettingsWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.transparencySlider then
        LanguageSettingsWindow.transparencySlider:SetValue(nextPct)
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.transparencyValue then
        LanguageSettingsWindow.transparencyValue:SetText(string.format("%d%%", nextPct))
    end
    print(ADDON_TAG .. string.format(LOr("msg_alpha_set", "Window opacity: %d%%."), nextPct))
end

function ns.ToggleHighlightThisCharacter(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    if ConcentrationTrackerSettings.highlightThisCharacter == false then
        ConcentrationTrackerSettings.highlightThisCharacter = true
    else
        ConcentrationTrackerSettings.highlightThisCharacter = false
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.highlightThisCharCheckbox then
        LanguageSettingsWindow.highlightThisCharCheckbox:SetChecked(ConcentrationTrackerSettings.highlightThisCharacter ~= false)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.highlightThisCharacter ~= false then
            print(ADDON_TAG .. (L["msg_markme_on"] or "This character's rows are marked."))
        else
            print(ADDON_TAG .. (L["msg_markme_off"] or "This character's rows are not marked."))
        end
    end
end

function ns.ToggleHighlightFull(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    if ConcentrationTrackerSettings.highlightFullRows == false then
        ConcentrationTrackerSettings.highlightFullRows = true
    else
        ConcentrationTrackerSettings.highlightFullRows = false
    end
    if LanguageSettingsWindow and LanguageSettingsWindow.highlightFullCheckbox then
        LanguageSettingsWindow.highlightFullCheckbox:SetChecked(ConcentrationTrackerSettings.highlightFullRows ~= false)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.highlightFullRows ~= false then
            print(ADDON_TAG .. (L["msg_fullhl_on"] or "Full rows are tinted."))
        else
            print(ADDON_TAG .. (L["msg_fullhl_off"] or "Full rows are not tinted."))
        end
    end
end

function ns.ToggleShowRealm(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.showRealm = not ConcentrationTrackerSettings.showRealm
    if LanguageSettingsWindow and LanguageSettingsWindow.showRealmCheckbox then
        LanguageSettingsWindow.showRealmCheckbox:SetChecked(ConcentrationTrackerSettings.showRealm and true or false)
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.showRealm then
            print(ADDON_TAG .. (L["msg_realm_on"] or "Realm names shown."))
        else
            print(ADDON_TAG .. (L["msg_realm_off"] or "Realm names hidden."))
        end
    end
end

function ns.ToggleHideInCombat(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.hideInCombat = not ConcentrationTrackerSettings.hideInCombat
    if LanguageSettingsWindow and LanguageSettingsWindow.hideInCombatCheckbox then
        LanguageSettingsWindow.hideInCombatCheckbox:SetChecked(ConcentrationTrackerSettings.hideInCombat == true)
    end
    ns.ApplyHideInCombatSetting()
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.hideInCombat then
            print(ADDON_TAG .. (L["msg_combat_on"] or "Hide in combat enabled."))
        else
            print(ADDON_TAG .. (L["msg_combat_off"] or "Hide in combat disabled."))
        end
    end
end

local function PrintTrackedCharacters()
    EnsureLocalization()
    local rows = CollectVisibleIdentityRows()
    local byChar = {}
    for _, row in ipairs(rows) do
        local key = MakeCharacterFilterKey(row.charName, row.realm)
        if key then
            local bucket = byChar[key]
            if not bucket then
                bucket = { charName = row.charName, realm = row.realm, conc = 0, moxie = 0, stale = 0 }
                byChar[key] = bucket
            end
            if row.hasConc then
                bucket.conc = bucket.conc + 1
            elseif row.moxieOnly then
                bucket.moxie = bucket.moxie + 1
            end
            if row.stale then
                bucket.stale = bucket.stale + 1
            end
        end
    end
    local list = {}
    for _, bucket in pairs(byChar) do
        list[#list + 1] = bucket
    end
    table.sort(list, function(a, b)
        return (a.charName or "") < (b.charName or "")
    end)
    if #list == 0 then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    print(ADDON_TAG .. string.format(LOr("msg_chars_header", "Tracked characters (%d):"), #list))
    for _, bucket in ipairs(list) do
        local who = bucket.charName
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm then
            who = FormatCharacterFilterLabel(bucket.charName, bucket.realm)
        end
        print("  " .. string.format(
            LOr("msg_chars_line", "%s — %d professions%s"),
            who,
            bucket.conc + bucket.moxie,
            bucket.stale > 0 and string.format(LOr("msg_chars_stale", " (%d stale)"), bucket.stale) or ""
        ))
    end
end

local function CopyTextToChat(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    if ChatEdit_GetActiveWindow then
        local edit = ChatEdit_GetActiveWindow()
        if edit then
            edit:Insert(text)
            return
        end
    end
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
        return
    end
    print(ADDON_TAG .. text)
end
ns.CopyTextToChat = CopyTextToChat

function ns.CopyCurrentCharacterStatus()
    local header, lines, err = ns.CollectCurrentCharacterStatusLines()
    if err then
        print(ADDON_TAG .. err)
        return
    end
    if #lines == 0 then
        print(ADDON_TAG .. (L["toggle_tooltip_no_data"] or "No profession data for this character yet."))
        return
    end
    local parts = { header }
    for _, row in ipairs(lines) do
        parts[#parts + 1] = row.line
    end
    CopyTextToChat(table.concat(parts, "  |  "))
end

local function CopyRowToChat(row)
    if type(row) ~= "table" or not row.entryCharName then
        return
    end
    EnsureLocalization()
    local who = row.entryCharName
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.showRealm and row.entryRealm then
        who = FormatCharacterFilterLabel(row.entryCharName, row.entryRealm)
    end
    local prof = row.entryProfessionName or (L["profession"] or "Profession")
    local text
    if row.entryMoxieOnly then
        text = string.format("%s (%s)  %s", who, prof, string.format(L["moxie_short"] or "Moxie: %d", row.entryMoxieQuantity or 0))
    else
        local conc = FormatConcentrationAmount(row.entryQuantity or 0, row.entryMaxQuantity or 0)
        local timeStr = row.entryTimeToFull or ""
        if row.entryMoxieQuantity ~= nil then
            text = string.format(
                "%s (%s): %s  %s  %s",
                who,
                prof,
                conc,
                timeStr,
                string.format(L["moxie_short"] or "Moxie: %d", row.entryMoxieQuantity)
            )
        else
            text = string.format("%s (%s): %s  %s", who, prof, conc, timeStr)
        end
    end
    CopyTextToChat(text)
end

local function UpdateThisCharButtonState()
    local btn = ConcentrationWindow and ConcentrationWindow.thisCharButton
    if not btn or not ConcentrationTrackerSettings then
        return
    end
    local meKey = GetCurrentPlayerFilterKey()
    local active = meKey and ConcentrationTrackerSettings.selectedCharacter == meKey
    local fs = btn.GetFontString and btn:GetFontString()
    if fs and fs.SetTextColor then
        if active then
            fs:SetTextColor(1, 0.82, 0)
        else
            fs:SetTextColor(1, 1, 1)
        end
    end
end

function ns.FilterToCharacter(charName, realm)
    if not ConcentrationTrackerSettings or not charName then
        return
    end
    local key = MakeCharacterFilterKey(charName, realm)
    if not key then
        return
    end
    ConcentrationTrackerSettings.selectedCharacter = key
    RefreshCharacterDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    UpdateThisCharButtonState()
end

--- ПКМ+Shift: фільтр на професію (повторний клік знімає → All).
local function FilterToProfession(professionName)
    if not ConcentrationTrackerSettings or not professionName or professionName == "" then
        return
    end
    if ConcentrationTrackerSettings.selectedProfession == professionName then
        ConcentrationTrackerSettings.selectedProfession = "All"
    else
        ConcentrationTrackerSettings.selectedProfession = professionName
    end
    RefreshProfessionDropdown()
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
end

function ns.FilterToExpansion(expansionKey)
    if not ConcentrationTrackerSettings or not expansionKey or expansionKey == "" then
        return
    end
    if ConcentrationTrackerSettings.selectedExpansion == expansionKey then
        ConcentrationTrackerSettings.selectedExpansion = "All"
    else
        ConcentrationTrackerSettings.selectedExpansion = expansionKey
    end
    OnExpansionFilterChanged()
end

local function HandleRowMouseUp(self, button)
    if button ~= "RightButton" then
        return
    end
    if IsControlKeyDown() then
        CopyRowToChat(self)
    elseif IsAltKeyDown() and self.entryExpansionKey then
        ns.FilterToExpansion(self.entryExpansionKey)
    elseif IsShiftKeyDown() and self.entryProfessionName then
        FilterToProfession(self.entryProfessionName)
    elseif self.entryCharName then
        ns.FilterToCharacter(self.entryCharName, self.entryRealm)
    end
end

--- Друк лише Moxie поточного персонажа (/conc moxie).
local function PrintCurrentCharacterMoxie()
    EnsureLocalization()
    if not ConcentrationTrackerDB or not ConcentrationTrackerSettings then
        print(ADDON_TAG .. (L["empty_state"] or "No data yet."))
        return
    end
    local cn = UnitName("player")
    if not cn or cn == "" then
        print(ADDON_TAG .. (L["error_character_name"] or "Unable to retrieve character name."))
        return
    end
    local rm = GetRealmName() or "Unknown"
    local lines = {}
    local total = 0

    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.entryChar == cn and data.entryRealm == rm then
            local _, _, skillLineID = GetEntryIdentity(key, data)
            if skillLineID and IsSkillLineIgnored(skillLineID) then
                -- skip
            elseif not IsCurrentPlayerActiveProfessionRow(cn, rm, skillLineID) then
                -- skip
            else
                local mq = GetMoxieQuantityForEntry(data, skillLineID)
                if mq ~= nil then
                    local pname = data.professionName or (L["profession"] or "Profession")
                    lines[#lines + 1] = {
                        sortKey = pname:lower(),
                        line = string.format("%s: %d", pname, mq),
                    }
                    total = total + mq
                end
            end
        end
    end

    if #lines == 0 then
        print(ADDON_TAG .. (L["msg_moxie_none"] or "No Moxie data for this character yet."))
        return
    end
    table.sort(lines, function(a, b)
        return a.sortKey < b.sortKey
    end)
    print(ADDON_TAG .. (L["msg_moxie_header"] or "Artisan's Moxie (this character):"))
    for _, item in ipairs(lines) do
        print("  " .. item.line)
    end
    print("  " .. string.format(LOr("msg_moxie_total", "Total: %d"), total))
end

-- ===========================================================
-- 4. ІНТЕРФЕЙС (UI)
-- ===========================================================
local rows = {}
local headerButtons = {}
local HEADER_KEYS = { "character", "profession", "moxie", "concentration", "time_remaining_sort", "exact_restoration_time" }
local HEADER_SORT_KEYS = { "character", "profession", "moxie", "concentration", "time_remaining", nil }
local NUM_TABLE_COLS = 6
local COL_CHAR, COL_PROF, COL_MOXIE, COL_CONC, COL_TIME, COL_EXACT = 1, 2, 3, 4, 5, 6
local COL_SETTING_KEYS = {
    [COL_CHAR] = "showColCharacter",
    [COL_PROF] = "showColProfession",
    [COL_MOXIE] = "showColMoxie",
    [COL_CONC] = "showColConcentration",
    [COL_TIME] = "showColTimeToFull",
    [COL_EXACT] = "showColRestoresAt",
}
local COLUMN_UI_ORDER = { COL_CHAR, COL_PROF, COL_MOXIE, COL_CONC, COL_TIME, COL_EXACT }
local COLUMN_GAP = 10
local PROF_ICON_SPACE = 20   -- іконка 16 + відступ 4
local ROW_ACTIONS_SPACE = 38  -- дві кнопки 16 + проміжки
local MIN_WINDOW_WIDTH = 500
local MAIN_HEADER_HEIGHT = 110 -- title + filters row + action buttons row
ns.MAIN_HEADER_HEIGHT = MAIN_HEADER_HEIGHT
ns.MAIN_TABLE_LEFT = 24
local MAIN_FOOTER_HEIGHT = 132
local MAIN_CHROME_HEIGHT = MAIN_HEADER_HEIGHT + MAIN_FOOTER_HEIGHT
local measureFontString = nil

local function SyncMainWindowContentHeight()
    if not ConcentrationWindow or not ConcentrationWindow.content then
        return
    end
    local contentWidth = math.max(400, ConcentrationWindow:GetWidth() - 70)
    ConcentrationWindow.content:SetSize(contentWidth, ConcentrationWindow:GetHeight() - MAIN_CHROME_HEIGHT)
end

local function ApplyWindowLock()
    if not ConcentrationWindow or not ConcentrationTrackerSettings then
        return
    end
    local locked = ConcentrationTrackerSettings.lockWindow == true
    ConcentrationWindow:SetMovable(not locked)
    ConcentrationWindow:SetResizable(not locked)
    if ConcentrationWindow.resizeButton then
        if locked then
            ConcentrationWindow.resizeButton:Hide()
        else
            ConcentrationWindow.resizeButton:Show()
        end
    end
end

function ns.ToggleWindowLock(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.lockWindow = not ConcentrationTrackerSettings.lockWindow
    ApplyWindowLock()
    if LanguageSettingsWindow and LanguageSettingsWindow.lockWindowCheckbox then
        LanguageSettingsWindow.lockWindowCheckbox:SetChecked(ConcentrationTrackerSettings.lockWindow == true)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.lockWindow then
            print(ADDON_TAG .. (L["msg_window_locked"] or "Main window locked."))
        else
            print(ADDON_TAG .. (L["msg_window_unlocked"] or "Main window unlocked."))
        end
    end
end

function ns.ToggleMinimapButton(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureMinimapSettings()
    ConcentrationTrackerSettings.minimap.hide = not ConcentrationTrackerSettings.minimap.hide
    ApplyMinimapButtonVisibility()
    if LanguageSettingsWindow and LanguageSettingsWindow.minimapHideCheckbox then
        LanguageSettingsWindow.minimapHideCheckbox:SetChecked(ConcentrationTrackerSettings.minimap.hide == true)
    end
    if opts.notifyChat then
        EnsureLocalization()
        if ConcentrationTrackerSettings.minimap.hide then
            print(ADDON_TAG .. (L["msg_minimap_hidden"] or "Minimap button hidden."))
        else
            print(ADDON_TAG .. (L["msg_minimap_shown"] or "Minimap button shown."))
        end
    end
end

--- Ховає головне вікно на час бою; OnHide не скидає прапорець, поки ns.hidingForCombat.
function ns.HideMainWindowForCombat()
    if not ConcentrationWindow or not ConcentrationWindow:IsShown() then
        return
    end
    ns.hidingForCombat = true
    ns.hiddenForCombat = true
    ConcentrationWindow:Hide()
    ns.hidingForCombat = false
end

function ns.RestoreMainWindowAfterCombat()
    if not ns.hiddenForCombat then
        return
    end
    ns.hiddenForCombat = false
    if ConcentrationTrackerSettings and ConcentrationTrackerSettings.hideInCombat then
        ShowConcentrationWindow()
    end
end

function ns.ApplyHideInCombatSetting()
    if not ConcentrationTrackerSettings then
        return
    end
    if ConcentrationTrackerSettings.hideInCombat then
        if UnitAffectingCombat and UnitAffectingCombat("player") then
            ns.HideMainWindowForCombat()
        end
    elseif ns.hiddenForCombat then
        ns.hiddenForCombat = false
        ShowConcentrationWindow()
    end
end

local function ApplyMainWindowVisualSettings()
    if not ConcentrationWindow or not ConcentrationTrackerSettings then
        return
    end
    local scale = (ConcentrationTrackerSettings.windowScale and ConcentrationTrackerSettings.windowScale > 0)
        and ConcentrationTrackerSettings.windowScale or 1
    ConcentrationWindow:SetScale(scale)
    ConcentrationWindow:SetAlpha(1)
    ConcentrationWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
    if ConcentrationWindow.Bg then ConcentrationWindow.Bg:SetAlpha(1) end
    ApplyWindowLock()
end

local function UpdateMainWindowTitle()
    if not ConcentrationWindow or not ConcentrationWindow.title then
        return
    end
    EnsureLocalization()
    local base = (L and L["title"]) or "Concentration"
    local parts = {}
    if ConcentrationTrackerSettings then
        local exp = ConcentrationTrackerSettings.selectedExpansion
        if exp and exp ~= "All" then
            parts[#parts + 1] = GetExpansionDropdownLabel(exp)
        end
        local prof = ConcentrationTrackerSettings.selectedProfession
        if prof and prof ~= "All" then
            parts[#parts + 1] = prof
        end
        local charSel = ConcentrationTrackerSettings.selectedCharacter
        if charSel and charSel ~= "All" then
            local cName, cRealm = strsplit(DB_KEY_SEP, charSel)
            parts[#parts + 1] = FormatCharacterFilterLabel(cName, cRealm)
        end
        local search = ns.GetSearchText and ns.GetSearchText() or ""
        if search ~= "" then
            parts[#parts + 1] = "\"" .. search .. "\""
        end
        local weeklyReady = ns.CollectReadyProfessionWeeklies()
        if #weeklyReady > 0 then
            parts[#parts + 1] = string.format(LOr("title_weekly", "Turn in %d"), #weeklyReady)
        end
    end
    if #parts > 0 then
        ConcentrationWindow.title:SetText(base .. "  |  " .. table.concat(parts, " · "))
    else
        ConcentrationWindow.title:SetText(base)
    end
    local maxW = (ConcentrationWindow:GetWidth() or 500) - 80
    if maxW > 80 then
        ConcentrationWindow.title:SetWidth(maxW)
        ConcentrationWindow.title:SetJustifyH("CENTER")
    end
end

local function ResetAddonUI(opts)
    opts = opts or {}
    if not ConcentrationTrackerSettings then
        return
    end
    ConcentrationTrackerSettings.windowPosition = nil
    ConcentrationTrackerSettings.windowSize = nil
    ConcentrationTrackerSettings.settingsWindowPosition = nil
    ConcentrationTrackerSettings.lockWindow = false
    if ConcentrationWindow then
        ConcentrationWindow:ClearAllPoints()
        ConcentrationWindow:SetPoint("CENTER")
        ConcentrationWindow:SetSize(MIN_WINDOW_WIDTH, 500)
        ApplyWindowLock()
        SyncMainWindowContentHeight()
    end
    if LanguageSettingsWindow then
        LanguageSettingsWindow:ClearAllPoints()
        LanguageSettingsWindow:SetPoint("CENTER")
        if LanguageSettingsWindow.lockWindowCheckbox then
            LanguageSettingsWindow.lockWindowCheckbox:SetChecked(false)
        end
    end
    if opts.notifyChat then
        EnsureLocalization()
        print(ADDON_TAG .. (L["msg_resetui"] or "Window position and size reset."))
    end
end

local function MeasureTextWidth(text, fontPath, fontSize)
    if not measureFontString then
        measureFontString = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    measureFontString:SetFont(fontPath or ADDON_FONT, fontSize or 12, "")
    measureFontString:SetText(text or "")
    return measureFontString:GetStringWidth() + 4
end

local function EnsureColumnSettings()
    if not ConcentrationTrackerSettings then
        return
    end
    for _, key in pairs(COL_SETTING_KEYS) do
        if ConcentrationTrackerSettings[key] == nil then
            ConcentrationTrackerSettings[key] = true
        end
    end
end

local function GetColumnVisibility()
    EnsureColumnSettings()
    local vis = {}
    for col, key in pairs(COL_SETTING_KEYS) do
        vis[col] = ConcentrationTrackerSettings[key] ~= false
    end
    return vis
end

local function CountVisibleColumns(colVis)
    local n = 0
    for col = 1, NUM_TABLE_COLS do
        if colVis[col] then
            n = n + 1
        end
    end
    return n
end

function ns.PrintColumnVisibility()
    EnsureLocalization()
    if not ConcentrationTrackerSettings then
        return
    end
    local order = {
        { key = "showColCharacter", label = L["character"] or "Character" },
        { key = "showColProfession", label = L["profession"] or "Profession" },
        { key = "showColMoxie", label = L["moxie"] or "Moxie" },
        { key = "showColConcentration", label = L["concentration"] or "Concentration" },
        { key = "showColTimeToFull", label = L["time_remaining_sort"] or "Time to full" },
        { key = "showColRestoresAt", label = L["exact_restoration_time"] or "Restores at" },
    }
    print(ADDON_TAG .. (L["msg_col_header"] or "Table columns:"))
    for _, col in ipairs(order) do
        local shown = ConcentrationTrackerSettings[col.key] ~= false
        print("  " .. string.format(
            LOr("msg_col_line", "%s: %s"),
            col.label,
            shown and (L["msg_col_shown"] or "shown") or (L["msg_col_hidden"] or "hidden")
        ))
    end
end

function ns.ToggleTableColumn(token)
    if not ConcentrationTrackerSettings then
        return
    end
    EnsureLocalization()
    if type(token) ~= "string" or token:gsub("%s", "") == "" then
        ns.PrintColumnVisibility()
        return
    end
    local settingKey = ns.ResolveColumnSetting(token)
    if not settingKey then
        print(ADDON_TAG .. (L["msg_col_unknown"] or "Unknown column. Use character, profession, moxie, concentration, time, or exact."))
        return
    end
    local colIndex
    for col, key in pairs(COL_SETTING_KEYS) do
        if key == settingKey then
            colIndex = col
            break
        end
    end
    local shown = ConcentrationTrackerSettings[settingKey] ~= false
    if shown and colIndex and not ns.CanHideAnotherColumn(CountVisibleColumns(GetColumnVisibility())) then
        print(ADDON_TAG .. (L["col_keep_one_visible"] or "At least one column must remain visible."))
        return
    end
    ConcentrationTrackerSettings[settingKey] = not shown
    if colIndex and LanguageSettingsWindow and LanguageSettingsWindow.columnCheckboxes then
        local cb = LanguageSettingsWindow.columnCheckboxes[colIndex]
        if cb then
            cb:SetChecked(ConcentrationTrackerSettings[settingKey] ~= false)
        end
    end
    MarkLayoutDirty()
    if type(UpdateConcentrationTimes) == "function" then
        UpdateConcentrationTimes()
    end
    local labels = {
        showColCharacter = L["character"] or "Character",
        showColProfession = L["profession"] or "Profession",
        showColMoxie = L["moxie"] or "Moxie",
        showColConcentration = L["concentration"] or "Concentration",
        showColTimeToFull = L["time_remaining_sort"] or "Time to full",
        showColRestoresAt = L["exact_restoration_time"] or "Restores at",
    }
    local label = labels[settingKey] or settingKey
    if ConcentrationTrackerSettings[settingKey] ~= false then
        print(ADDON_TAG .. string.format(LOr("msg_col_on", "%s column shown."), label))
    else
        print(ADDON_TAG .. string.format(LOr("msg_col_off", "%s column hidden."), label))
    end
end

local function ApplyVisibilityToColWidths(colWidths, colVis)
    for col = 1, NUM_TABLE_COLS do
        if not colVis[col] then
            colWidths[col] = 0
        end
    end
end

local function ComputeTotalContentWidth(colWidths, colVis)
    local total = ROW_ACTIONS_SPACE
    local hadPrev = false
    for _, col in ipairs(COLUMN_UI_ORDER) do
        local w = colWidths[col] or 0
        if colVis[col] and w > 0 then
            if hadPrev then
                total = total + COLUMN_GAP
            end
            if col == COL_PROF and colVis[COL_CHAR] then
                total = total + PROF_ICON_SPACE
            end
            total = total + w
            hadPrev = true
        end
    end
    return total
end

local function PositionTableHeaders(colWidths, colVis)
    if ConcentrationWindow.headerSpacer then
        ConcentrationWindow.headerSpacer:Hide()
    end
    local prevHeader = nil
    for _, col in ipairs(COLUMN_UI_ORDER) do
        local hb = headerButtons[col]
        if not hb then
            break
        end
        local w = colVis[col] and (colWidths[col] or 0) or 0
        if w < 1 then
            hb:Hide()
        else
            hb:Show()
            hb:SetSize(w, 24)
            hb:ClearAllPoints()
            if not prevHeader then
                hb:SetPoint("TOPLEFT", 0, 0)
            elseif col == COL_PROF and colVis[COL_CHAR] and ConcentrationWindow.headerSpacer then
                ConcentrationWindow.headerSpacer:Show()
                ConcentrationWindow.headerSpacer:ClearAllPoints()
                ConcentrationWindow.headerSpacer:SetPoint("LEFT", prevHeader, "RIGHT", COLUMN_GAP, 0)
                ConcentrationWindow.headerSpacer:SetSize(PROF_ICON_SPACE, 20)
                hb:SetPoint("LEFT", ConcentrationWindow.headerSpacer, "RIGHT", 0, 0)
            else
                hb:SetPoint("LEFT", prevHeader, "RIGHT", COLUMN_GAP, 0)
            end
            prevHeader = hb
        end
    end
end

local function ApplyRowColumnLayout(row, colWidths, colVis, rowHeight)
    rowHeight = rowHeight or row:GetHeight() or 22

    local function setCell(frame, w, visible)
        if not frame then
            return
        end
        if visible and w > 0 then
            frame:SetSize(w, rowHeight)
            frame:Show()
        else
            frame:SetSize(0.001, rowHeight)
            frame:Hide()
        end
    end

    setCell(row.cellChar, colWidths[COL_CHAR], colVis[COL_CHAR])
    if row.charText then
        row.charText:SetWidth(math.max(colWidths[COL_CHAR] - 8, 1))
    end

    local profVisible = colVis[COL_PROF] and colWidths[COL_PROF] > 0
    if row.profIcon then
        if profVisible then
            row.profIcon:Show()
            row.profIcon:ClearAllPoints()
            if colVis[COL_CHAR] and colWidths[COL_CHAR] > 0 and row.cellChar:IsShown() then
                row.profIcon:SetPoint("LEFT", row.cellChar, "RIGHT", COLUMN_GAP, 0)
            else
                row.profIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
            end
        else
            row.profIcon:Hide()
        end
    end

    setCell(row.cellProf, colWidths[COL_PROF], profVisible)
    if row.profText then
        row.profText:SetWidth(math.max(colWidths[COL_PROF], 1))
    end

    local showMoxieCol = colVis[COL_MOXIE] and colWidths[COL_MOXIE] > 0
    setCell(row.cellMoxie, colWidths[COL_MOXIE], showMoxieCol)
    if row.moxieColText then
        row.moxieColText:SetWidth(math.max(colWidths[COL_MOXIE], 1))
    end

    setCell(row.cellConc, colWidths[COL_CONC], colVis[COL_CONC])
    setCell(row.cellTime, colWidths[COL_TIME], colVis[COL_TIME])
    setCell(row.cellExact, colWidths[COL_EXACT], colVis[COL_EXACT])

    if row.concBarBg then
        row.concBarBg:SetWidth(math.max(colWidths[COL_CONC], 1))
    end
    if row.timeToFullText then
        row.timeToFullText:SetWidth(math.max(colWidths[COL_TIME], 1))
    end
    if row.exactTimeText then
        row.exactTimeText:SetWidth(math.max(colWidths[COL_EXACT], 1))
    end

    local lastFrame = row
    if colVis[COL_CHAR] and colWidths[COL_CHAR] > 0 and row.cellChar:IsShown() then
        row.cellChar:ClearAllPoints()
        row.cellChar:SetPoint("LEFT", row, "LEFT", 0, 0)
        lastFrame = row.cellChar
    end
    if profVisible and row.cellProf:IsShown() then
        row.cellProf:ClearAllPoints()
        if row.profIcon and row.profIcon:IsShown() then
            row.cellProf:SetPoint("LEFT", row.profIcon, "RIGHT", 4, 0)
        elseif lastFrame == row then
            row.cellProf:SetPoint("LEFT", row, "LEFT", 0, 0)
        else
            row.cellProf:SetPoint("LEFT", lastFrame, "RIGHT", COLUMN_GAP, 0)
        end
        lastFrame = row.cellProf
    end
    if showMoxieCol and row.cellMoxie:IsShown() then
        row.cellMoxie:ClearAllPoints()
        row.cellMoxie:SetPoint("LEFT", lastFrame, "RIGHT", COLUMN_GAP, 0)
        lastFrame = row.cellMoxie
    end
    if colVis[COL_CONC] and colWidths[COL_CONC] > 0 and row.cellConc:IsShown() then
        row.cellConc:ClearAllPoints()
        row.cellConc:SetPoint("LEFT", lastFrame, "RIGHT", COLUMN_GAP, 0)
        lastFrame = row.cellConc
    end
    if colVis[COL_TIME] and colWidths[COL_TIME] > 0 and row.cellTime:IsShown() then
        row.cellTime:ClearAllPoints()
        row.cellTime:SetPoint("LEFT", lastFrame, "RIGHT", COLUMN_GAP, 0)
        lastFrame = row.cellTime
    end
    if colVis[COL_EXACT] and colWidths[COL_EXACT] > 0 and row.cellExact:IsShown() then
        row.cellExact:ClearAllPoints()
        row.cellExact:SetPoint("LEFT", lastFrame, "RIGHT", COLUMN_GAP, 0)
        lastFrame = row.cellExact
    end

    if row.stopTrackingButton then
        row.stopTrackingButton:ClearAllPoints()
        row.stopTrackingButton:SetPoint("LEFT", lastFrame, "RIGHT", 5, 0)
    end
    if row.deleteButton and row.stopTrackingButton then
        row.deleteButton:ClearAllPoints()
        row.deleteButton:SetPoint("LEFT", row.stopTrackingButton, "RIGHT", 5, 0)
    end
end
local RegisterDeleteEntryDialog
local RegisterStopTrackingDialog
local RegisterClearIgnoredDialog
local RegisterResetConfirmDialog
local RefreshIgnoredProfessionsSettingsUI

function ShowConcentrationWindow()
    if not ConcentrationWindow then
        -- Створюємо вікно (ширина автоматично підлаштовується під контент)
        ConcentrationWindow = CreateFrame("Frame", "ConcentrationWindow", UIParent, "PortraitFrameTemplate,BackdropTemplate")
        if ConcentrationWindow.TitleText then ConcentrationWindow.TitleText:Hide() end
        if ConcentrationWindow.TitleContainer and ConcentrationWindow.TitleContainer.TitleText then
            ConcentrationWindow.TitleContainer.TitleText:Hide()
        end
        if ConcentrationWindow.PortraitContainer and ConcentrationWindow.PortraitContainer.portrait then
            SetPortraitTexture(ConcentrationWindow.PortraitContainer.portrait, "player")
        end
        ConcentrationWindow:SetClampedToScreen(true)
        local savedW = ConcentrationTrackerSettings.windowSize and ConcentrationTrackerSettings.windowSize[1]
        local savedH = ConcentrationTrackerSettings.windowSize and ConcentrationTrackerSettings.windowSize[2]
        local winW = (savedW and savedW >= MIN_WINDOW_WIDTH) and savedW or MIN_WINDOW_WIDTH
        local winH = savedH or 440
        if not ConcentrationTrackerSettings.retailLayoutV2 then
            winH = 440
            ConcentrationTrackerSettings.retailLayoutV2 = true
        end
        ConcentrationWindow:SetSize(winW, winH)
        if ConcentrationTrackerSettings.windowPosition and ConcentrationTrackerSettings.windowPosition[1] then
            local p = ConcentrationTrackerSettings.windowPosition
            ConcentrationWindow:ClearAllPoints()
            ConcentrationWindow:SetPoint(p[1], UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
        else
            ConcentrationWindow:SetPoint("CENTER")
        end
        local scale = (ConcentrationTrackerSettings.windowScale and ConcentrationTrackerSettings.windowScale > 0) and ConcentrationTrackerSettings.windowScale or 1
        ConcentrationWindow:SetScale(scale)
        ConcentrationWindow:SetMovable(true)
        ConcentrationWindow:EnableMouse(true)
        ConcentrationWindow:RegisterForDrag("LeftButton")
        ConcentrationWindow:SetScript("OnDragStart", function(self)
            if ConcentrationTrackerSettings and ConcentrationTrackerSettings.lockWindow then
                return
            end
            self:StartMoving()
        end)
        ConcentrationWindow:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
            ConcentrationTrackerSettings.windowPosition = { point, relativePoint, xOfs, yOfs }
        end)
        ConcentrationWindow:SetScript("OnHide", function(self)
            if not ns.hidingForCombat then
                ns.hiddenForCombat = false
            end
            if ConcentrationTrackerSettings then
                local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
                ConcentrationTrackerSettings.windowPosition = { point, relativePoint, xOfs, yOfs }
                ConcentrationTrackerSettings.windowSize = { self:GetWidth(), self:GetHeight() }
            end
        end)
        ConcentrationWindow:SetResizable(true)
        ConcentrationWindow:SetResizeBounds(600, 380, UIParent:GetWidth(), UIParent:GetHeight())
        ConcentrationWindow:SetScript("OnSizeChanged", function(self)
            SyncMainWindowContentHeight()
            UpdateMainWindowTitle()
            -- Relayout on the next rendered frame; avoid re-entering layout
            -- when the measured minimum itself changes the window width.
            self.responsiveResizePending = true
        end)

        -- Кнопка для зміни розміру
        ConcentrationWindow.resizeButton = CreateFrame("Button", nil, ConcentrationWindow)
        ConcentrationWindow.resizeButton:SetSize(16, 16)
        ConcentrationWindow.resizeButton:SetPoint("BOTTOMRIGHT")
        ConcentrationWindow.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        ConcentrationWindow.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        ConcentrationWindow.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        ConcentrationWindow.resizeButton:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                if ConcentrationTrackerSettings and ConcentrationTrackerSettings.lockWindow then
                    return
                end
                ConcentrationWindow:StartSizing("BOTTOMRIGHT")
                self:GetHighlightTexture():Hide()
            end
        end)
        ConcentrationWindow.resizeButton:SetScript("OnMouseUp", function(self)
            ConcentrationWindow:StopMovingOrSizing()
            self:GetHighlightTexture():Show()
            SyncMainWindowContentHeight()
            if ConcentrationTrackerSettings then
                ConcentrationTrackerSettings.windowSize = { ConcentrationWindow:GetWidth(), ConcentrationWindow:GetHeight() }
            end
        end)

        -- Match the textured outer shell used by Retail's bank and auction UI.
        ConcentrationWindow:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
            tile = true, tileSize = 256,
            insets = {left=4, right=4, top=24, bottom=4},
        })
        ConcentrationWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
        tinsert(UISpecialFrames, "ConcentrationWindow")

        -- Заголовок
        ConcentrationWindow.title = ConcentrationWindow.TitleContainer.TitleText
        ConcentrationWindow.title:Show()
        ConcentrationWindow.title:ClearAllPoints()
        local titleFontSize = (ConcentrationTrackerSettings and ConcentrationTrackerSettings.fontSize) or 12
        ConcentrationWindow.title:SetFont(ADDON_FONT, titleFontSize + 1, "")
        ConcentrationWindow.title:SetTextColor(1, 0.82, 0, 1)
        ConcentrationWindow.title:SetPoint("CENTER", ConcentrationWindow.TitleContainer, "CENTER", 0, 0)
        ConcentrationWindow.title:SetJustifyH("CENTER")
        ConcentrationWindow.title:SetText(LOr("title", "Character Concentration"))

        -- Хрестик закрити
        ConcentrationWindow.closeButton = ConcentrationWindow.CloseButton or CreateFrame("Button", nil, ConcentrationWindow, "UIPanelCloseButton")
        ConcentrationWindow.closeButton:SetPoint("TOPRIGHT", -2, -2)
        ConcentrationWindow.closeButton:SetScript("OnClick", function()
            ConcentrationWindow:Hide()
        end)

        -- Кнопка «Оновити»
        ConcentrationWindow.refreshButton = CreateFrame("Button", nil, ConcentrationWindow, "UIPanelButtonTemplate")
        ConcentrationWindow.refreshButton:SetSize(90, 25)
        ConcentrationWindow.refreshButton:SetPoint("BOTTOMRIGHT", -20, 14)
        ConcentrationWindow.refreshButton:SetText(LOr("refresh", "Refresh"))
        ConcentrationWindow.refreshButton:SetScript("OnClick", function()
            PerformConcentrationRefresh()
        end)
        ConcentrationWindow.refreshButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["refresh_tooltip"] or "Refresh data now")
        end)
        ConcentrationWindow.refreshButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Кнопка налаштувань
        ConcentrationWindow.settingsButton = CreateFrame("Button", nil, ConcentrationWindow, "UIPanelButtonTemplate")
        ConcentrationWindow.settingsButton:SetSize(110, 25)
        ConcentrationWindow.settingsButton:SetPoint("BOTTOMLEFT", 16, 14)
        ConcentrationWindow.settingsButton:SetText(LOr("settings", "Settings"))
        ConcentrationWindow.settingsButton:SetScript("OnClick", function()
            CreateLanguageSettingsWindow()
        end)

        ConcentrationWindow.expansionDropdown = CreateFrame("Frame", "ConcentrationTrackerExpansionDropdown", ConcentrationWindow, "UIDropDownMenuTemplate")
        ConcentrationWindow.expansionDropdown:SetPoint("TOPLEFT", 0, -36)
        UIDropDownMenu_SetWidth(ConcentrationWindow.expansionDropdown, 110)
        InitializeExpansionDropdown(ConcentrationWindow.expansionDropdown, OnExpansionFilterChanged)

        -- Випадаючий список для вибору професії
        ConcentrationWindow.professionDropdown = CreateFrame("Frame", "ConcentrationTrackerProfessionDropdown", ConcentrationWindow, "UIDropDownMenuTemplate")
        ConcentrationWindow.professionDropdown:SetPoint("LEFT", ConcentrationWindow.expansionDropdown, "RIGHT", 0, 0)
        UIDropDownMenu_SetWidth(ConcentrationWindow.professionDropdown, 120)
        UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, LOr("select_profession", "Select Profession"))

        function InitializeProfessionDropdown()
            SanitizeSelectedProfessionFilter()
            local info = UIDropDownMenu_CreateInfo()
            info.func = function(self)
                ConcentrationTrackerSettings.selectedProfession = self.value
                UIDropDownMenu_SetSelectedValue(ConcentrationWindow.professionDropdown, self.value)
                UpdateConcentrationTimes()
            end

            -- "Всі професії"
            info.text = LOr("all_professions", "All Professions")
            info.value = "All"
            info.checked = (ConcentrationTrackerSettings.selectedProfession == "All")
            UIDropDownMenu_AddButton(info)

            -- Збираємо унікальні професії (без порожніх імен), з урахуванням фільтра доповнення
            local professions = {}
            for _, data in pairs(ConcentrationTrackerDB) do
                local sid = tonumber(data.entrySkillLine or data.professionID)
                if EntryPassesExpansionFilter(data, sid) then
                    local pn = data.professionName
                    if type(pn) == "string" and pn ~= "" then
                        professions[pn] = true
                    end
                end
            end

            local professionList = {}
            for professionName, _ in pairs(professions) do
                table.insert(professionList, professionName)
            end
            table.sort(professionList)

            for _, professionName in ipairs(professionList) do
                info.text = professionName
                info.value = professionName
                info.checked = (ConcentrationTrackerSettings.selectedProfession == professionName)
                UIDropDownMenu_AddButton(info)
            end
        end

        UIDropDownMenu_Initialize(ConcentrationWindow.professionDropdown, InitializeProfessionDropdown)
        UIDropDownMenu_SetSelectedValue(ConcentrationWindow.professionDropdown, ConcentrationTrackerSettings.selectedProfession)

        ConcentrationWindow.characterDropdown = CreateFrame("Frame", "ConcentrationTrackerCharacterDropdown", ConcentrationWindow, "UIDropDownMenuTemplate")
        ConcentrationWindow.characterDropdown:SetPoint("LEFT", ConcentrationWindow.professionDropdown, "RIGHT", 0, 0)
        UIDropDownMenu_SetWidth(ConcentrationWindow.characterDropdown, 120)
        UIDropDownMenu_SetText(ConcentrationWindow.characterDropdown, LOr("all_characters", "All Characters"))

        function InitializeCharacterDropdown()
            SanitizeSelectedCharacterFilter()
            local info = UIDropDownMenu_CreateInfo()
            info.func = function(self)
                ConcentrationTrackerSettings.selectedCharacter = self.value
                UIDropDownMenu_SetSelectedValue(ConcentrationWindow.characterDropdown, self.value)
                MarkLayoutDirty()
                UpdateConcentrationTimes()
            end

            info.text = LOr("all_characters", "All Characters")
            info.value = "All"
            info.checked = (ConcentrationTrackerSettings.selectedCharacter == "All")
            UIDropDownMenu_AddButton(info)

            local characters = {}
            for key, data in pairs(ConcentrationTrackerDB) do
                if type(data) == "table" then
                    local charName, realm, sid = GetEntryIdentity(key, data)
                    if charName and EntryPassesExpansionFilter(data, sid) then
                        local filterKey = MakeCharacterFilterKey(charName, realm)
                        if filterKey and not characters[filterKey] then
                            characters[filterKey] = FormatCharacterFilterLabel(charName, realm)
                        end
                    end
                end
            end

            local characterList = {}
            for filterKey, label in pairs(characters) do
                characterList[#characterList + 1] = { key = filterKey, label = label }
            end
            table.sort(characterList, function(a, b)
                return a.label:lower() < b.label:lower()
            end)

            for _, item in ipairs(characterList) do
                info.text = item.label
                info.value = item.key
                info.checked = (ConcentrationTrackerSettings.selectedCharacter == item.key)
                UIDropDownMenu_AddButton(info)
            end
        end

        UIDropDownMenu_Initialize(ConcentrationWindow.characterDropdown, InitializeCharacterDropdown)
        UIDropDownMenu_SetSelectedValue(ConcentrationWindow.characterDropdown, ConcentrationTrackerSettings.selectedCharacter or "All")
        if ConcentrationTrackerSettings.selectedCharacter == "All" then
            UIDropDownMenu_SetText(ConcentrationWindow.characterDropdown, LOr("all_characters", "All Characters"))
        else
            local cName, cRealm = strsplit(DB_KEY_SEP, ConcentrationTrackerSettings.selectedCharacter or "")
            UIDropDownMenu_SetText(ConcentrationWindow.characterDropdown, FormatCharacterFilterLabel(cName, cRealm))
        end

        ConcentrationWindow.retailFilters = {}
        local filterSpecs = {
            { key = "selectedExpansion", label = "All expansions", legacy = ConcentrationWindow.expansionDropdown },
            { key = "selectedProfession", label = "All professions", legacy = ConcentrationWindow.professionDropdown },
            { key = "selectedCharacter", label = "All characters", legacy = ConcentrationWindow.characterDropdown },
        }
        for index, spec in ipairs(filterSpecs) do
            spec.legacy:Hide()
            local dropdown = CreateFrame("DropdownButton", nil, ConcentrationWindow, "WowStyle1DropdownTemplate")
            dropdown:SetSize(176, 24)
            if index == 1 then
                dropdown:SetPoint("TOPLEFT", 64, -36)
            else
                dropdown:SetPoint("LEFT", ConcentrationWindow.retailFilters[index - 1], "RIGHT", 12, 0)
            end
            dropdown.filterKey = spec.key
            dropdown.emptyLabel = spec.label
            dropdown:SetupMenu(function(_, root)
                local options = { { value = "All", label = spec.label } }
                local seen = { All = true }
                if spec.key == "selectedExpansion" then
                    for _, value in ipairs(CollectExpansionFilterOptions()) do
                        if value ~= "All" then options[#options + 1] = {value=value, label=GetExpansionDropdownLabel(value)} end
                    end
                else
                    for key, data in pairs(ConcentrationTrackerDB or {}) do
                        if type(data) == "table" then
                            local cn, rm, sid = GetEntryIdentity(key, data)
                            local value, label
                            if spec.key == "selectedCharacter" and cn and rm then
                                value, label = MakeCharacterFilterKey(cn, rm), FormatCharacterFilterLabel(cn, rm)
                            elseif spec.key == "selectedProfession" and EntryPassesExpansionFilter(data, sid) then
                                value, label = data.professionName, data.professionName
                            end
                            if value and not seen[value] then
                                seen[value] = true
                                options[#options + 1] = {value=value, label=label}
                            end
                        end
                    end
                    table.sort(options, function(a,b)
                        if a.value == "All" then return b.value ~= "All" end
                        if b.value == "All" then return false end
                        return a.label < b.label
                    end)
                end
                for _, item in ipairs(options) do
                    root:CreateRadio(item.label,
                        function(value) return (ConcentrationTrackerSettings[spec.key] or "All") == value end,
                        function(value)
                            ConcentrationTrackerSettings[spec.key] = value
                            MarkLayoutDirty()
                            UpdateConcentrationTimes()
                        end, item.value)
                end
            end)
            ConcentrationWindow.retailFilters[index] = dropdown
        end

        -- Другий рядок: компактні кнопки фільтрів (сортування — лише через заголовки колонок)
        local function FitToolbarButton(btn, text, minW)
            btn:SetText(text or "")
            local tw = btn:GetTextWidth() or 0
            btn:SetWidth(math.max(minW or 64, tw + 14))
        end

        ConcentrationWindow.thisCharButton = CreateFrame("Button", nil, ConcentrationWindow, "UIPanelButtonTemplate")
        ConcentrationWindow.thisCharButton:SetPoint("TOPLEFT", 16, -70)
        ConcentrationWindow.thisCharButton:SetHeight(20)
        FitToolbarButton(ConcentrationWindow.thisCharButton, LOr("this_character", "This char"), 64)
        ConcentrationWindow.thisCharButton:SetScript("OnClick", function()
            local meKey = GetCurrentPlayerFilterKey()
            if not meKey then
                return
            end
            if ConcentrationTrackerSettings.selectedCharacter == meKey then
                ConcentrationTrackerSettings.selectedCharacter = "All"
            else
                ConcentrationTrackerSettings.selectedCharacter = meKey
            end
            RefreshCharacterDropdown()
            MarkLayoutDirty()
            UpdateConcentrationTimes()
            UpdateThisCharButtonState()
        end)
        ConcentrationWindow.thisCharButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(LOr("this_character_tooltip", "Toggle filter to the logged-in character."))
            GameTooltip:Show()
        end)
        ConcentrationWindow.thisCharButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        ConcentrationWindow.hideFullButton = CreateFrame("Button", nil, ConcentrationWindow, "UIPanelButtonTemplate")
        ConcentrationWindow.hideFullButton:SetPoint("LEFT", ConcentrationWindow.thisCharButton, "RIGHT", 4, 0)
        ConcentrationWindow.hideFullButton:SetHeight(20)
        local function SyncHideFullButtonText()
            local on = ConcentrationTrackerSettings.hideFullConcentration == true
            FitToolbarButton(
                ConcentrationWindow.hideFullButton,
                on and LOr("show_full_short", "Show full") or LOr("hide_full_short", "Hide full"),
                64
            )
        end
        SyncHideFullButtonText()
        ConcentrationWindow.SyncHideFullButtonText = SyncHideFullButtonText
        ConcentrationWindow.hideFullButton:SetScript("OnClick", function()
            ns.ToggleHideFull()
        end)
        ConcentrationWindow.hideFullButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(LOr("hide_full_concentration_tooltip", "Hide rows that are already at maximum concentration."))
            GameTooltip:Show()
        end)
        ConcentrationWindow.hideFullButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        ConcentrationWindow.resetFiltersButton = CreateFrame("Button", nil, ConcentrationWindow, "UIPanelButtonTemplate")
        ConcentrationWindow.resetFiltersButton:SetPoint("LEFT", ConcentrationWindow.hideFullButton, "RIGHT", 4, 0)
        ConcentrationWindow.resetFiltersButton:SetHeight(20)
        FitToolbarButton(
            ConcentrationWindow.resetFiltersButton,
            LOr("reset_filters_short", "Clear"),
            56
        )
        ConcentrationWindow.resetFiltersButton:SetScript("OnClick", function()
            ResetAllFilters()
            UpdateThisCharButtonState()
            if ConcentrationWindow.SyncHideFullButtonText then
                ConcentrationWindow.SyncHideFullButtonText()
            end
        end)
        ConcentrationWindow.resetFiltersButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(LOr("reset_filters_tooltip", "Reset expansion, profession, and character filters to All."))
            GameTooltip:Show()
        end)
        ConcentrationWindow.resetFiltersButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        ConcentrationWindow.FitToolbarButton = FitToolbarButton

        ConcentrationWindow.searchBox = CreateFrame("EditBox", nil, ConcentrationWindow, "InputBoxTemplate")
        ConcentrationWindow.searchBox:SetSize(120, 20)
        ConcentrationWindow.searchBox:SetPoint("LEFT", ConcentrationWindow.resetFiltersButton, "RIGHT", 12, 0)
        ConcentrationWindow.searchBox:SetAutoFocus(false)
        ConcentrationWindow.searchBox:SetMaxLetters(40)
        ConcentrationWindow.searchBox:SetText(ns.GetSearchText())
        ConcentrationWindow.searchBox.Instructions = ConcentrationWindow.searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        ConcentrationWindow.searchBox.Instructions:SetPoint("LEFT", 6, 0)
        ConcentrationWindow.searchBox.Instructions:SetText(LOr("search_placeholder", "Search..."))
        if ns.GetSearchText() ~= "" then
            ConcentrationWindow.searchBox.Instructions:Hide()
        end
        ConcentrationWindow.searchBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            ns.SetSearchText(self:GetText())
        end)
        ConcentrationWindow.searchBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        ConcentrationWindow.searchBox:SetScript("OnEditFocusLost", function(self)
            ns.SetSearchText(self:GetText())
        end)
        ConcentrationWindow.searchBox:SetScript("OnTextChanged", function(self, userInput)
            if self.Instructions then
                if (self:GetText() or "") == "" then
                    self.Instructions:Show()
                else
                    self.Instructions:Hide()
                end
            end
            if userInput then
                ns.searchText = self:GetText() or ""
                MarkLayoutDirty()
                if type(UpdateConcentrationTimes) == "function" then
                    UpdateConcentrationTimes()
                end
            end
        end)
        ConcentrationWindow.searchBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(LOr("search_tooltip", "Filter by character, realm, or profession. /conc search clears when empty."))
            GameTooltip:Show()
        end)
        ConcentrationWindow.searchBox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        ConcentrationWindow.weeklyAlertButton = CreateFrame("Button", nil, ConcentrationWindow)
        ConcentrationWindow.weeklyAlertButton:SetPoint("TOPLEFT", 10, -(MAIN_HEADER_HEIGHT - 4))
        ConcentrationWindow.weeklyAlertButton:SetPoint("TOPRIGHT", -10, -(MAIN_HEADER_HEIGHT - 4))
        ConcentrationWindow.weeklyAlertButton:SetHeight(16)
        ConcentrationWindow.weeklyAlertButton:Hide()
        ConcentrationWindow.weeklyAlertButton:SetScript("OnClick", function()
            if IsControlKeyDown() then
                ns.CopyWeeklyTurnIns()
            else
                ns.PrintWeeklyTurnIns()
            end
        end)
        ConcentrationWindow.weeklyAlertButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(LOr("weekly_alert_tooltip", "Click to list in chat. Ctrl+click copies into the chat box."))
            GameTooltip:Show()
        end)
        ConcentrationWindow.weeklyAlertButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        ConcentrationWindow.weeklyAlertText = ConcentrationWindow.weeklyAlertButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ConcentrationWindow.weeklyAlertText:SetPoint("LEFT", 2, 0)
        ConcentrationWindow.weeklyAlertText:SetPoint("RIGHT", -2, 0)
        ConcentrationWindow.weeklyAlertText:SetJustifyH("LEFT")
        ConcentrationWindow.weeklyAlertText:SetTextColor(1, 0.82, 0.25, 1)
        ConcentrationWindow.weeklyAlertText:SetWordWrap(false)
        ConcentrationWindow.weeklyAlertText:Hide()

        ConcentrationWindow.TableInset = CreateFrame("Frame", nil, ConcentrationWindow, "InsetFrameTemplate")
        ConcentrationWindow.TableInset:SetPoint("TOPLEFT", 12, -(MAIN_HEADER_HEIGHT - 5))
        ConcentrationWindow.TableInset:SetPoint("BOTTOMRIGHT", -12, MAIN_FOOTER_HEIGHT - 8)
        ConcentrationWindow.TableInset:SetFrameLevel(ConcentrationWindow:GetFrameLevel() + 1)
        -- The marble inset artwork sits on a solid base so scenery never shows through.
        local insetBase = ConcentrationWindow.TableInset:CreateTexture(nil, "BACKGROUND", nil, -8)
        insetBase:SetAllPoints()
        insetBase:SetColorTexture(0.06, 0.055, 0.05, 1)
        if ConcentrationWindow.TableInset.Bg then
            ConcentrationWindow.TableInset.Bg:SetVertexColor(0.8, 0.8, 0.8, 1)
        end

        -- Фрейм з повзунком
        ConcentrationWindow.scrollFrame = CreateFrame("ScrollFrame", nil, ConcentrationWindow, "UIPanelScrollFrameTemplate")
        ConcentrationWindow.scrollFrame:SetPoint("TOPLEFT", ns.MAIN_TABLE_LEFT, -MAIN_HEADER_HEIGHT)
        ConcentrationWindow.scrollFrame:SetFrameLevel(ConcentrationWindow.TableInset:GetFrameLevel() + 2)
        ConcentrationWindow.scrollFrame:SetPoint("BOTTOMRIGHT", -40, MAIN_FOOTER_HEIGHT)

        -- Контейнер для контенту (ширина динамічна під контент)
        ConcentrationWindow.content = CreateFrame("Frame", nil, ConcentrationWindow.scrollFrame)
        ConcentrationWindow.content:SetSize(math.max(400, ConcentrationWindow:GetWidth() - 70), ConcentrationWindow:GetHeight() - MAIN_CHROME_HEIGHT)
        ConcentrationWindow.scrollFrame:SetScrollChild(ConcentrationWindow.content)
        -- Заголовки таблиці (ширина професії та часу збільшена для великого шрифту)
        local headers = {
            { name = LOr("character", "Character"), width = 120, sortKey = "character" },
            { name = LOr("profession", "Profession"), width = 140, sortKey = "profession" },
            { name = LOr("moxie", "Moxie"), width = 56, sortKey = "moxie" },
            { name = LOr("concentration", "Concentration"), width = 100, sortKey = "concentration" },
            { name = (L["time_remaining_sort"] or L["restoration_time"] or "Time to full"), width = 110, sortKey = "time_remaining" },
            { name = LOr("exact_restoration_time", "Restores at"), width = 130, sortKey = nil },
        }

        local prevHeader
        for i, header in ipairs(headers) do
            local headerButton = CreateFrame("Button", nil, ConcentrationWindow.content, "ColumnDisplayButtonNoScriptsTemplate")
            if i == 1 then
                headerButton:SetPoint("TOPLEFT", 0, 0)
            elseif i == 2 then
                -- Після "Персонаж" — відступ під іконку професії
                local headerSpacer = CreateFrame("Frame", nil, ConcentrationWindow.content)
                headerSpacer:SetSize(PROF_ICON_SPACE, 20)
                headerSpacer:SetPoint("LEFT", prevHeader, "RIGHT", COLUMN_GAP, 0)
                headerButton:SetPoint("LEFT", headerSpacer, "RIGHT", 0, 0)
                ConcentrationWindow.headerSpacer = headerSpacer
            else
                headerButton:SetPoint("LEFT", prevHeader, "RIGHT", COLUMN_GAP, 0)
            end
            headerButton:SetSize(header.width, 24)

            local headerText = headerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            headerText:SetPoint("TOPLEFT", 5, 0)
            headerText:SetPoint("BOTTOMRIGHT", -5, 0)
            headerText:SetJustifyH("LEFT")
            headerText:SetText(header.name)
            headerButton.text = headerText

            if header.sortKey then
                headerButton:SetScript("OnClick", function()
                    if header.sortKey == "character" then
                        local mode, ascending = ConcentrationTrackerSettings.sortOrder, ConcentrationTrackerSettings.sortAscending
                        if mode ~= "character" and mode ~= "class" then
                            ConcentrationTrackerSettings.sortOrder, ConcentrationTrackerSettings.sortAscending = "character", true
                        elseif ascending then
                            ConcentrationTrackerSettings.sortAscending = false
                        else
                            ConcentrationTrackerSettings.sortOrder = mode == "character" and "class" or "character"
                            ConcentrationTrackerSettings.sortAscending = true
                        end
                    elseif ConcentrationTrackerSettings.sortOrder == header.sortKey then
                        ConcentrationTrackerSettings.sortAscending = not ConcentrationTrackerSettings.sortAscending
                    else
                        ConcentrationTrackerSettings.sortOrder = header.sortKey
                        ConcentrationTrackerSettings.sortAscending = true
                    end
                    UpdateConcentrationTimes()
                end)
                headerButton:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if header.sortKey == "character" then
                        GameTooltip:SetText("Character sorting")
                        GameTooltip:AddLine("Click to cycle: Name A–Z, Name Z–A, Class A–Z, Class Z–A.", 1, 1, 1, true)
                        GameTooltip:AddLine("Within a class, characters are listed by name A–Z.", 0.8, 0.8, 0.8, true)
                    else
                        GameTooltip:SetText(string.format((L and L["sort_tooltip"]) or "Click to sort by %s", header.name))
                    end
                    GameTooltip:Show()
                end)
                headerButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            prevHeader = headerButton
            table.insert(headerButtons, headerButton)
        end

        local horizontalSeparator = ConcentrationWindow.content:CreateTexture(nil, "BACKGROUND")
        horizontalSeparator:SetColorTexture(0.4, 0.36, 0.29, 0.5)
        horizontalSeparator:SetHeight(1)
        horizontalSeparator:SetPoint("TOPLEFT", 0, -25)
        horizontalSeparator:SetPoint("TOPRIGHT", 0, -25)

        -- Повідомлення коли немає даних
        ConcentrationWindow.emptyStateLabel = ConcentrationWindow.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ConcentrationWindow.emptyStateLabel:SetPoint("TOP", ConcentrationWindow.content, "TOP", 0, -60)
        ConcentrationWindow.emptyStateLabel:SetJustifyH("CENTER")
        ConcentrationWindow.emptyStateLabel:SetTextColor(0.7, 0.7, 0.7, 1)
        ConcentrationWindow.emptyStateLabel:Hide()

        ConcentrationWindow:SetScript("OnUpdate", function(self, elapsed)
            if self.responsiveResizePending and self.content then
                self.responsiveResizePending = nil
                UpdateConcentrationTimes()
            end
            self.updateInterval = (self.updateInterval or 0) + elapsed
            if self.updateInterval >= UI_UPDATE_INTERVAL then
                UpdateConcentrationTimes()
                self.updateInterval = self.updateInterval - UI_UPDATE_INTERVAL
            end
        end)

        -- Панель для прогнозу
        ConcentrationWindow.forecastFrame = CreateFrame("Frame", nil, ConcentrationWindow, "BackdropTemplate")
        ConcentrationWindow.forecastFrame:SetPoint("BOTTOMLEFT", 16, 88)
        ConcentrationWindow.forecastFrame:SetPoint("BOTTOMRIGHT", -16, 120)
        ConcentrationWindow.forecastFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        ConcentrationWindow.forecastFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        ConcentrationWindow.forecastFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        ConcentrationWindow.targetInput = CreateFrame("EditBox", nil, ConcentrationWindow.forecastFrame, "InputBoxTemplate")
        ConcentrationWindow.targetInput:SetSize(80, 28)
        ConcentrationWindow.targetInput:SetPoint("LEFT", 10, 0)
        ConcentrationWindow.targetInput:SetAutoFocus(false)
        ConcentrationWindow.targetInput:SetNumeric(true)
        ConcentrationWindow.targetInput:SetTextInsets(0, 0, 0, 0)
        ConcentrationWindow.targetInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        
        ConcentrationWindow.targetInput.Instructions = ConcentrationWindow.targetInput:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ConcentrationWindow.targetInput.Instructions:SetPoint("LEFT", 5, 0)
        ConcentrationWindow.targetInput.Instructions:SetTextColor(0.5, 0.5, 0.5, 1)
        ConcentrationWindow.targetInput.Instructions:SetText(LOr("enter_target_amount", "Enter target..."))

        ConcentrationWindow.targetInput:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text and text ~= "" then
                ConcentrationWindow.targetInput.Instructions:Hide()
                ConcentrationTrackerSettings.lastTarget = tonumber(text)
            else
                ConcentrationWindow.targetInput.Instructions:Show()
            end
        end)

        if ConcentrationTrackerSettings.lastTarget then
            ConcentrationWindow.targetInput:SetText(tostring(ConcentrationTrackerSettings.lastTarget))
            ConcentrationWindow.targetInput.Instructions:Hide()
        end

        ConcentrationWindow.calculateButton = CreateFrame("Button", nil, ConcentrationWindow.forecastFrame, "UIPanelButtonTemplate")
        ConcentrationWindow.calculateButton:SetSize(85, 25)
        ConcentrationWindow.calculateButton:SetPoint("LEFT", ConcentrationWindow.targetInput, "RIGHT", 5, 0)
        ConcentrationWindow.calculateButton:SetText(LOr("calculate", "Forecast"))

        ConcentrationWindow.targetResultText = ConcentrationWindow.forecastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ConcentrationWindow.targetResultText:SetPoint("LEFT", ConcentrationWindow.calculateButton, "RIGHT", 10, 0)
        ConcentrationWindow.targetResultText:SetFont(ADDON_FONT, 12, "OUTLINE")
        ConcentrationWindow.targetResultText:SetJustifyH("LEFT")

        local function CalculateTimeToTarget()
            local target = tonumber(ConcentrationWindow.targetInput:GetText())
            if not target or target <= 0 then
                ConcentrationWindow.targetResultText:SetText("")
                return
            end

            local bestTime = -1
            local bestResult = ""
            local anyAtOrAbove = false

            for key, data in pairs(ConcentrationTrackerDB) do
                if EntryHasConcentration(data) and EntryPassesMainTableFilters(key, data) then
                    local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                    local currentQty = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
                    if currentQty < target and target <= maxQ then
                        local remainingAmount = target - currentQty
                        local remainingTime = (remainingAmount / GetRestoreRate()) * 3600

                        if bestTime < 0 or remainingTime < bestTime then
                            bestTime = remainingTime
                            local timeStr = FormatDurationHoursMinutes(remainingTime)
                            bestResult = string.format(LOr("time_to_target", "Time to %d: %s"), target, timeStr)
                        end
                    elseif currentQty >= target then
                        anyAtOrAbove = true
                    end
                end
            end
            if bestResult == "" and anyAtOrAbove then
                bestResult = "|cFF00FF00" .. LOr("concentration", "Concentration") .. " OK|r"
            end
            ConcentrationWindow.targetResultText:SetText(bestResult)
        end
        ConcentrationWindow.calculateButton:SetScript("OnClick", CalculateTimeToTarget)

        local footerRule = ConcentrationWindow:CreateTexture(nil, "BORDER")
        footerRule:SetColorTexture(0.5, 0.45, 0.35, 0.6)
        footerRule:SetHeight(1)
        footerRule:SetPoint("BOTTOMLEFT", 6, 40)
        footerRule:SetPoint("BOTTOMRIGHT", -6, 40)

        -- Підсумкова статистика
        ConcentrationWindow.summaryText = ConcentrationWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ConcentrationWindow.summaryText:SetPoint("BOTTOMLEFT", 16, 46)
        ConcentrationWindow.summaryText:SetPoint("BOTTOMRIGHT", -16, 46)
        ConcentrationWindow.summaryText:SetHeight(40)
        ConcentrationWindow.summaryText:SetJustifyH("LEFT")
        ConcentrationWindow.summaryText:SetJustifyV("TOP")
        ConcentrationWindow.summaryText:SetWordWrap(true)
        ConcentrationWindow.summaryText:SetFont(ADDON_FONT, 11, "OUTLINE")
        ConcentrationWindow.summaryText:SetTextColor(0.8, 0.8, 0.8, 1)
        local summaryHover = CreateFrame("Frame", nil, ConcentrationWindow)
        summaryHover:SetAllPoints(ConcentrationWindow.summaryText)
        summaryHover:EnableMouse(true)
        summaryHover:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Concentration summary")
            GameTooltip:AddLine(ConcentrationWindow.summaryDetails or "", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        summaryHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    end

    EnsureLocalization()
    ApplyMainWindowVisualSettings()
    if ConcentrationTrackerSettings.autoFilterThisCharacter then
        local meKey = GetCurrentPlayerFilterKey()
        if meKey then
            ConcentrationTrackerSettings.selectedCharacter = meKey
        end
    end
    if ConcentrationTrackerSettings.refreshOnOpen then
        PerformConcentrationRefresh()
    end
    if ConcentrationWindow.title then
        local titleFs = (ConcentrationTrackerSettings and ConcentrationTrackerSettings.fontSize) or 12
        ConcentrationWindow.title:SetFont(ADDON_FONT, titleFs + 1, "")
        UpdateMainWindowTitle()
    end
    if ConcentrationWindow.refreshButton then
        ConcentrationWindow.refreshButton:SetText(L["refresh"] or "Refresh")
    end
    if ConcentrationWindow.settingsButton then
        ConcentrationWindow.settingsButton:SetText(L["settings"] or "Settings")
    end
    if ConcentrationWindow.thisCharButton then
        if ConcentrationWindow.FitToolbarButton then
            ConcentrationWindow.FitToolbarButton(ConcentrationWindow.thisCharButton, L["this_character"] or "This char", 64)
        else
            ConcentrationWindow.thisCharButton:SetText(L["this_character"] or "This char")
        end
    end
    if ConcentrationWindow.hideFullButton then
        if ConcentrationWindow.SyncHideFullButtonText then
            ConcentrationWindow.SyncHideFullButtonText()
        end
    end
    if ConcentrationWindow.resetFiltersButton then
        if ConcentrationWindow.FitToolbarButton then
            ConcentrationWindow.FitToolbarButton(
                ConcentrationWindow.resetFiltersButton,
                L["reset_filters_short"] or L["reset_filters"] or "Clear",
                56
            )
        else
            ConcentrationWindow.resetFiltersButton:SetText(L["reset_filters_short"] or "Clear")
        end
    end
    UpdateThisCharButtonState()
    if ConcentrationWindow.professionDropdown and InitializeProfessionDropdown then
        UIDropDownMenu_Initialize(ConcentrationWindow.professionDropdown, InitializeProfessionDropdown)
        if ConcentrationTrackerSettings.selectedProfession == "All" then
            UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, L["all_professions"] or "All")
        else
            UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, ConcentrationTrackerSettings.selectedProfession or (L["select_profession"] or ""))
        end
    end
    RefreshCharacterDropdown()
    if ConcentrationWindow.targetInput and ConcentrationWindow.targetInput.Instructions then
        ConcentrationWindow.targetInput.Instructions:SetText(L["enter_target_amount"] or "")
    end
    if ConcentrationWindow.calculateButton then
        ConcentrationWindow.calculateButton:SetText(L["calculate"] or "")
    end
    RefreshExpansionDropdowns()
    SyncMainWindowContentHeight()
    if ConcentrationTrackerSettings.showMoxie ~= false then
        RefreshCurrentCharacterMoxieFromAPI()
    end
    UpdateConcentrationTimes()
    ConcentrationWindow:Show()
end

local function EnsureRowMoxieCell(row)
    if row.cellMoxie then
        return
    end
    row.cellMoxie = CreateFrame("Frame", nil, row)
    row.cellMoxie:SetClipsChildren(true)
    row.cellMoxie:SetPoint("LEFT", row.cellProf, "RIGHT", COLUMN_GAP, 0)
    row.moxieColText = row.cellMoxie:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.moxieColText:SetPoint("LEFT", row.cellMoxie, "LEFT", 0, 0)
    row.moxieColText:SetJustifyH("LEFT")
    if row.cellConc then
        row.cellConc:ClearAllPoints()
        row.cellConc:SetPoint("LEFT", row.cellMoxie, "RIGHT", COLUMN_GAP, 0)
    end
end

local function UpdateRowMoxieColumn(row, entry, colWidth, fontPath, fontSize, showMoxieCol, naLabel)
    if not showMoxieCol or colWidth < 1 then
        if row.cellMoxie then
            row.cellMoxie:Hide()
        end
        if row.cellConc and row.cellProf then
            row.cellConc:ClearAllPoints()
            row.cellConc:SetPoint("LEFT", row.cellProf, "RIGHT", COLUMN_GAP, 0)
        end
        return
    end
    EnsureRowMoxieCell(row)
    row.cellMoxie:Show()
    row.moxieColText:SetWidth(colWidth)
    row.moxieColText:SetFont(fontPath, fontSize, "")
    if entry.moxieQuantity ~= nil then
        row.moxieColText:SetText(tostring(entry.moxieQuantity))
        local mq = entry.moxieQuantity
        if mq >= MOXIE_NOTIFY_THRESHOLD then
            row.moxieColText:SetTextColor(0.45, 0.92, 0.5)
        elseif mq >= math.floor(MOXIE_NOTIFY_THRESHOLD * 0.75) then
            row.moxieColText:SetTextColor(0.95, 0.78, 0.25)
        else
            row.moxieColText:SetTextColor(0.72, 0.72, 0.72)
        end
    else
        row.moxieColText:SetText(naLabel)
        row.moxieColText:SetTextColor(0.5, 0.5, 0.5)
    end
end

function UpdateConcentrationTimes()
    if not ConcentrationWindow or not ConcentrationWindow:IsShown() then return end
    if not ConcentrationTrackerSettings then return end

    local fontSize = (ConcentrationTrackerSettings and ConcentrationTrackerSettings.fontSize) or 12
    local fontPath = ADDON_FONT

    for _, dropdown in ipairs(ConcentrationWindow.retailFilters or {}) do
        local value = ConcentrationTrackerSettings[dropdown.filterKey] or "All"
        local label = value == "All" and dropdown.emptyLabel or value
        if dropdown.filterKey == "selectedCharacter" and value ~= "All" then
            local cn, rm = strsplit(DB_KEY_SEP, value)
            label = FormatCharacterFilterLabel(cn, rm)
        end
        dropdown:OverrideText(label)
    end

    -- Оновлюємо заголовки з індикатором сортування (▲/▼)
    local sortOrder = ConcentrationTrackerSettings.sortOrder
    local sortAscending = ConcentrationTrackerSettings.sortAscending
    for i = 1, #headerButtons do
        local name = (i == COL_CHAR and sortOrder == "class") and "Class / Character" or ((L and L[HEADER_KEYS[i]]) or HEADER_KEYS[i])
        if HEADER_SORT_KEYS[i] and (sortOrder == HEADER_SORT_KEYS[i] or (i == COL_CHAR and sortOrder == "class")) then
            name = name .. (sortAscending and " |TInterface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up:14:14:0:0|t" or " |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:14:14:0:0|t")
        end
        headerButtons[i].text:SetText(name)
        headerButtons[i].text:SetFont(fontPath, fontSize + 1, "")
    end

    for _, row in ipairs(rows) do
        row:Hide()
    end

    -- Після оновлення: додати колонку Moxie до заголовків, якщо вікно створене на старій версії
    if #headerButtons < NUM_TABLE_COLS and ConcentrationWindow and ConcentrationWindow.content then
        local prevHeader = headerButtons[2]
        if ConcentrationWindow.headerSpacer then
            prevHeader = headerButtons[2]
        end
        local moxieHeader = CreateFrame("Button", nil, ConcentrationWindow.content)
        moxieHeader:SetSize(56, 20)
        moxieHeader:SetPoint("LEFT", prevHeader, "RIGHT", COLUMN_GAP, 0)
        local moxieHeaderText = moxieHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        moxieHeaderText:SetAllPoints()
        moxieHeaderText:SetJustifyH("LEFT")
        moxieHeader.text = moxieHeaderText
        moxieHeader:SetScript("OnClick", function()
            if ConcentrationTrackerSettings.sortOrder == "moxie" then
                ConcentrationTrackerSettings.sortAscending = not ConcentrationTrackerSettings.sortAscending
            else
                ConcentrationTrackerSettings.sortOrder = "moxie"
                ConcentrationTrackerSettings.sortAscending = true
            end
            UpdateConcentrationTimes()
        end)
        moxieHeader:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format((L and L["sort_tooltip"]) or "Click to sort by %s", L["moxie"] or "Moxie"))
            GameTooltip:Show()
        end)
        moxieHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(headerButtons, COL_MOXIE, moxieHeader)
        for i = COL_CONC, NUM_TABLE_COLS do
            if headerButtons[i] then
                headerButtons[i]:ClearAllPoints()
                headerButtons[i]:SetPoint("LEFT", headerButtons[i - 1], "RIGHT", COLUMN_GAP, 0)
            end
        end
        ConcentrationWindow.layoutDirty = true
    end

    local dataEntries = {}
    local showMoxieInList = ConcentrationTrackerSettings.showMoxie ~= false
    local colVis = GetColumnVisibility()
    local naLabel = (L and L["no_concentration"]) or "—"

    for key, data in pairs(ConcentrationTrackerDB) do
        if type(data) ~= "table" then
            -- skip
        else
            local charName, realm, skillLineID = GetEntryIdentity(key, data)
            if not charName then
                charName, realm, skillLineID = "?", "?", nil
            end
            local professionName = data.professionName or (L and L["profession"]) or "Profession"
            local professionFilter = ConcentrationTrackerSettings.selectedProfession == "All"
                or ConcentrationTrackerSettings.selectedProfession == professionName
            if not professionFilter then
                -- skip
            elseif not EntryPassesCharacterFilter(charName, realm) then
                -- skip
            elseif not EntryPassesExpansionFilter(data, skillLineID) then
                -- skip
            elseif IsSkillLineIgnored(skillLineID) then
                -- skip
            elseif not IsCurrentPlayerActiveProfessionRow(charName, realm, skillLineID) then
                -- skip abandoned professions for current character
            elseif not ns.EntryPassesSearchFilter(charName, professionName, realm) then
                -- skip search filter
            elseif EntryHasConcentration(data) then
                local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
                local updatedQuantity, remainingTime, timeToFull, exactTime = GetRestorationTimes(data.lastUpdate, data.quantity, maxQ)
                if ConcentrationTrackerSettings.hideFullConcentration and updatedQuantity >= maxQ then
                    -- skip full rows when hide-full is enabled
                elseif ConcentrationTrackerSettings.hideStaleRows and IsDataStale(data.lastUpdate) then
                    -- skip stale rows when hide-stale is enabled
                else
                local remSec = (updatedQuantity >= maxQ) and 0 or (remainingTime or 0)
                local skillLineNum = data.professionID and tonumber(data.professionID) or tonumber(skillLineID)
                table.insert(dataEntries, {
                    key = key,
                    charName = charName,
                    realm = realm,
                    charClass = data.charClass,
                    professionName = professionName,
                    professionID = skillLineNum,
                    moxieCurrencyID = GetEntryMoxieCurrencyID(data, skillLineNum),
                    moxieQuantity = GetMoxieQuantityForEntry(data, skillLineID),
                    quantity = updatedQuantity,
                    maxQuantity = maxQ,
                    timeToFull = timeToFull,
                    exactTime = exactTime,
                    remainingSeconds = remSec,
                    lastUpdate = data.lastUpdate,
                    stale = IsDataStale(data.lastUpdate),
                    expansionKey = GetExpansionKeyForEntry(data, skillLineID),
                    moxieOnly = false,
                })
                end
            elseif showMoxieInList and not ConcentrationTrackerSettings.hideMoxieOnlyRows and data.moxieOnly then
                local moxieQty = GetMoxieQuantityForEntry(data, skillLineID)
                local skillLineNum = data.professionID and tonumber(data.professionID) or tonumber(skillLineID)
                local moxieCID = GetEntryMoxieCurrencyID(data, skillLineNum)
                if moxieQty ~= nil and ShouldTrackMoxieForCharacter(charName, realm, moxieCID, moxieQty, skillLineNum) then
                    if not moxieCID and type(key) == "string" and key:find(DB_KEY_SEP, 1, true) then
                        local _, _, third = strsplit(DB_KEY_SEP, key)
                        if third and third:sub(1, #MOXIE_ONLY_KEY_PREFIX) == MOXIE_ONLY_KEY_PREFIX then
                            moxieCID = tonumber(third:sub(#MOXIE_ONLY_KEY_PREFIX + 1))
                        end
                    end
                    if moxieCID and FindConcentrationRowForMoxieCurrency(charName, realm, moxieCID) then
                        -- дублікат: Moxie вже в рядку з концентрацією
                    else
                    table.insert(dataEntries, {
                        key = key,
                        charName = charName,
                        realm = realm,
                        charClass = data.charClass,
                        professionName = professionName,
                        professionID = skillLineNum,
                        moxieCurrencyID = moxieCID,
                        moxieQuantity = moxieQty,
                        quantity = 0,
                        maxQuantity = 1,
                        timeToFull = naLabel,
                        exactTime = naLabel,
                        remainingSeconds = -1,
                        lastUpdate = data.lastUpdate,
                        stale = IsDataStale(data.lastUpdate),
                        expansionKey = GetExpansionKeyForEntry(data, skillLineID),
                        moxieOnly = true,
                    })
                    end
                end
            end
        end
    end

    table.sort(dataEntries, function(a, b)
        local aCurrent = IsCurrentPlayerEntry(a.charName, a.realm)
        local bCurrent = IsCurrentPlayerEntry(b.charName, b.realm)
        if sortOrder ~= "character" and sortOrder ~= "class" and aCurrent ~= bCurrent then
            return aCurrent
        end

        local function TieBreak()
            local aChar = (a.charName or "") .. "\0" .. (a.realm or "")
            local bChar = (b.charName or "") .. "\0" .. (b.realm or "")
            if aChar ~= bChar then
                return aChar < bChar
            end
            local aProf = a.professionName or ""
            local bProf = b.professionName or ""
            if aProf ~= bProf then
                return aProf < bProf
            end
            return tostring(a.key or "") < tostring(b.key or "")
        end

        local function CmpNum(av, bv)
            if av == bv then
                return TieBreak()
            end
            if sortAscending then
                return av < bv
            end
            return av > bv
        end

        local function CmpStr(av, bv)
            av, bv = av or "", bv or ""
            if av == bv then
                return TieBreak()
            end
            if sortAscending then
                return av < bv
            end
            return av > bv
        end

        if sortOrder == "character" then
            return CmpStr((a.charName or ""):lower(), (b.charName or ""):lower())
        elseif sortOrder == "class" then
            local classNames = LOCALIZED_CLASS_NAMES_MALE or {}
            local ac, bc = a.charClass, b.charClass
            -- Unknown classes stay last in either direction.
            if (ac == nil) ~= (bc == nil) then return ac ~= nil end
            local al, bl = classNames[ac] or ac or "", classNames[bc] or bc or ""
            if al ~= bl then return CmpStr(al:lower(), bl:lower()) end
            local an, bn = (a.charName or ""):lower(), (b.charName or ""):lower()
            if an ~= bn then return an < bn end
            return TieBreak()
        elseif sortOrder == "profession" then
            return CmpStr(a.professionName, b.professionName)
        elseif sortOrder == "moxie" then
            return CmpNum(a.moxieQuantity or -1, b.moxieQuantity or -1)
        elseif sortOrder == "concentration" then
            return CmpNum(a.moxieOnly and -1 or a.quantity, b.moxieOnly and -1 or b.quantity)
        elseif sortOrder == "time_remaining" then
            return CmpNum(a.remainingSeconds, b.remainingSeconds)
        else
            return TieBreak()
        end
    end)

    -- Розрахунок загальної статистики та оновлення прогнозу
    local totalConc = 0
    local totalMax = 0
    local fullCount = 0
    local nextFillEntry = nil
    local nextFillSec = nil
    local charKeys = {}
    local target = ConcentrationTrackerSettings.lastTarget
    local bestTime = -1
    local bestResult = ""

    for _, entry in ipairs(dataEntries) do
        local ck = MakeCharacterFilterKey(entry.charName, entry.realm)
        if ck then
            charKeys[ck] = true
        end
        if not entry.moxieOnly then
            totalConc = totalConc + entry.quantity
            totalMax = totalMax + entry.maxQuantity
            if entry.quantity >= entry.maxQuantity then
                fullCount = fullCount + 1
            elseif entry.remainingSeconds and entry.remainingSeconds > 0 then
                if not nextFillSec or entry.remainingSeconds < nextFillSec then
                    nextFillSec = entry.remainingSeconds
                    nextFillEntry = entry
                end
            end
        end

        -- Прогноз для авто-оновлення
        if not entry.moxieOnly and target and target > 0 and target <= entry.maxQuantity then
            if entry.quantity < target then
                local remainingAmount = target - entry.quantity
                local remainingTime = (remainingAmount / GetRestoreRate()) * 3600
                if bestTime < 0 or remainingTime < bestTime then
                    bestTime = remainingTime
                    local timeStr = FormatDurationHoursMinutes(remainingTime)
                    bestResult = string.format(LOr("time_to_target", "Time to %d: %s"), target, timeStr)
                end
            elseif entry.quantity >= target and bestResult == "" then
                bestResult = "|cFF00FF00" .. LOr("concentration", "Concentration") .. " OK|r"
            end
        end
    end

    local charCount = 0
    for _ in pairs(charKeys) do
        charCount = charCount + 1
    end

    local totalMoxie = 0
    local hasMoxie = false
    if ConcentrationTrackerSettings.showMoxie ~= false then
        for _, entry in ipairs(dataEntries) do
            if entry.moxieQuantity ~= nil then
                totalMoxie = totalMoxie + entry.moxieQuantity
                hasMoxie = true
            end
        end
    end

    if ConcentrationWindow.summaryText then
        local summary = string.format((L and L["summary_total"]) or "Total: %.0f / %d", totalConc, totalMax)
        if charCount > 1 then
            summary = summary .. "  " .. string.format(LOr("summary_chars", "(%d chars)"), charCount)
        end
        if fullCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_full", "(%d full)"), fullCount)
        end
        if hasMoxie then
            summary = summary .. "  " .. string.format(LOr("summary_moxie", "Moxie: %d"), totalMoxie)
        end
        if #dataEntries > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_rows", "(%d rows)"), #dataEntries)
        end
        local staleCount = 0
        for _, entry in ipairs(dataEntries) do
            if entry.stale then
                staleCount = staleCount + 1
            end
        end
        if staleCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_stale", "(%d stale)"), staleCount)
            local oldestUpdate
            for _, entry in ipairs(dataEntries) do
                if entry.lastUpdate and (not oldestUpdate or entry.lastUpdate < oldestUpdate) then
                    oldestUpdate = entry.lastUpdate
                end
            end
            if oldestUpdate then
                summary = summary .. "  " .. string.format(
                    LOr("summary_oldest", "Oldest: %s"),
                    FormatDataAgeShort(oldestUpdate)
                )
            end
        end
        local soonCount = 0
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and ns.IsSoonFill(entry.remainingSeconds, 2) then
                soonCount = soonCount + 1
            end
        end
        if soonCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_soon", "(%d soon)"), soonCount)
        end
        local todayCount = 0
        local resetSec = ns.GetSecondsUntilDailyReset()
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and ns.IsFillBeforeReset(entry.remainingSeconds, resetSec) then
                todayCount = todayCount + 1
            end
        end
        if todayCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_today", "(%d before reset)"), todayCount)
        end
        local weekSec = ns.GetSecondsUntilWeeklyReset()
        local weekCount = 0
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and ns.IsFillBeforeReset(entry.remainingSeconds, weekSec) then
                weekCount = weekCount + 1
            end
        end
        if weekCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_week", "(%d this week)"), weekCount)
        end
        local spendCount = 0
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and ns.IsSpendable(entry.quantity, entry.maxQuantity) then
                spendCount = spendCount + 1
            end
        end
        if spendCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_spend", "(%d ready)"), spendCount)
        end
        local belowCount = 0
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and ns.IsBelowFill(entry.quantity, entry.maxQuantity) then
                belowCount = belowCount + 1
            end
        end
        if belowCount > 0 then
            summary = summary .. "  " .. string.format(LOr("summary_below", "(%d under 25%%)"), belowCount)
        end
        local avgQty, avgMax = 0, 0
        for _, entry in ipairs(dataEntries) do
            if (not entry.moxieOnly) and (entry.maxQuantity or 0) > 0 then
                avgQty = avgQty + (entry.quantity or 0)
                avgMax = avgMax + entry.maxQuantity
            end
        end
        local avgPct = ns.AverageFillPercent(avgQty, avgMax)
        if avgPct then
            summary = summary .. "  " .. string.format(LOr("summary_avg", "(%d%% avg)"), avgPct)
        end
        if nextFillEntry then
            local who = nextFillEntry.charName
            summary = summary .. "  |  " .. string.format(
                LOr("summary_next", "Next: %s (%s) %s"),
                who,
                nextFillEntry.professionName,
                nextFillEntry.timeToFull or FormatTimeToFullString(nextFillSec)
            )
        end
        local weeklyReady = ns.CollectReadyProfessionWeeklies()
        if #weeklyReady > 0 then
            summary = summary .. "  |  " .. string.format(LOr("summary_weekly", "Turn in: %d"), #weeklyReady)
        end
        ConcentrationWindow.summaryDetails = summary
        local concise = string.format("%d / %d concentration  ·  %d at cap", totalConc, totalMax, fullCount)
        if nextFillEntry then
            concise = concise .. "\nNext full: " .. nextFillEntry.charName .. " · " .. nextFillEntry.timeToFull
        end
        ConcentrationWindow.summaryText:SetText(concise)
        ConcentrationWindow.summaryText:SetFontObject(GameFontHighlightSmall)
        ns.UpdateWeeklyTurnInBanner()
    end
    if ConcentrationWindow.targetResultText then
        ConcentrationWindow.targetResultText:SetText(bestResult)
    end
    UpdateThisCharButtonState()

    if #dataEntries == 0 then
        ConcentrationWindow.emptyStateLabel:SetWidth(ConcentrationWindow.content:GetWidth() - 20)
        local hasAny = false
        if ConcentrationTrackerDB then
            for _, data in pairs(ConcentrationTrackerDB) do
                if type(data) == "table" then
                    hasAny = true
                    break
                end
            end
        end
        if hasAny then
            ConcentrationWindow.emptyStateLabel:SetText((L and L["empty_filtered"]) or "No rows match the current filters.")
        else
            ConcentrationWindow.emptyStateLabel:SetText((L and L["empty_state"]) or "No data yet.")
        end
        ConcentrationWindow.emptyStateLabel:SetFont(fontPath, fontSize, "")
        ConcentrationWindow.emptyStateLabel:Show()
        UpdateMainWindowTitle()
        return
    end
    ConcentrationWindow.emptyStateLabel:Hide()

    local sortKeys = {}
    for _, e in ipairs(dataEntries) do
        sortKeys[#sortKeys + 1] = e.key
    end
    table.sort(sortKeys)
    local layoutSig = table.concat({
        tostring(fontSize),
        tostring(ConcentrationTrackerSettings.showRealm),
        tostring(ConcentrationTrackerSettings.showMoxie ~= false),
        tostring(colVis[COL_CHAR]),
        tostring(colVis[COL_PROF]),
        tostring(colVis[COL_MOXIE]),
        tostring(colVis[COL_CONC]),
        tostring(colVis[COL_TIME]),
        tostring(colVis[COL_EXACT]),
        tostring(ConcentrationTrackerSettings.selectedProfession or ""),
        tostring(ConcentrationTrackerSettings.selectedExpansion or "All"),
        tostring(ConcentrationTrackerSettings.selectedCharacter or "All"),
        ns.GetSearchText(),
        tostring(ConcentrationTrackerSettings.hideFullConcentration and true or false),
        tostring(ConcentrationTrackerSettings.hideStaleRows and true or false),
        tostring(ConcentrationTrackerSettings.hideMoxieOnlyRows and true or false),
        tostring(ConcentrationTrackerSettings.showConcentrationPercent and true or false),
        tostring(ConcentrationTrackerSettings.compactTimeFormat and true or false),
        tostring(ConcentrationTrackerSettings.highlightFullRows ~= false),
        tostring(ConcentrationTrackerSettings.highlightLowRows == true),
        tostring(ConcentrationTrackerSettings.highlightSoonRows == true),
        tostring(ConcentrationTrackerSettings.highlightThisCharacter ~= false),
        sortOrder or "",
        sortAscending and "1" or "0",
        ConcentrationTrackerSettings.language or "",
        tostring(#dataEntries),
        table.concat(sortKeys, "|"),
    }, "\001")

    local colWidths
    local needRelayout = ConcentrationWindow.layoutDirty
        or not ConcentrationWindow._layoutSig
        or ConcentrationWindow._layoutSig ~= layoutSig
        or not ConcentrationWindow.savedColWidths

    if needRelayout then
        local MIN_COL = { 80, 90, 48, 70, 90, 120 }
        colWidths = { 0, 0, 0, 0, 0, 0 }
        for i = 1, NUM_TABLE_COLS do
            colWidths[i] = MIN_COL[i]
        end
        for _, entry in ipairs(dataEntries) do
            local charDisp = entry.charName
            if ConcentrationTrackerSettings.showRealm then
                charDisp = charDisp .. "-" .. entry.realm
            end
            local w1 = MeasureTextWidth(charDisp, fontPath, fontSize)
            local w2 = MeasureTextWidth(entry.professionName, fontPath, fontSize)
            local wMox = MeasureTextWidth(
                entry.moxieQuantity ~= nil and tostring(entry.moxieQuantity) or naLabel,
                fontPath,
                fontSize
            )
            local wConcText = entry.moxieOnly and naLabel or FormatConcentrationAmount(entry.quantity, entry.maxQuantity)
            local w3 = MeasureTextWidth(wConcText, fontPath, fontSize - 1)
            local w4 = MeasureTextWidth(entry.timeToFull, fontPath, fontSize)
            local w5 = MeasureTextWidth(entry.exactTime, fontPath, fontSize)
            colWidths[COL_CHAR] = math.max(colWidths[COL_CHAR], w1 + 8)
            colWidths[COL_PROF] = math.max(colWidths[COL_PROF], w2)
            colWidths[COL_MOXIE] = math.max(colWidths[COL_MOXIE], wMox)
            colWidths[COL_CONC] = math.max(colWidths[COL_CONC], w3)
            colWidths[COL_TIME] = math.max(colWidths[COL_TIME], w4)
            colWidths[COL_EXACT] = math.max(colWidths[COL_EXACT], w5)
        end
        for i = 1, NUM_TABLE_COLS do
            local headerName = (i == COL_CHAR and sortOrder == "class") and "Class / Character" or ((L and L[HEADER_KEYS[i]]) or HEADER_KEYS[i])
            if HEADER_SORT_KEYS[i] and (sortOrder == HEADER_SORT_KEYS[i] or (i == COL_CHAR and sortOrder == "class")) then
                headerName = headerName .. (sortAscending and " |TInterface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up:14:14:0:0|t" or " |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:14:14:0:0|t")
            end
            local hw = MeasureTextWidth(headerName, fontPath, fontSize + 1)
            colWidths[i] = math.max(colWidths[i], hw + 10)
        end
        ApplyVisibilityToColWidths(colWidths, colVis)
        ConcentrationWindow.savedColWidths = {
            colWidths[COL_CHAR], colWidths[COL_PROF], colWidths[COL_MOXIE],
            colWidths[COL_CONC], colWidths[COL_TIME], colWidths[COL_EXACT],
        }
        ConcentrationWindow._layoutSig = layoutSig
        ConcentrationWindow.layoutDirty = false
    else
        local s = ConcentrationWindow.savedColWidths
        colWidths = {
            s[1] or 80, s[2] or 90, s[3] or 48, s[4] or 70, s[5] or 90, s[6] or 120,
        }
        ApplyVisibilityToColWidths(colWidths, colVis)
    end

    -- savedColWidths contains measured minima, never stretched widths.
    -- Allocate spare width afresh so growing and shrinking cannot accumulate it.
    local minimumContentWidth = ComputeTotalContentWidth(colWidths, colVis)
    local requiredWindowWidth = math.max(680, minimumContentWidth + 70)
    ConcentrationWindow:SetResizeBounds(requiredWindowWidth, 380,
        math.max(requiredWindowWidth, UIParent:GetWidth()), math.max(380, UIParent:GetHeight()))
    if ConcentrationWindow:GetWidth() < requiredWindowWidth then
        ConcentrationWindow:SetWidth(requiredWindowWidth)
    end
    local availableWidth = math.max(minimumContentWidth, ConcentrationWindow:GetWidth() - 70)
    local spareWidth = availableWidth - minimumContentWidth
    -- Keep labels readable and give the concentration meter the flexible space.
    -- If that column is disabled, expand the profession or last visible column.
    local flexibleColumn = colVis[COL_CONC] and COL_CONC or (colVis[COL_PROF] and COL_PROF)
    if not flexibleColumn then
        for _, col in ipairs(COLUMN_UI_ORDER) do
            if colVis[col] then flexibleColumn = col end
        end
    end
    if flexibleColumn then colWidths[flexibleColumn] = colWidths[flexibleColumn] + spareWidth end
    local totalContentWidth = ComputeTotalContentWidth(colWidths, colVis)
    ConcentrationWindow.content:SetSize(availableWidth, ConcentrationWindow:GetHeight() - MAIN_CHROME_HEIGHT)

    PositionTableHeaders(colWidths, colVis)

    for index, entry in ipairs(dataEntries) do
        local row = rows[index]
        local rowHeight = math.max(28, fontSize + 12)
        if not row then
            row = CreateFrame("Frame", nil, ConcentrationWindow.content)
            if index == 1 then
                row:SetPoint("TOPLEFT", 0, -30)
            else
                row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -5)
            end

            -- Фон для чергування рядків (смугастість)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.35)
            row.bg:SetAllPoints(row)
            row.bg:Hide()

            -- Золота смужка для рядків залогіненого персонажа
            row.meAccent = row:CreateTexture(nil, "ARTWORK")
            row.meAccent:SetColorTexture(1, 0.82, 0, 0.9)
            row.meAccent:SetWidth(3)
            row.meAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.meAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.meAccent:Hide()

            -- Підсвітка при наведенні
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetColorTexture(0.4, 0.4, 0.5, 0.25)
            row.highlight:SetAllPoints(row)
            row.highlight:Hide()
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                if self.highlight then self.highlight:Show() end
                if self.profTooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.profTooltip)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                if self.highlight then self.highlight:Hide() end
                GameTooltip:Hide()
            end)
            row:SetScript("OnMouseUp", HandleRowMouseUp)

            -- Клітинка 1: Персонаж
            row.cellChar = CreateFrame("Frame", nil, row)
            row.cellChar:SetClipsChildren(true)
            row.cellChar:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.charText = row.cellChar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.charText:SetPoint("LEFT", row.cellChar, "LEFT", 8, 0)
            row.charText:SetWidth(80)
            row.charText:SetJustifyH("LEFT")

            -- Іконка професії
            row.profIcon = row:CreateTexture(nil, "OVERLAY")
            row.profIcon:SetSize(16, 16)
            row.profIcon:SetPoint("LEFT", row.cellChar, "RIGHT", COLUMN_GAP, 0)
            row.profIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.profIcon:Hide()

            -- Клітинка 2: Професія
            row.cellProf = CreateFrame("Frame", nil, row)
            row.cellProf:SetClipsChildren(true)
            row.cellProf:SetPoint("LEFT", row.profIcon, "RIGHT", 4, 0)
            row.profText = row.cellProf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.profText:SetPoint("LEFT", row.cellProf, "LEFT", 0, 0)
            row.profText:SetWidth(90)
            row.profText:SetJustifyH("LEFT")
            row.profText:SetWordWrap(false)

            -- Клітинка 3: Moxie
            row.cellMoxie = CreateFrame("Frame", nil, row)
            row.cellMoxie:SetClipsChildren(true)
            row.cellMoxie:SetPoint("LEFT", row.cellProf, "RIGHT", COLUMN_GAP, 0)
            row.moxieColText = row.cellMoxie:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.moxieColText:SetPoint("LEFT", row.cellMoxie, "LEFT", 0, 0)
            row.moxieColText:SetJustifyH("LEFT")

            -- Клітинка 4: Концентрація (прогрес-бар)
            row.cellConc = CreateFrame("Frame", nil, row)
            row.cellConc:SetClipsChildren(true)
            row.cellConc:SetPoint("LEFT", row.cellMoxie, "RIGHT", COLUMN_GAP, 0)
            row.concBarBg = row.cellConc:CreateTexture(nil, "BACKGROUND")
            row.concBarBg:SetAtlas("ui-damagemeters-bar-shadowbg")
            row.concBarBg:SetHeight(18)
            row.concBarBg:SetPoint("LEFT", row.cellConc, "LEFT", 0, 0)
            row.concBarBg:SetWidth(70)
            
            row.concBarFill = row.cellConc:CreateTexture(nil, "ARTWORK")
            row.concBarFill:SetAtlas("UI-HUD-CoolDownManager-Bar")
            row.concBarFill:SetHeight(18)
            row.concBarFill:SetPoint("LEFT", row.concBarBg, "LEFT", 0, 0)
            row.concBarFill:SetWidth(0)

            row.concBarEdge = row.cellConc:CreateTexture(nil, "OVERLAY")
            row.concBarEdge:SetAtlas("ui-damagemeters-bar-shadowedge")
            row.concBarEdge:SetPoint("TOPLEFT", row.concBarBg, "TOPLEFT", -1, 1)
            row.concBarEdge:SetPoint("BOTTOMRIGHT", row.concBarBg, "BOTTOMRIGHT", 1, -1)

            row.concText = row.cellConc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.concText:SetPoint("CENTER", row.concBarBg, "CENTER", 0, 0)
            row.concText:SetJustifyH("CENTER")

            -- Клітинка 4: Відновлення через
            row.cellTime = CreateFrame("Frame", nil, row)
            row.cellTime:SetClipsChildren(true)
            row.cellTime:SetPoint("LEFT", row.cellConc, "RIGHT", COLUMN_GAP, 0)
            row.timeToFullText = row.cellTime:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.timeToFullText:SetPoint("LEFT", row.cellTime, "LEFT", 0, 0)
            row.timeToFullText:SetJustifyH("LEFT")

            -- Клітинка 5: Відновиться о
            row.cellExact = CreateFrame("Frame", nil, row)
            row.cellExact:SetClipsChildren(true)
            row.cellExact:SetPoint("LEFT", row.cellTime, "RIGHT", COLUMN_GAP, 0)
            row.exactTimeText = row.cellExact:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.exactTimeText:SetPoint("LEFT", row.cellExact, "LEFT", 0, 0)
            row.exactTimeText:SetJustifyH("LEFT")
            row.exactTimeText:SetWordWrap(false)

            -- Не відстежувати цю лінію навичок (окремий ID для Dragon Isles / інших розширень)
            row.stopTrackingButton = CreateFrame("Button", nil, row)
            row.stopTrackingButton:SetSize(16, 16)
            row.stopTrackingButton:SetPoint("LEFT", row.cellExact, "RIGHT", 5, 0)
            row.stopTrackingButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
            row.stopTrackingButton:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-Up")
            row.stopTrackingButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
            row.stopTrackingButton:SetScript("OnClick", function(self)
                local data = {
                    key = self.entryKey,
                    charName = self.charName,
                    profName = self.profName,
                    skillLineID = self.skillLineID,
                }
                RegisterStopTrackingDialog()
                StaticPopup_Show("CONFIRM_STOP_TRACKING_SKILLLINE", self.charName, self.profName, data)
            end)
            row.stopTrackingButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L and L["stop_tracking_tooltip"] or "Stop auto-tracking this profession variant")
                GameTooltip:Show()
            end)
            row.stopTrackingButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Кнопка видалення (рядок можна знову додати, відкривши вікно професії)
            row.deleteButton = CreateFrame("Button", nil, row)
            row.deleteButton:SetSize(16, 16)
            row.deleteButton:SetPoint("LEFT", row.stopTrackingButton, "RIGHT", 5, 0)
            row.deleteButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            row.deleteButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
            row.deleteButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
            row.deleteButton:SetScript("OnClick", function(self)
                local data = { key = self.entryKey, charName = self.charName, profName = self.profName }
                RegisterDeleteEntryDialog() -- Оновлюємо текст перед показом
                StaticPopup_Show("CONFIRM_DELETE_CONCENTRATION_ENTRY", self.charName, self.profName, data)
            end)
            row.deleteButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L and L["delete_row_tooltip"] or "Remove this row only (data can be re-added)")
                GameTooltip:Show()
            end)
            row.deleteButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local rowSeparator = row:CreateTexture(nil, "BACKGROUND")
            rowSeparator:SetColorTexture(1, 1, 1, 0.08)
            rowSeparator:SetHeight(1)
            rowSeparator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
            rowSeparator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)

            rows[index] = row
        end

        row:SetSize(totalContentWidth, rowHeight)

        -- Розмір шрифту та смугастість
        row.charText:SetFont(fontPath, fontSize, "")
        row.profText:SetFont(fontPath, fontSize, "")
        row.concText:SetFont(fontPath, fontSize, "")
        row.timeToFullText:SetFont(fontPath, fontSize, "")
        row.exactTimeText:SetFont(fontPath, fontSize, "")

        row.entryCharName = entry.charName
        row.entryRealm = entry.realm
        row.entryProfessionName = entry.professionName
        row.entryQuantity = entry.quantity
        row.entryMaxQuantity = entry.maxQuantity
        row.entryTimeToFull = entry.timeToFull
        row.entryMoxieOnly = entry.moxieOnly
        row.entryMoxieQuantity = entry.moxieQuantity
        row.entryExpansionKey = entry.expansionKey
        row:SetScript("OnMouseUp", HandleRowMouseUp)

        local isFullRow = (not entry.moxieOnly) and entry.quantity >= entry.maxQuantity
        local fillPct = 1
        if (not entry.moxieOnly) and entry.maxQuantity and entry.maxQuantity > 0 then
            fillPct = entry.quantity / entry.maxQuantity
        end
        local isLowRow = (not entry.moxieOnly) and (not isFullRow)
            and ConcentrationTrackerSettings.highlightLowRows == true
            and fillPct < 0.25
        local isSoonRow = (not entry.moxieOnly) and (not isFullRow)
            and ConcentrationTrackerSettings.highlightSoonRows == true
            and ns.IsSoonFill(entry.remainingSeconds, 2)
        if row.bg then
            if isFullRow and ConcentrationTrackerSettings.highlightFullRows ~= false then
                row.bg:SetColorTexture(0.12, 0.42, 0.22, 0.42)
                row.bg:Show()
            elseif isSoonRow then
                row.bg:SetColorTexture(0.48, 0.38, 0.10, 0.42)
                row.bg:Show()
            elseif isLowRow then
                row.bg:SetColorTexture(0.45, 0.18, 0.12, 0.40)
                row.bg:Show()
            elseif index % 2 == 0 then
                row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.35)
                row.bg:Show()
            else
                row.bg:Hide()
            end
        end
        if row.meAccent then
            if IsCurrentPlayerEntry(entry.charName, entry.realm)
                and ConcentrationTrackerSettings.highlightThisCharacter ~= false then
                row.meAccent:Show()
            else
                row.meAccent:Hide()
            end
        end

        local charDisplayName = entry.charName
        if ConcentrationTrackerSettings.showRealm then
            charDisplayName = charDisplayName .. "-" .. entry.realm
        end
        if colVis[COL_CHAR] then
            row.charText:SetText(charDisplayName)
        end
        
        -- Колір класу
        if entry.charClass and RAID_CLASS_COLORS[entry.charClass] then
            local color = RAID_CLASS_COLORS[entry.charClass]
            row.charText:SetTextColor(color.r, color.g, color.b)
        else
            row.charText:SetTextColor(1, 0.82, 0, 1)
        end

        if colVis[COL_PROF] then
            row.profText:SetText(entry.professionName)
            row.profText:ClearAllPoints()
            row.profText:SetPoint("LEFT", row.cellProf, "LEFT", 0, 0)
        end
        local tooltipLines = { entry.professionName }
        if entry.moxieOnly then
            tooltipLines[#tooltipLines + 1] = "Moxie recorded; concentration has not been scanned."
            tooltipLines[#tooltipLines + 1] = "Log into this character; concentration is collected automatically after login."
        end
        if entry.moxieQuantity ~= nil then
            tooltipLines[#tooltipLines + 1] = string.format(L["moxie_short"] or "Moxie: %d", entry.moxieQuantity)
        end
        if entry.lastUpdate then
            tooltipLines[#tooltipLines + 1] = string.format(
                LOr("last_sync", "Last sync: %s"),
                FormatDataAgeShort(entry.lastUpdate)
            )
        end
        if entry.stale then
            tooltipLines[#tooltipLines + 1] = LOr("stale_data_hint", "Data may be outdated — open the profession or /conc refresh.")
        end
        tooltipLines[#tooltipLines + 1] = LOr("row_filter_hint", "Right-click — filter to this character.")
        tooltipLines[#tooltipLines + 1] = LOr("row_filter_prof_hint", "Shift+Right-click — filter to this profession.")
        tooltipLines[#tooltipLines + 1] = LOr("row_copy_hint", "Ctrl+Right-click — copy this row to chat.")
        tooltipLines[#tooltipLines + 1] = LOr("row_filter_exp_hint", "Alt+Right-click — filter to this expansion.")
        row.profTooltip = table.concat(tooltipLines, "\n")

        ApplyRowProfessionIcon(row, entry)
        local naLabel = (L and L["no_concentration"]) or "—"
        if entry.moxieOnly then
            if row.concBarFill then row.concBarFill:Hide() end
            if row.concBarBg then row.concBarBg:Hide() end
            if row.concBarEdge then row.concBarEdge:Hide() end
            if colVis[COL_CONC] then
                row.concText:SetText("Not scanned")
                row.concText:SetTextColor(0.55, 0.55, 0.55)
                row.concText:SetFont(fontPath, fontSize - 1, "")
            end
            if colVis[COL_TIME] then
                row.timeToFullText:SetText(entry.timeToFull or naLabel)
                row.timeToFullText:SetTextColor(0.55, 0.55, 0.55)
            end
            if colVis[COL_EXACT] then
                row.exactTimeText:SetText(entry.exactTime or naLabel)
                row.exactTimeText:SetTextColor(0.55, 0.55, 0.55)
            end
            if row.stopTrackingButton then
                if entry.professionID then
                    row.stopTrackingButton:Show()
                else
                    row.stopTrackingButton:Hide()
                end
            end
        else
            if row.concBarBg then row.concBarBg:Show() end
            if row.concBarEdge then row.concBarEdge:Show() end
            local maxQ = GetEffectiveMaxQuantity(entry.maxQuantity)
            local percentage = (entry.quantity / maxQ) * 100
            local r, g, b = GetConcentrationFillColor(percentage)
            if row.concBarFill and colVis[COL_CONC] and colWidths[COL_CONC] > 0 then
                row.concBarFill:SetWidth(math.max(0, (entry.quantity / maxQ) * colWidths[COL_CONC]))
                row.concBarFill:SetAtlas("UI-HUD-CoolDownManager-Bar")
                row.concBarFill:SetVertexColor(r, g, b, 1)
                row.concBarFill:Show()
            elseif row.concBarFill then
                row.concBarFill:SetWidth(0)
                row.concBarFill:Hide()
            end

            if colVis[COL_CONC] then
                row.concText:SetText(FormatConcentrationAmount(entry.quantity, maxQ))
                row.concText:SetTextColor(1, 1, 1)
                row.concText:SetFont(fontPath, fontSize - 1, "OUTLINE")
            end

            if colVis[COL_TIME] then
                row.timeToFullText:SetText(entry.timeToFull)
                if entry.stale then
                    row.timeToFullText:SetTextColor(0.65, 0.65, 0.65)
                else
                    row.timeToFullText:SetTextColor(r, g, b)
                end
            end
            if colVis[COL_EXACT] then
                row.exactTimeText:SetText(entry.exactTime)
                if entry.stale then
                    row.exactTimeText:SetTextColor(0.65, 0.65, 0.65)
                else
                    row.exactTimeText:SetTextColor(0.85, 0.85, 0.85)
                end
            end
            if row.stopTrackingButton then
                row.stopTrackingButton:Show()
            end
        end

        -- Оновлюємо дані для кнопки видалення
        row.stopTrackingButton.entryKey = entry.key
        row.stopTrackingButton.charName = entry.charName
        row.stopTrackingButton.profName = entry.professionName
        row.stopTrackingButton.skillLineID = entry.professionID

        row.deleteButton.entryKey = entry.key
        row.deleteButton.charName = entry.charName
        row.deleteButton.profName = entry.professionName

        UpdateRowMoxieColumn(row, entry, colWidths[COL_MOXIE], fontPath, fontSize, colVis[COL_MOXIE], naLabel)
        ApplyRowColumnLayout(row, colWidths, colVis, rowHeight)

        row:Show()
    end
    UpdateMainWindowTitle()
end

local SETTINGS_SCROLL_FOOTER_HEIGHT = 54
local SETTINGS_SCROLL_TOP_INSET = 88
local SETTINGS_SCROLL_CHILD_DEFAULT_HEIGHT = 1500

local function LanguageSettingsWindowIsComplete(win)
    return win
        and win.settingsScrollFrame
        and win.scrollChild
        and win.sectionDisplayLabel
        and win.expansionDropdown
        and win.columnCheckboxes
        and win.columnCheckboxes[COL_CHAR]
        and win.highlightLowCheckbox
        and win.highlightSoonCheckbox
        and win.refreshOnOpenCheckbox
        and win.highlightThisCharCheckbox
        and win.lockWindowCheckbox
        and win.hideInCombatCheckbox
        and win.hideStaleCheckbox
        and win.hideMoxieOnlyCheckbox
        and win.weeklyTurnInCheckbox
        and win.closeButton
end

local function DestroyLanguageSettingsWindow()
    local win = LanguageSettingsWindow or _G.LanguageSettingsWindow
    if win then
        win:Hide()
        win:SetParent(nil)
    end
    LanguageSettingsWindow = nil
    _G.LanguageSettingsWindow = nil
end

local function RefreshLanguageSettingsScrollRange()
    local win = LanguageSettingsWindow or _G.LanguageSettingsWindow
    if not win or not win.settingsScrollFrame or not win.scrollChild then
        return
    end
    LanguageSettingsWindow = win
    local child = win.scrollChild
    local frame = win.settingsScrollFrame
    local frameW = frame:GetWidth()
    if frameW and frameW > 1 then
        child:SetWidth(frameW)
    end

    local viewportH = frame:GetHeight() or 200
    local contentH = SETTINGS_SCROLL_CHILD_DEFAULT_HEIGHT
    local last = win.clearIgnoredButton
    if last and child.GetTop and last.GetBottom then
        local childTop = child:GetTop()
        local lastBottom = last:GetBottom()
        if childTop and lastBottom then
            local measured = childTop - lastBottom + 32
            if measured > 100 then
                contentH = measured
            end
        end
    end
    if contentH < viewportH then
        contentH = viewportH
    end
    child:SetHeight(contentH)

    if frame.UpdateScrollChildRect then
        frame:UpdateScrollChildRect()
    end
end

function CreateLanguageSettingsWindow()
    if not LanguageSettingsWindowIsComplete(LanguageSettingsWindow or _G.LanguageSettingsWindow) then
        DestroyLanguageSettingsWindow()
    end

    if not LanguageSettingsWindow then
        LanguageSettingsWindow = CreateFrame("Frame", "ConcentrationTrackerSettingsRoot", UIParent, "PortraitFrameTemplate,BackdropTemplate")
        LanguageSettingsWindow:SetClampedToScreen(true)
        if LanguageSettingsWindow.PortraitContainer then
            SetPortraitTexture(LanguageSettingsWindow.PortraitContainer.portrait, "player")
        end
        LanguageSettingsWindow:SetSize(460, 580)
        if ConcentrationTrackerSettings.settingsWindowPosition and ConcentrationTrackerSettings.settingsWindowPosition[1] then
            local p = ConcentrationTrackerSettings.settingsWindowPosition
            LanguageSettingsWindow:SetPoint(p[1], UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
        else
            LanguageSettingsWindow:SetPoint("CENTER")
        end
        LanguageSettingsWindow:SetMovable(true)
        LanguageSettingsWindow:EnableMouse(true)
        LanguageSettingsWindow:RegisterForDrag("LeftButton")
        LanguageSettingsWindow:SetScript("OnDragStart", LanguageSettingsWindow.StartMoving)
        LanguageSettingsWindow:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if ConcentrationTrackerSettings then
                local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
                ConcentrationTrackerSettings.settingsWindowPosition = { point, relativePoint, xOfs, yOfs }
            end
        end)
        LanguageSettingsWindow:SetScript("OnHide", function(self)
            if ConcentrationTrackerSettings then
                local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
                ConcentrationTrackerSettings.settingsWindowPosition = { point, relativePoint, xOfs, yOfs }
            end
        end)
        LanguageSettingsWindow:SetScript("OnShow", function()
            RefreshLanguageSettingsScrollRange()
            C_Timer.After(0.05, RefreshLanguageSettingsScrollRange)
        end)
        LanguageSettingsWindow:SetFrameStrata("DIALOG")

        LanguageSettingsWindow:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
            tile = true, tileSize = 256,
            insets = {left=4, right=4, top=24, bottom=4},
        })
        LanguageSettingsWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
        LanguageSettingsWindow:SetAlpha(1)
        if LanguageSettingsWindow.CloseButton then
            LanguageSettingsWindow.CloseButton:SetScript("OnClick", function() LanguageSettingsWindow:Hide() end)
        end

        _G.LanguageSettingsWindow = LanguageSettingsWindow
        tinsert(UISpecialFrames, "ConcentrationTrackerSettingsRoot")

        LanguageSettingsWindow.title = LanguageSettingsWindow.TitleContainer.TitleText
        LanguageSettingsWindow.title:ClearAllPoints()
        LanguageSettingsWindow.title:SetFontObject(GameFontNormal)
        LanguageSettingsWindow.title:SetPoint("CENTER", LanguageSettingsWindow.TitleContainer, "CENTER", 0, 0)
        LanguageSettingsWindow.title:SetText(L["settings_window_title"] or L["settings"] or "Settings")

        LanguageSettingsWindow.versionLabel = LanguageSettingsWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        LanguageSettingsWindow.versionLabel:SetPoint("TOPRIGHT", LanguageSettingsWindow, "TOPRIGHT", -12, -34)
        LanguageSettingsWindow.versionLabel:SetJustifyH("RIGHT")
        LanguageSettingsWindow.versionLabel:SetText(string.format(L["version_label"] or "Version %s", ADDON_VERSION))

        LanguageSettingsWindow.languageDropdown = CreateFrame("Frame", "ConcentrationTrackerLanguageDropdown", LanguageSettingsWindow, "UIDropDownMenuTemplate")
        LanguageSettingsWindow.languageDropdown:SetPoint("TOP", LanguageSettingsWindow.title, "BOTTOM", 0, -20)
        -- Збільшена ширина для кращого вирівнювання
        UIDropDownMenu_SetWidth(LanguageSettingsWindow.languageDropdown, 200)
        UIDropDownMenu_SetText(LanguageSettingsWindow.languageDropdown, GetLanguageDisplayName(ConcentrationTrackerSettings.language or "en"))

        UIDropDownMenu_Initialize(LanguageSettingsWindow.languageDropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, lang in ipairs(LANGUAGES) do
                info.text = lang.text
                info.arg1 = lang.value
                info.func = function(self, arg1)
                    ConcentrationTrackerSettings.language = arg1
                    EnsureLocalization(arg1)
                    UpdateLanguageTexts()
                    UIDropDownMenu_SetText(LanguageSettingsWindow.languageDropdown, GetLanguageDisplayName(arg1))
                end
                info.checked = (ConcentrationTrackerSettings.language == lang.value)
                UIDropDownMenu_AddButton(info)
            end
        end)

        LanguageSettingsWindow.languageDropdown:Hide()
        local languageMenu = CreateFrame("DropdownButton", nil, LanguageSettingsWindow, "WowStyle1DropdownTemplate")
        LanguageSettingsWindow.retailLanguageDropdown = languageMenu
        languageMenu:SetSize(200, 24)
        languageMenu:SetPoint("TOP", LanguageSettingsWindow, "TOP", 0, -48)
        languageMenu:SetupMenu(function(_, root)
            for _, lang in ipairs(LANGUAGES) do
                root:CreateRadio(lang.text,
                    function(value) return ConcentrationTrackerSettings.language == value end,
                    function(value)
                        ConcentrationTrackerSettings.language = value
                        EnsureLocalization(value)
                        UpdateLanguageTexts()
                        languageMenu:OverrideText(GetLanguageDisplayName(value))
                    end, lang.value)
            end
        end)
        languageMenu:OverrideText(GetLanguageDisplayName(ConcentrationTrackerSettings.language or "en"))

        LanguageSettingsWindow.SettingsInset = CreateFrame("Frame", nil, LanguageSettingsWindow, "InsetFrameTemplate")
        LanguageSettingsWindow.SettingsInset:SetPoint("TOPLEFT", 12, -(SETTINGS_SCROLL_TOP_INSET - 6))
        LanguageSettingsWindow.SettingsInset:SetPoint("BOTTOMRIGHT", -12, SETTINGS_SCROLL_FOOTER_HEIGHT - 6)
        LanguageSettingsWindow.SettingsInset:SetFrameLevel(LanguageSettingsWindow:GetFrameLevel() + 1)
        local settingsBase = LanguageSettingsWindow.SettingsInset:CreateTexture(nil, "BACKGROUND", nil, -8)
        settingsBase:SetAllPoints()
        settingsBase:SetColorTexture(0.06, 0.055, 0.05, 1)

        LanguageSettingsWindow.settingsScrollFrame = CreateFrame("ScrollFrame", "ConcentrationTrackerSettingsScroll", LanguageSettingsWindow, "UIPanelScrollFrameTemplate")
        LanguageSettingsWindow.settingsScrollFrame:SetPoint("TOPLEFT", LanguageSettingsWindow, "TOPLEFT", 24, -(SETTINGS_SCROLL_TOP_INSET + 4))
        LanguageSettingsWindow.settingsScrollFrame:SetFrameLevel(LanguageSettingsWindow.SettingsInset:GetFrameLevel() + 2)
        LanguageSettingsWindow.settingsScrollFrame:SetPoint("BOTTOMRIGHT", LanguageSettingsWindow, "BOTTOMRIGHT", -40, SETTINGS_SCROLL_FOOTER_HEIGHT + 4)

        LanguageSettingsWindow.scrollChild = CreateFrame("Frame", nil, LanguageSettingsWindow.settingsScrollFrame)
        LanguageSettingsWindow.scrollChild:SetWidth(360)
        LanguageSettingsWindow.scrollChild:SetHeight(SETTINGS_SCROLL_CHILD_DEFAULT_HEIGHT)
        LanguageSettingsWindow.settingsScrollFrame:SetScrollChild(LanguageSettingsWindow.scrollChild)
        LanguageSettingsWindow.settingsScrollFrame:SetScript("OnSizeChanged", function()
            RefreshLanguageSettingsScrollRange()
        end)
        LanguageSettingsWindow:EnableMouseWheel(true)
        LanguageSettingsWindow:SetScript("OnMouseWheel", function(_, delta)
            local sf = LanguageSettingsWindow.settingsScrollFrame
            if not sf or not sf.SetVerticalScroll then
                return
            end
            local step = 48
            local cur = sf:GetVerticalScroll() or 0
            local maxScroll = 0
            if sf.GetVerticalScrollRange then
                maxScroll = math.max(0, sf:GetVerticalScrollRange() or 0)
            end
            sf:SetVerticalScroll(math.min(maxScroll, math.max(0, cur - delta * step)))
        end)

        local sp = LanguageSettingsWindow.scrollChild

        -- Секція «Відображення»
        LanguageSettingsWindow.sectionDisplayLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.sectionDisplayLabel:SetPoint("TOPLEFT", sp, "TOPLEFT", 8, -4)
        LanguageSettingsWindow.sectionDisplayLabel:SetTextColor(1, 0.82, 0, 1)
        LanguageSettingsWindow.sectionDisplayLabel:SetText(LOr("section_display", "Display"))

        -- Масштаб вікна
        LanguageSettingsWindow.windowScaleLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.windowScaleLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.sectionDisplayLabel, "BOTTOMLEFT", 0, -8)
        LanguageSettingsWindow.windowScaleLabel:SetText(LOr("window_scale", "Window Scale"))
        LanguageSettingsWindow.windowScaleSlider = CreateFrame("Slider", nil, sp, "OptionsSliderTemplate")
        LanguageSettingsWindow.windowScaleSlider:SetPoint("TOPLEFT", LanguageSettingsWindow.windowScaleLabel, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.windowScaleSlider:SetWidth(180)
        LanguageSettingsWindow.windowScaleSlider:SetMinMaxValues(0.5, 1.5)
        LanguageSettingsWindow.windowScaleSlider:SetValueStep(0.05)
        LanguageSettingsWindow.windowScaleSlider:SetValue(ConcentrationTrackerSettings.windowScale or 1)
        LanguageSettingsWindow.windowScaleSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value * 20) / 20
            ConcentrationTrackerSettings.windowScale = value
            if LanguageSettingsWindow.windowScaleValue then
                LanguageSettingsWindow.windowScaleValue:SetText(string.format("%d%%", value * 100))
            end
            if ConcentrationWindow then
                ConcentrationWindow:SetScale(value)
            end
        end)
        LanguageSettingsWindow.windowScaleValue = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        LanguageSettingsWindow.windowScaleValue:SetPoint("LEFT", LanguageSettingsWindow.windowScaleSlider, "RIGHT", 10, 0)
        LanguageSettingsWindow.windowScaleValue:SetText(string.format("%d%%", (ConcentrationTrackerSettings.windowScale or 1) * 100))

        -- Розмір шрифту
        LanguageSettingsWindow.fontSizeLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.fontSizeLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.windowScaleSlider, "BOTTOMLEFT", 0, -20)
        LanguageSettingsWindow.fontSizeLabel:SetText(LOr("font_size", "Font Size"))
        LanguageSettingsWindow.fontSizeSlider = CreateFrame("Slider", nil, sp, "OptionsSliderTemplate")
        LanguageSettingsWindow.fontSizeSlider:SetPoint("TOPLEFT", LanguageSettingsWindow.fontSizeLabel, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.fontSizeSlider:SetWidth(180)
        LanguageSettingsWindow.fontSizeSlider:SetMinMaxValues(10, 18)
        LanguageSettingsWindow.fontSizeSlider:SetValueStep(1)
        LanguageSettingsWindow.fontSizeSlider:SetValue(ConcentrationTrackerSettings.fontSize or 12)
        LanguageSettingsWindow.fontSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)
            ConcentrationTrackerSettings.fontSize = value
            if LanguageSettingsWindow.fontSizeValue then
                LanguageSettingsWindow.fontSizeValue:SetText(value)
            end
            UpdateLanguageTexts()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.fontSizeValue = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        LanguageSettingsWindow.fontSizeValue:SetPoint("LEFT", LanguageSettingsWindow.fontSizeSlider, "RIGHT", 10, 0)
        LanguageSettingsWindow.fontSizeValue:SetText(ConcentrationTrackerSettings.fontSize or 12)

        LanguageSettingsWindow.transparencyLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.transparencyLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.fontSizeSlider, "BOTTOMLEFT", 0, -20)
        LanguageSettingsWindow.transparencyLabel:SetText(LOr("window_transparency", "Window Transparency"))
        LanguageSettingsWindow.transparencySlider = CreateFrame("Slider", nil, sp, "OptionsSliderTemplate")
        LanguageSettingsWindow.transparencySlider:SetPoint("TOPLEFT", LanguageSettingsWindow.transparencyLabel, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.transparencySlider:SetWidth(200)
        LanguageSettingsWindow.transparencySlider:SetMinMaxValues(0, 100)
        LanguageSettingsWindow.transparencySlider:SetValueStep(1)
        LanguageSettingsWindow.transparencySlider:SetValue((ConcentrationTrackerSettings.transparency or 0.8) * 100)
        LanguageSettingsWindow.transparencySlider:SetScript("OnValueChanged", function(self, value)
            local alpha = value / 100
            ConcentrationTrackerSettings.transparency = alpha
            LanguageSettingsWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
            if ConcentrationWindow then
                ConcentrationWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
            end
            if LanguageSettingsWindow.transparencyValue then
                LanguageSettingsWindow.transparencyValue:SetText(string.format("%d%%", value))
            end
        end)
        LanguageSettingsWindow.transparencySlider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["window_transparency_tooltip"] or "Set window opacity (0% = fully transparent, 100% = fully opaque)")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.transparencySlider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        LanguageSettingsWindow.transparencyValue = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        LanguageSettingsWindow.transparencyValue:SetPoint("LEFT", LanguageSettingsWindow.transparencySlider, "RIGHT", 10, 0)
        LanguageSettingsWindow.transparencyValue:SetText(string.format("%d%%", (ConcentrationTrackerSettings.transparency or 0.8) * 100))

        LanguageSettingsWindow.showRealmCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.showRealmCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.transparencySlider, "BOTTOMLEFT", 0, -14)
        LanguageSettingsWindow.showRealmCheckbox.text = LanguageSettingsWindow.showRealmCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.showRealmCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.showRealmCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.showRealmCheckbox.text:SetText(LOr("show_realm", "Show Character's Realm"))
        LanguageSettingsWindow.showRealmCheckbox:SetChecked(ConcentrationTrackerSettings.showRealm)
        LanguageSettingsWindow.showRealmCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.showRealm = self:GetChecked()
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)

        LanguageSettingsWindow.hideFullCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.hideFullCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.showRealmCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.hideFullCheckbox.text = LanguageSettingsWindow.hideFullCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.hideFullCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.hideFullCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.hideFullCheckbox.text:SetText(LOr("hide_full_concentration", "Hide full concentration"))
        LanguageSettingsWindow.hideFullCheckbox:SetChecked(ConcentrationTrackerSettings.hideFullConcentration == true)
        LanguageSettingsWindow.hideFullCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.hideFullConcentration = self:GetChecked() and true or false
            if ConcentrationWindow and ConcentrationWindow.SyncHideFullButtonText then
                ConcentrationWindow.SyncHideFullButtonText()
            end
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.hideFullCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("hide_full_concentration_tooltip", "Hide rows that are already at maximum concentration."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.hideFullCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.hideStaleCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.hideStaleCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.hideFullCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.hideStaleCheckbox.text = LanguageSettingsWindow.hideStaleCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.hideStaleCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.hideStaleCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.hideStaleCheckbox.text:SetText(LOr("hide_stale_rows", "Hide stale rows"))
        LanguageSettingsWindow.hideStaleCheckbox:SetChecked(ConcentrationTrackerSettings.hideStaleRows == true)
        LanguageSettingsWindow.hideStaleCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.hideStaleRows = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.hideStaleCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("hide_stale_rows_tooltip", "Hide rows that have not been synced in over 24 hours."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.hideStaleCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.hideMoxieOnlyCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.hideStaleCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.hideMoxieOnlyCheckbox.text = LanguageSettingsWindow.hideMoxieOnlyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.hideMoxieOnlyCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.hideMoxieOnlyCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.hideMoxieOnlyCheckbox.text:SetText(LOr("hide_moxie_only_rows", "Hide Moxie-only rows"))
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetChecked(ConcentrationTrackerSettings.hideMoxieOnlyRows == true)
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.hideMoxieOnlyRows = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("hide_moxie_only_rows_tooltip", "Hide profession rows that have Moxie but no concentration data."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.showPercentCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.showPercentCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.hideMoxieOnlyCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.showPercentCheckbox.text = LanguageSettingsWindow.showPercentCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.showPercentCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.showPercentCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.showPercentCheckbox.text:SetText(LOr("show_concentration_percent", "Show concentration %"))
        LanguageSettingsWindow.showPercentCheckbox:SetChecked(ConcentrationTrackerSettings.showConcentrationPercent == true)
        LanguageSettingsWindow.showPercentCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.showConcentrationPercent = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.showPercentCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("show_concentration_percent_tooltip", "Show fill percentage next to concentration (e.g. 750/1000 · 75%)."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.showPercentCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.compactTimeCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.compactTimeCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.showPercentCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.compactTimeCheckbox.text = LanguageSettingsWindow.compactTimeCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.compactTimeCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.compactTimeCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.compactTimeCheckbox.text:SetText(LOr("compact_time_format", "Compact time format"))
        LanguageSettingsWindow.compactTimeCheckbox:SetChecked(ConcentrationTrackerSettings.compactTimeFormat == true)
        LanguageSettingsWindow.compactTimeCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.compactTimeFormat = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.compactTimeCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("compact_time_format_tooltip", "Hide seconds in the time-to-full column (e.g. 12 h 30 m)."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.compactTimeCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.highlightFullCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.highlightFullCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.compactTimeCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.highlightFullCheckbox.text = LanguageSettingsWindow.highlightFullCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.highlightFullCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.highlightFullCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.highlightFullCheckbox.text:SetText(LOr("highlight_full_rows", "Highlight full rows"))
        LanguageSettingsWindow.highlightFullCheckbox:SetChecked(ConcentrationTrackerSettings.highlightFullRows ~= false)
        LanguageSettingsWindow.highlightFullCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.highlightFullRows = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.highlightFullCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("highlight_full_rows_tooltip", "Tint rows that are already at maximum concentration."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.highlightFullCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.autoFilterCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.autoFilterCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.highlightFullCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.autoFilterCheckbox.text = LanguageSettingsWindow.autoFilterCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.autoFilterCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.autoFilterCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.autoFilterCheckbox.text:SetText(LOr("auto_filter_this_character", "Auto-filter to this character"))
        LanguageSettingsWindow.autoFilterCheckbox:SetChecked(ConcentrationTrackerSettings.autoFilterThisCharacter == true)
        LanguageSettingsWindow.autoFilterCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.autoFilterThisCharacter = self:GetChecked() and true or false
        end)
        LanguageSettingsWindow.autoFilterCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("auto_filter_this_character_tooltip", "When opening the main window, filter the list to the logged-in character."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.autoFilterCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.highlightLowCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.highlightLowCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.autoFilterCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.highlightLowCheckbox.text = LanguageSettingsWindow.highlightLowCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.highlightLowCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.highlightLowCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.highlightLowCheckbox.text:SetText(LOr("highlight_low_rows", "Highlight low concentration"))
        LanguageSettingsWindow.highlightLowCheckbox:SetChecked(ConcentrationTrackerSettings.highlightLowRows == true)
        LanguageSettingsWindow.highlightLowCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.highlightLowRows = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.highlightLowCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("highlight_low_rows_tooltip", "Tint rows below 25% concentration (helps spot professions that need regen)."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.highlightLowCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.highlightSoonCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.highlightSoonCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.highlightLowCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.highlightSoonCheckbox.text = LanguageSettingsWindow.highlightSoonCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.highlightSoonCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.highlightSoonCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.highlightSoonCheckbox.text:SetText(LOr("highlight_soon_rows", "Highlight soon-to-fill rows"))
        LanguageSettingsWindow.highlightSoonCheckbox:SetChecked(ConcentrationTrackerSettings.highlightSoonRows == true)
        LanguageSettingsWindow.highlightSoonCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.highlightSoonRows = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.highlightSoonCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("highlight_soon_rows_tooltip", "Tint rows that reach full concentration within 2 hours."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.highlightSoonCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.refreshOnOpenCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.highlightSoonCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.refreshOnOpenCheckbox.text = LanguageSettingsWindow.refreshOnOpenCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.refreshOnOpenCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.refreshOnOpenCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.refreshOnOpenCheckbox.text:SetText(LOr("refresh_on_open", "Refresh on open"))
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetChecked(ConcentrationTrackerSettings.refreshOnOpen == true)
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.refreshOnOpen = self:GetChecked() and true or false
        end)
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("refresh_on_open_tooltip", "When opening the main window, sync this character's concentration and Moxie from the game API."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.refreshOnOpenCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.highlightThisCharCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.highlightThisCharCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.refreshOnOpenCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.highlightThisCharCheckbox.text = LanguageSettingsWindow.highlightThisCharCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.highlightThisCharCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.highlightThisCharCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.highlightThisCharCheckbox.text:SetText(LOr("highlight_this_character", "Mark this character's rows"))
        LanguageSettingsWindow.highlightThisCharCheckbox:SetChecked(ConcentrationTrackerSettings.highlightThisCharacter ~= false)
        LanguageSettingsWindow.highlightThisCharCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.highlightThisCharacter = self:GetChecked() and true or false
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.highlightThisCharCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("highlight_this_character_tooltip", "Show a gold bar on rows that belong to the logged-in character."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.highlightThisCharCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.lockWindowCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.lockWindowCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.highlightThisCharCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.lockWindowCheckbox.text = LanguageSettingsWindow.lockWindowCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.lockWindowCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.lockWindowCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.lockWindowCheckbox.text:SetText(LOr("lock_window", "Lock window"))
        LanguageSettingsWindow.lockWindowCheckbox:SetChecked(ConcentrationTrackerSettings.lockWindow == true)
        LanguageSettingsWindow.lockWindowCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.lockWindow = self:GetChecked() and true or false
            ApplyWindowLock()
        end)
        LanguageSettingsWindow.lockWindowCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("lock_window_tooltip", "Prevent dragging or resizing the main window. /conc resetui recenters it."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.lockWindowCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.hideInCombatCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.hideInCombatCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.lockWindowCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.hideInCombatCheckbox.text = LanguageSettingsWindow.hideInCombatCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.hideInCombatCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.hideInCombatCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.hideInCombatCheckbox.text:SetText(LOr("hide_in_combat", "Hide window in combat"))
        LanguageSettingsWindow.hideInCombatCheckbox:SetChecked(ConcentrationTrackerSettings.hideInCombat == true)
        LanguageSettingsWindow.hideInCombatCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.hideInCombat = self:GetChecked() and true or false
            ns.ApplyHideInCombatSetting()
        end)
        LanguageSettingsWindow.hideInCombatCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("hide_in_combat_tooltip", "Automatically hide the main window when you enter combat, then restore it after combat."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.hideInCombatCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.expansionFilterLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.expansionFilterLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.hideInCombatCheckbox, "BOTTOMLEFT", 0, -12)
        LanguageSettingsWindow.expansionFilterLabel:SetText(LOr("expansion_filter", "Expansion"))

        LanguageSettingsWindow.expansionDropdown = CreateFrame("Frame", "ConcentrationTrackerSettingsExpansionDropdown", LanguageSettingsWindow, "UIDropDownMenuTemplate")
        LanguageSettingsWindow.expansionDropdown:SetPoint("TOPLEFT", LanguageSettingsWindow.expansionFilterLabel, "BOTTOMLEFT", -16, -4)
        UIDropDownMenu_SetWidth(LanguageSettingsWindow.expansionDropdown, 220)
        InitializeExpansionDropdown(LanguageSettingsWindow.expansionDropdown, OnExpansionFilterChanged)
        LanguageSettingsWindow.expansionDropdown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["expansion_filter_tooltip"] or "")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.expansionDropdown:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.sectionColumnsLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.sectionColumnsLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.expansionDropdown, "BOTTOMLEFT", 16, -14)
        LanguageSettingsWindow.sectionColumnsLabel:SetTextColor(1, 0.82, 0, 1)
        LanguageSettingsWindow.sectionColumnsLabel:SetText(L["section_columns"] or "Table columns")

        LanguageSettingsWindow.columnCheckboxes = {}
        local columnAnchor = LanguageSettingsWindow.sectionColumnsLabel
        for idx, col in ipairs(COLUMN_UI_ORDER) do
            local settingKey = COL_SETTING_KEYS[col]
            local headerKey = HEADER_KEYS[col]
            local cb = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", columnAnchor, "BOTTOMLEFT", 0, idx == 1 and -6 or -4)
            cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 0, 0)
            cb.text:SetText(L[headerKey] or headerKey)
            cb.columnIndex = col
            cb.settingKey = settingKey
            cb:SetChecked(ConcentrationTrackerSettings[settingKey] ~= false)
            cb:SetScript("OnClick", function(self)
                if not self:GetChecked() then
                    local vis = GetColumnVisibility()
                    if vis[self.columnIndex] and CountVisibleColumns(vis) <= 1 then
                        self:SetChecked(true)
                        if L and L["col_keep_one_visible"] then
                            print(ADDON_TAG .. L["col_keep_one_visible"])
                        end
                        return
                    end
                end
                ConcentrationTrackerSettings[self.settingKey] = self:GetChecked()
                MarkLayoutDirty()
                UpdateConcentrationTimes()
            end)
            LanguageSettingsWindow.columnCheckboxes[col] = cb
            columnAnchor = cb
        end

        LanguageSettingsWindow.showMoxieCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.showMoxieCheckbox:SetPoint("TOPLEFT", columnAnchor, "BOTTOMLEFT", 0, -12)
        LanguageSettingsWindow.showMoxieCheckbox.text = LanguageSettingsWindow.showMoxieCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.showMoxieCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.showMoxieCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.showMoxieCheckbox.text:SetText(L["show_moxie"] or "Show Moxie in profession list")
        LanguageSettingsWindow.showMoxieCheckbox:SetChecked(ConcentrationTrackerSettings.showMoxie ~= false)
        LanguageSettingsWindow.showMoxieCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.showMoxie = self:GetChecked()
            if self:GetChecked() then
                RefreshCurrentCharacterMoxieFromAPI()
            end
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.showMoxieCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["show_moxie_tooltip"] or "")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.showMoxieCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Секція «Нотифікації»
        LanguageSettingsWindow.sectionNotifLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.sectionNotifLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.showMoxieCheckbox, "BOTTOMLEFT", 0, -18)
        LanguageSettingsWindow.sectionNotifLabel:SetTextColor(1, 0.82, 0, 1)
        LanguageSettingsWindow.sectionNotifLabel:SetText(LOr("section_notifications", "Notifications"))

        LanguageSettingsWindow.notificationsCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.notificationsCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.sectionNotifLabel, "BOTTOMLEFT", 0, -8)
        LanguageSettingsWindow.notificationsCheckbox.text = LanguageSettingsWindow.notificationsCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.notificationsCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.notificationsCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.notificationsCheckbox.text:SetText(LOr("enable_notifications", "Enable Notifications"))
        LanguageSettingsWindow.notificationsCheckbox:SetChecked(ConcentrationTrackerSettings.enableNotifications)
        LanguageSettingsWindow.notificationsCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.enableNotifications = self:GetChecked()
        end)

        LanguageSettingsWindow.notifyMoxieCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.notifyMoxieCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.notificationsCheckbox, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.notifyMoxieCheckbox.text = LanguageSettingsWindow.notifyMoxieCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.notifyMoxieCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.notifyMoxieCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.notifyMoxieCheckbox.text:SetText(L["notify_moxie_600"] or "Notify at 600 Moxie")
        LanguageSettingsWindow.notifyMoxieCheckbox:SetChecked(ConcentrationTrackerSettings.notifyMoxieAt600 ~= false)
        LanguageSettingsWindow.notifyMoxieCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.notifyMoxieAt600 = self:GetChecked()
        end)
        LanguageSettingsWindow.notifyMoxieCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["notify_moxie_600_tooltip"] or "")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.notifyMoxieCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.weeklyTurnInCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.weeklyTurnInCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.notifyMoxieCheckbox, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.weeklyTurnInCheckbox.text = LanguageSettingsWindow.weeklyTurnInCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.weeklyTurnInCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.weeklyTurnInCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.weeklyTurnInCheckbox.text:SetText(LOr("notify_weekly_turnin", "Idiot Alert: weekly quest ready to turn in"))
        LanguageSettingsWindow.weeklyTurnInCheckbox:SetChecked(ConcentrationTrackerSettings.notifyWeeklyTurnIn ~= false)
        LanguageSettingsWindow.weeklyTurnInCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.notifyWeeklyTurnIn = self:GetChecked() and true or false
            ns.UpdateWeeklyTurnInBanner()
        end)
        LanguageSettingsWindow.weeklyTurnInCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LOr("notify_weekly_turnin_tooltip", "Warn when a weekly profession quest is complete in your log but not yet turned in."))
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.weeklyTurnInCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.hideButtonCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.hideButtonCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.weeklyTurnInCheckbox, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.hideButtonCheckbox.text = LanguageSettingsWindow.hideButtonCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.hideButtonCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.hideButtonCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.hideButtonCheckbox.text:SetText(LOr("hide_button", "Hide main button"))
        LanguageSettingsWindow.hideButtonCheckbox:SetChecked(ConcentrationTrackerSettings.hideFloatingButton)
        LanguageSettingsWindow.hideButtonCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.hideFloatingButton = self:GetChecked()
            if ConcentrationTrackerToggleButton then
                if ConcentrationTrackerSettings.hideFloatingButton then
                    ConcentrationTrackerToggleButton:Hide()
                else
                    ConcentrationTrackerToggleButton:Show()
                end
            end
        end)

        LanguageSettingsWindow.minimapHideCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.minimapHideCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.hideButtonCheckbox, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.minimapHideCheckbox.text = LanguageSettingsWindow.minimapHideCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.minimapHideCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.minimapHideCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.minimapHideCheckbox.text:SetText(L["hide_minimap"] or "Hide minimap button")
        LanguageSettingsWindow.minimapHideCheckbox:SetChecked(ConcentrationTrackerSettings.minimap and ConcentrationTrackerSettings.minimap.hide)
        LanguageSettingsWindow.minimapHideCheckbox:SetScript("OnClick", function(self)
            if not ConcentrationTrackerSettings.minimap then
                ConcentrationTrackerSettings.minimap = { hide = false, minimapPos = 220 }
            end
            ConcentrationTrackerSettings.minimap.hide = self:GetChecked()
            ApplyMinimapButtonVisibility()
        end)
        LanguageSettingsWindow.minimapHideCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["hide_minimap_tooltip"] or "")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.minimapHideCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.sectionDataLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.sectionDataLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.minimapHideCheckbox, "BOTTOMLEFT", 0, -14)
        LanguageSettingsWindow.sectionDataLabel:SetTextColor(1, 0.82, 0, 1)
        LanguageSettingsWindow.sectionDataLabel:SetText(L["section_data"] or "Data")

        LanguageSettingsWindow.restoreRateLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.restoreRateLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.sectionDataLabel, "BOTTOMLEFT", 0, -8)
        LanguageSettingsWindow.restoreRateLabel:SetText(L["restore_rate"] or "Restore rate (/hour)")
        LanguageSettingsWindow.restoreRateSlider = CreateFrame("Slider", nil, sp, "OptionsSliderTemplate")
        LanguageSettingsWindow.restoreRateSlider:SetPoint("TOPLEFT", LanguageSettingsWindow.restoreRateLabel, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.restoreRateSlider:SetWidth(200)
        LanguageSettingsWindow.restoreRateSlider:SetMinMaxValues(1, 25)
        LanguageSettingsWindow.restoreRateSlider:SetValueStep(1)
        LanguageSettingsWindow.restoreRateSlider:SetValue(ConcentrationTrackerSettings.restoreRatePerHour or 10)
        LanguageSettingsWindow.restoreRateSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            ConcentrationTrackerSettings.restoreRatePerHour = value
            if LanguageSettingsWindow.restoreRateValue then
                LanguageSettingsWindow.restoreRateValue:SetText(tostring(value))
            end
            MarkLayoutDirty()
            UpdateConcentrationTimes()
        end)
        LanguageSettingsWindow.restoreRateSlider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["restore_rate_tooltip"] or "Typically 10/hour in-game; change if needed.")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.restoreRateSlider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        LanguageSettingsWindow.restoreRateValue = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        LanguageSettingsWindow.restoreRateValue:SetPoint("LEFT", LanguageSettingsWindow.restoreRateSlider, "RIGHT", 10, 0)
        LanguageSettingsWindow.restoreRateValue:SetText(tostring(ConcentrationTrackerSettings.restoreRatePerHour or 10))

        LanguageSettingsWindow.logChatCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.logChatCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.restoreRateSlider, "BOTTOMLEFT", 0, -12)
        LanguageSettingsWindow.logChatCheckbox.text = LanguageSettingsWindow.logChatCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.logChatCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.logChatCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.logChatCheckbox.text:SetText(L["log_updates_chat"] or "Print updates to chat")
        LanguageSettingsWindow.logChatCheckbox:SetChecked(ConcentrationTrackerSettings.logUpdatesToChat)
        LanguageSettingsWindow.logChatCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.logUpdatesToChat = self:GetChecked()
        end)

        LanguageSettingsWindow.notifRaidCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.notifRaidCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.logChatCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.notifRaidCheckbox.text = LanguageSettingsWindow.notifRaidCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.notifRaidCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.notifRaidCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.notifRaidCheckbox.text:SetText(L["notify_raid_warning"] or "Raid warning banner")
        LanguageSettingsWindow.notifRaidCheckbox:SetChecked(ConcentrationTrackerSettings.notificationRaidWarning ~= false)
        LanguageSettingsWindow.notifRaidCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.notificationRaidWarning = self:GetChecked()
        end)

        LanguageSettingsWindow.notifChatCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.notifChatCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.notifRaidCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.notifChatCheckbox.text = LanguageSettingsWindow.notifChatCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.notifChatCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.notifChatCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.notifChatCheckbox.text:SetText(L["notify_chat_message"] or "Also print to chat")
        LanguageSettingsWindow.notifChatCheckbox:SetChecked(ConcentrationTrackerSettings.notificationChat)
        LanguageSettingsWindow.notifChatCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.notificationChat = self:GetChecked()
        end)

        LanguageSettingsWindow.notifSoundCheckbox = CreateFrame("CheckButton", nil, sp, "UICheckButtonTemplate")
        LanguageSettingsWindow.notifSoundCheckbox:SetPoint("TOPLEFT", LanguageSettingsWindow.notifChatCheckbox, "BOTTOMLEFT", 0, -4)
        LanguageSettingsWindow.notifSoundCheckbox.text = LanguageSettingsWindow.notifSoundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.notifSoundCheckbox.text:SetPoint("LEFT", LanguageSettingsWindow.notifSoundCheckbox, "RIGHT", 0, 0)
        LanguageSettingsWindow.notifSoundCheckbox.text:SetText(L["notify_sound"] or "Play sound")
        LanguageSettingsWindow.notifSoundCheckbox:SetChecked(ConcentrationTrackerSettings.notificationSound ~= false)
        LanguageSettingsWindow.notifSoundCheckbox:SetScript("OnClick", function(self)
            ConcentrationTrackerSettings.notificationSound = self:GetChecked()
        end)

        LanguageSettingsWindow.sectionIgnoredLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.sectionIgnoredLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.notifSoundCheckbox, "BOTTOMLEFT", 0, -14)
        LanguageSettingsWindow.sectionIgnoredLabel:SetTextColor(1, 0.82, 0, 1)
        LanguageSettingsWindow.sectionIgnoredLabel:SetText(L["section_ignored_professions"] or "Ignored variants")

        LanguageSettingsWindow.ignoredHint = sp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        LanguageSettingsWindow.ignoredHint:SetPoint("TOPLEFT", LanguageSettingsWindow.sectionIgnoredLabel, "BOTTOMLEFT", 0, -6)
        LanguageSettingsWindow.ignoredHint:SetWidth(360)
        LanguageSettingsWindow.ignoredHint:SetJustifyH("LEFT")
        LanguageSettingsWindow.ignoredHint:SetWordWrap(true)
        LanguageSettingsWindow.ignoredHint:SetTextColor(0.65, 0.65, 0.65, 1)
        LanguageSettingsWindow.ignoredHint:SetText(L["ignored_professions_hint"] or "")

        LanguageSettingsWindow.ignoredCountLabel = sp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LanguageSettingsWindow.ignoredCountLabel:SetPoint("TOPLEFT", LanguageSettingsWindow.ignoredHint, "BOTTOMLEFT", 0, -8)
        LanguageSettingsWindow.ignoredCountLabel:SetText("")

        LanguageSettingsWindow.clearIgnoredButton = CreateFrame("Button", nil, sp, "UIPanelButtonTemplate")
        LanguageSettingsWindow.clearIgnoredButton:SetPoint("TOPLEFT", LanguageSettingsWindow.ignoredCountLabel, "BOTTOMLEFT", 0, -8)
        LanguageSettingsWindow.clearIgnoredButton:SetHeight(22)
        LanguageSettingsWindow.clearIgnoredButton:SetWidth(200)
        LanguageSettingsWindow.clearIgnoredButton:SetText(L["clear_ignored_professions"] or "Clear ignored list")
        LanguageSettingsWindow.clearIgnoredButton:SetScript("OnClick", function()
            RegisterClearIgnoredDialog()
            StaticPopup_Show("CONFIRM_CLEAR_IGNORED_SKILL_LINES")
        end)
        LanguageSettingsWindow.clearIgnoredButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["clear_ignored_professions_tooltip"] or "")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.clearIgnoredButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.closeButton = CreateFrame("Button", nil, LanguageSettingsWindow, "UIPanelButtonTemplate")
        LanguageSettingsWindow.closeButton:SetSize(96, 26)
        LanguageSettingsWindow.closeButton:SetPoint("BOTTOMRIGHT", LanguageSettingsWindow, "BOTTOMRIGHT", -14, 16)
        LanguageSettingsWindow.closeButton:SetText(LOr("close", "Close"))
        LanguageSettingsWindow.closeButton:SetScript("OnClick", function()
            LanguageSettingsWindow:Hide()
        end)

        LanguageSettingsWindow.resetTransparencyButton = CreateFrame("Button", nil, LanguageSettingsWindow, "UIPanelButtonTemplate")
        LanguageSettingsWindow.resetTransparencyButton:SetText(LOr("reset_short", "Reset"))
        local rtw = math.max(88, LanguageSettingsWindow.resetTransparencyButton:GetTextWidth() + 24)
        LanguageSettingsWindow.resetTransparencyButton:SetSize(rtw, 26)
        LanguageSettingsWindow.resetTransparencyButton:SetPoint("RIGHT", LanguageSettingsWindow.closeButton, "LEFT", -10, 0)
        LanguageSettingsWindow.resetTransparencyButton:SetScript("OnClick", function()
            StaticPopup_Show("CONFIRM_RESET_CONCENTRATION_TRACKER")
        end)
        LanguageSettingsWindow.resetTransparencyButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["reset_to_factory"] or "Reset to Factory Defaults")
            GameTooltip:Show()
        end)
        LanguageSettingsWindow.resetTransparencyButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        LanguageSettingsWindow.scrollRangeAnchor = CreateFrame("Frame", nil, sp)
        LanguageSettingsWindow.scrollRangeAnchor:SetPoint("TOPLEFT", LanguageSettingsWindow.clearIgnoredButton, "BOTTOMLEFT", 0, -16)
        LanguageSettingsWindow.scrollRangeAnchor:SetSize(1, 1)

        RefreshLanguageSettingsScrollRange()
    end

    LanguageSettingsWindow:SetSize(420, 520)
    if RefreshIgnoredProfessionsSettingsUI then
        RefreshIgnoredProfessionsSettingsUI()
    end
    RefreshLanguageSettingsScrollRange()
    LanguageSettingsWindow:Show()
    C_Timer.After(0.05, RefreshLanguageSettingsScrollRange)
end

RegisterResetConfirmDialog = function()
    StaticPopupDialogs["CONFIRM_RESET_CONCENTRATION_TRACKER"] = {
        text = LOr("confirm_reset", "Are you sure you want to reset all addon settings and data?"),
        button1 = LOr("yes", "Yes"),
        button2 = LOr("no", "No"),
        OnAccept = function()
            ConcentrationTrackerDB = {}
            ConcentrationTrackerSettings = GetDefaultSettings()
            RebuildIgnoredSkillLineSet()
            EnsureLocalization()
            -- Показуємо головну кнопку після скидання
            if ConcentrationTrackerToggleButton then
                ConcentrationTrackerToggleButton:Show()
            end
            if LanguageSettingsWindow and LanguageSettingsWindow.minimapHideCheckbox then
                LanguageSettingsWindow.minimapHideCheckbox:SetChecked(false)
            end
            ApplyMinimapButtonVisibility()
            ApplyMainWindowVisualSettings()
            RegisterResetConfirmDialog() -- оновлюємо текст діалогу після зміни мови
            UpdateLanguageTexts()
            UpdateConcentrationTimes()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

RegisterDeleteEntryDialog = function()
    StaticPopupDialogs["CONFIRM_DELETE_CONCENTRATION_ENTRY"] = {
        text = LOr("confirm_delete_entry", "Are you sure you want to delete this entry?"),
        button1 = LOr("yes", "Yes"),
        button2 = LOr("no", "No"),
        OnAccept = function(self, data)
            if data and data.key then
                ConcentrationTrackerDB[data.key] = nil
                AfterConcentrationDataChanged()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

RegisterStopTrackingDialog = function()
    StaticPopupDialogs["CONFIRM_STOP_TRACKING_SKILLLINE"] = {
        text = L["confirm_stop_tracking"] or "Stop tracking %s (%s)?",
        button1 = L["yes"] or "Yes",
        button2 = L["no"] or "No",
        OnAccept = function(_, data)
            if data and data.key and data.skillLineID then
                AddIgnoredSkillLine(data.skillLineID)
                ConcentrationTrackerDB[data.key] = nil
                if RefreshIgnoredProfessionsSettingsUI then
                    RefreshIgnoredProfessionsSettingsUI()
                end
                AfterConcentrationDataChanged()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

RegisterClearIgnoredDialog = function()
    StaticPopupDialogs["CONFIRM_CLEAR_IGNORED_SKILL_LINES"] = {
        text = L["confirm_clear_ignored"] or "Clear all ignored profession variants?",
        button1 = L["yes"] or "Yes",
        button2 = L["no"] or "No",
        OnAccept = function()
            ClearAllIgnoredSkillLines()
            if RefreshIgnoredProfessionsSettingsUI then
                RefreshIgnoredProfessionsSettingsUI()
            end
            AfterConcentrationDataChanged()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

RefreshIgnoredProfessionsSettingsUI = function()
    if not LanguageSettingsWindow or not ConcentrationTrackerSettings then return end
    EnsureLocalization()
    if LanguageSettingsWindow.ignoredCountLabel then
        local n = IgnoredSkillLineCount()
        LanguageSettingsWindow.ignoredCountLabel:SetText(string.format(L["ignored_count"] or "Ignored: %d", n))
    end
    if LanguageSettingsWindow.clearIgnoredButton then
        LanguageSettingsWindow.clearIgnoredButton:SetEnabled(IgnoredSkillLineCount() > 0)
    end
    RefreshLanguageSettingsScrollRange()
end

function UpdateLanguageTexts()
    if ConcentrationTrackerSettings then
        EnsureLocalization()
    end
    if ConcentrationWindow then
        ApplyMainWindowVisualSettings()
        local fs = (ConcentrationTrackerSettings and ConcentrationTrackerSettings.fontSize) or 12
        ConcentrationWindow.title:SetFont(ADDON_FONT, fs + 1, "")
        UpdateMainWindowTitle()
        ConcentrationWindow.settingsButton:SetText(L["settings"])
        if ConcentrationWindow.refreshButton then
            ConcentrationWindow.refreshButton:SetText(L["refresh"])
            ConcentrationWindow.refreshButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["refresh_tooltip"] or "Refresh data now")
            end)
        end

        for i, headerButton in ipairs(headerButtons) do
            local key = HEADER_KEYS[i]
            if key then
                headerButton.text:SetText(L[key] or key)
            end
        end

        UpdateConcentrationTimes()

        if ConcentrationWindow.professionDropdown and InitializeProfessionDropdown then
            UIDropDownMenu_Initialize(ConcentrationWindow.professionDropdown, InitializeProfessionDropdown)
            if ConcentrationTrackerSettings.selectedProfession == "All" then
                UIDropDownMenu_SetText(ConcentrationWindow.professionDropdown, L["all_professions"] or "All")
            else
                UIDropDownMenu_SetText(
                    ConcentrationWindow.professionDropdown,
                    ConcentrationTrackerSettings.selectedProfession or (L["select_profession"] or "")
                )
            end
        end
        RefreshCharacterDropdown()
        RefreshExpansionDropdowns()

        if ConcentrationWindow.thisCharButton then
            if ConcentrationWindow.FitToolbarButton then
                ConcentrationWindow.FitToolbarButton(ConcentrationWindow.thisCharButton, L["this_character"] or "This char", 64)
            else
                ConcentrationWindow.thisCharButton:SetText(L["this_character"] or "This char")
            end
            ConcentrationWindow.thisCharButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["this_character_tooltip"] or "Toggle filter to the logged-in character.")
                GameTooltip:Show()
            end)
        end
        if ConcentrationWindow.hideFullButton then
            if ConcentrationWindow.SyncHideFullButtonText then
                ConcentrationWindow.SyncHideFullButtonText()
            end
            ConcentrationWindow.hideFullButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["hide_full_concentration_tooltip"] or "Hide rows that are already at maximum concentration.")
                GameTooltip:Show()
            end)
        end
        if ConcentrationWindow.resetFiltersButton then
            if ConcentrationWindow.FitToolbarButton then
                ConcentrationWindow.FitToolbarButton(
                    ConcentrationWindow.resetFiltersButton,
                    L["reset_filters_short"] or L["reset_filters"] or "Clear",
                    56
                )
            else
                ConcentrationWindow.resetFiltersButton:SetText(L["reset_filters_short"] or "Clear")
            end
            ConcentrationWindow.resetFiltersButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["reset_filters_tooltip"] or "Reset expansion, profession, character, and search filters.")
                GameTooltip:Show()
            end)
        end
        if ConcentrationWindow.searchBox then
            ns.SyncSearchBox()
            ConcentrationWindow.searchBox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["search_tooltip"] or "Filter by character, realm, or profession.")
                GameTooltip:Show()
            end)
        end
        UpdateThisCharButtonState()

        if ConcentrationWindow.calculateButton then
            ConcentrationWindow.calculateButton:SetText(LOr("calculate", "Forecast"))
        end
        if ConcentrationWindow.targetInput and ConcentrationWindow.targetInput.Instructions then
            ConcentrationWindow.targetInput.Instructions:SetText(LOr("enter_target_amount", "Enter target..."))
        end
    end

    -- Оновлюємо текст плаваючої кнопки при зміні мови
    if ConcentrationTrackerToggleButton and ConcentrationTrackerToggleButton.text then
        ConcentrationTrackerToggleButton.text:SetText(L["toggle_button"] or "Conc. Tracker")
    end

    if LanguageSettingsWindow then
        LanguageSettingsWindow.title:SetText(L["settings_window_title"] or L["settings"])
        if LanguageSettingsWindow.versionLabel then
            LanguageSettingsWindow.versionLabel:SetText(string.format(L["version_label"] or "Version %s", ADDON_VERSION))
        end
        LanguageSettingsWindow.closeButton:SetText(L["close"])
        if LanguageSettingsWindow.fontSizeLabel then
            LanguageSettingsWindow.fontSizeLabel:SetText(L["font_size"])
        end
        if LanguageSettingsWindow.fontSizeValue then
            LanguageSettingsWindow.fontSizeValue:SetText(ConcentrationTrackerSettings.fontSize or 12)
        end
        if LanguageSettingsWindow.sectionDisplayLabel then
            LanguageSettingsWindow.sectionDisplayLabel:SetText(L["section_display"])
        end
        if LanguageSettingsWindow.windowScaleLabel then
            LanguageSettingsWindow.windowScaleLabel:SetText(L["window_scale"])
        end
        if LanguageSettingsWindow.windowScaleValue then
            LanguageSettingsWindow.windowScaleValue:SetText(string.format("%d%%", (ConcentrationTrackerSettings.windowScale or 1) * 100))
        end
        if LanguageSettingsWindow.sectionNotifLabel then
            LanguageSettingsWindow.sectionNotifLabel:SetText(L["section_notifications"])
        end
        LanguageSettingsWindow.showRealmCheckbox.text:SetText(L["show_realm"])
        if LanguageSettingsWindow.hideFullCheckbox and LanguageSettingsWindow.hideFullCheckbox.text then
            LanguageSettingsWindow.hideFullCheckbox.text:SetText(L["hide_full_concentration"] or "Hide full concentration")
            LanguageSettingsWindow.hideFullCheckbox:SetChecked(ConcentrationTrackerSettings.hideFullConcentration == true)
            LanguageSettingsWindow.hideFullCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["hide_full_concentration_tooltip"] or "Hide rows that are already at maximum concentration.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.hideStaleCheckbox and LanguageSettingsWindow.hideStaleCheckbox.text then
            LanguageSettingsWindow.hideStaleCheckbox.text:SetText(L["hide_stale_rows"] or "Hide stale rows")
            LanguageSettingsWindow.hideStaleCheckbox:SetChecked(ConcentrationTrackerSettings.hideStaleRows == true)
            LanguageSettingsWindow.hideStaleCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["hide_stale_rows_tooltip"] or "Hide rows that have not been synced in over 24 hours.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.hideMoxieOnlyCheckbox and LanguageSettingsWindow.hideMoxieOnlyCheckbox.text then
            LanguageSettingsWindow.hideMoxieOnlyCheckbox.text:SetText(L["hide_moxie_only_rows"] or "Hide Moxie-only rows")
            LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetChecked(ConcentrationTrackerSettings.hideMoxieOnlyRows == true)
            LanguageSettingsWindow.hideMoxieOnlyCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["hide_moxie_only_rows_tooltip"] or "Hide profession rows that have Moxie but no concentration data.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.showPercentCheckbox and LanguageSettingsWindow.showPercentCheckbox.text then
            LanguageSettingsWindow.showPercentCheckbox.text:SetText(L["show_concentration_percent"] or "Show concentration %")
            LanguageSettingsWindow.showPercentCheckbox:SetChecked(ConcentrationTrackerSettings.showConcentrationPercent == true)
            LanguageSettingsWindow.showPercentCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["show_concentration_percent_tooltip"] or "Show fill percentage next to concentration.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.compactTimeCheckbox and LanguageSettingsWindow.compactTimeCheckbox.text then
            LanguageSettingsWindow.compactTimeCheckbox.text:SetText(L["compact_time_format"] or "Compact time format")
            LanguageSettingsWindow.compactTimeCheckbox:SetChecked(ConcentrationTrackerSettings.compactTimeFormat == true)
            LanguageSettingsWindow.compactTimeCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["compact_time_format_tooltip"] or "Hide seconds in the time-to-full column.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.highlightFullCheckbox and LanguageSettingsWindow.highlightFullCheckbox.text then
            LanguageSettingsWindow.highlightFullCheckbox.text:SetText(L["highlight_full_rows"] or "Highlight full rows")
            LanguageSettingsWindow.highlightFullCheckbox:SetChecked(ConcentrationTrackerSettings.highlightFullRows ~= false)
            LanguageSettingsWindow.highlightFullCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["highlight_full_rows_tooltip"] or "Tint rows that are already at maximum concentration.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.autoFilterCheckbox and LanguageSettingsWindow.autoFilterCheckbox.text then
            LanguageSettingsWindow.autoFilterCheckbox.text:SetText(L["auto_filter_this_character"] or "Auto-filter to this character")
            LanguageSettingsWindow.autoFilterCheckbox:SetChecked(ConcentrationTrackerSettings.autoFilterThisCharacter == true)
            LanguageSettingsWindow.autoFilterCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["auto_filter_this_character_tooltip"] or "When opening the main window, filter the list to the logged-in character.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.highlightLowCheckbox and LanguageSettingsWindow.highlightLowCheckbox.text then
            LanguageSettingsWindow.highlightLowCheckbox.text:SetText(L["highlight_low_rows"] or "Highlight low concentration")
            LanguageSettingsWindow.highlightLowCheckbox:SetChecked(ConcentrationTrackerSettings.highlightLowRows == true)
            LanguageSettingsWindow.highlightLowCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["highlight_low_rows_tooltip"] or "Tint rows below 25% concentration.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.highlightSoonCheckbox and LanguageSettingsWindow.highlightSoonCheckbox.text then
            LanguageSettingsWindow.highlightSoonCheckbox.text:SetText(L["highlight_soon_rows"] or "Highlight soon-to-fill rows")
            LanguageSettingsWindow.highlightSoonCheckbox:SetChecked(ConcentrationTrackerSettings.highlightSoonRows == true)
            LanguageSettingsWindow.highlightSoonCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["highlight_soon_rows_tooltip"] or "Tint rows that reach full concentration within 2 hours.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.refreshOnOpenCheckbox and LanguageSettingsWindow.refreshOnOpenCheckbox.text then
            LanguageSettingsWindow.refreshOnOpenCheckbox.text:SetText(L["refresh_on_open"] or "Refresh on open")
            LanguageSettingsWindow.refreshOnOpenCheckbox:SetChecked(ConcentrationTrackerSettings.refreshOnOpen == true)
            LanguageSettingsWindow.refreshOnOpenCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["refresh_on_open_tooltip"] or "When opening the main window, sync this character from the game API.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.highlightThisCharCheckbox and LanguageSettingsWindow.highlightThisCharCheckbox.text then
            LanguageSettingsWindow.highlightThisCharCheckbox.text:SetText(L["highlight_this_character"] or "Mark this character's rows")
            LanguageSettingsWindow.highlightThisCharCheckbox:SetChecked(ConcentrationTrackerSettings.highlightThisCharacter ~= false)
            LanguageSettingsWindow.highlightThisCharCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["highlight_this_character_tooltip"] or "Show a gold bar on rows that belong to the logged-in character.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.lockWindowCheckbox and LanguageSettingsWindow.lockWindowCheckbox.text then
            LanguageSettingsWindow.lockWindowCheckbox.text:SetText(L["lock_window"] or "Lock window")
            LanguageSettingsWindow.lockWindowCheckbox:SetChecked(ConcentrationTrackerSettings.lockWindow == true)
            LanguageSettingsWindow.lockWindowCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["lock_window_tooltip"] or "Prevent dragging or resizing the main window.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.hideInCombatCheckbox and LanguageSettingsWindow.hideInCombatCheckbox.text then
            LanguageSettingsWindow.hideInCombatCheckbox.text:SetText(L["hide_in_combat"] or "Hide window in combat")
            LanguageSettingsWindow.hideInCombatCheckbox:SetChecked(ConcentrationTrackerSettings.hideInCombat == true)
            LanguageSettingsWindow.hideInCombatCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["hide_in_combat_tooltip"] or "Automatically hide the main window when you enter combat.")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.expansionFilterLabel then
            LanguageSettingsWindow.expansionFilterLabel:SetText(L["expansion_filter"] or "Expansion")
        end
        if LanguageSettingsWindow.expansionDropdown then
            LanguageSettingsWindow.expansionDropdown:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["expansion_filter_tooltip"] or "")
                GameTooltip:Show()
            end)
        end
        RefreshExpansionDropdowns()
        if LanguageSettingsWindow.sectionColumnsLabel then
            LanguageSettingsWindow.sectionColumnsLabel:SetText(L["section_columns"] or "Columns")
        end
        if LanguageSettingsWindow.columnCheckboxes then
            for col, cb in pairs(LanguageSettingsWindow.columnCheckboxes) do
                if cb.text and HEADER_KEYS[col] then
                    cb.text:SetText(L[HEADER_KEYS[col]] or HEADER_KEYS[col])
                end
                if cb.settingKey then
                    cb:SetChecked(ConcentrationTrackerSettings[cb.settingKey] ~= false)
                end
            end
        end
        if LanguageSettingsWindow.showMoxieCheckbox and LanguageSettingsWindow.showMoxieCheckbox.text then
            LanguageSettingsWindow.showMoxieCheckbox.text:SetText(L["show_moxie"] or "Show Moxie in profession list")
            LanguageSettingsWindow.showMoxieCheckbox:SetChecked(ConcentrationTrackerSettings.showMoxie ~= false)
            LanguageSettingsWindow.showMoxieCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["show_moxie_tooltip"] or "")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.notifyMoxieCheckbox and LanguageSettingsWindow.notifyMoxieCheckbox.text then
            LanguageSettingsWindow.notifyMoxieCheckbox.text:SetText(L["notify_moxie_600"] or "Notify at 600 Moxie")
            LanguageSettingsWindow.notifyMoxieCheckbox:SetChecked(ConcentrationTrackerSettings.notifyMoxieAt600 ~= false)
            LanguageSettingsWindow.notifyMoxieCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["notify_moxie_600_tooltip"] or "")
                GameTooltip:Show()
            end)
        end
        if LanguageSettingsWindow.weeklyTurnInCheckbox and LanguageSettingsWindow.weeklyTurnInCheckbox.text then
            LanguageSettingsWindow.weeklyTurnInCheckbox.text:SetText(L["notify_weekly_turnin"] or "Idiot Alert: weekly quest ready to turn in")
            LanguageSettingsWindow.weeklyTurnInCheckbox:SetChecked(ConcentrationTrackerSettings.notifyWeeklyTurnIn ~= false)
            LanguageSettingsWindow.weeklyTurnInCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["notify_weekly_turnin_tooltip"] or "Warn when a weekly profession quest is complete in your log but not yet turned in.")
                GameTooltip:Show()
            end)
        end
        LanguageSettingsWindow.notificationsCheckbox.text:SetText(L["enable_notifications"])
        if LanguageSettingsWindow.hideButtonCheckbox and LanguageSettingsWindow.hideButtonCheckbox.text then
            LanguageSettingsWindow.hideButtonCheckbox.text:SetText(L["hide_button"] or "Hide main button")
        end
        if LanguageSettingsWindow.minimapHideCheckbox and LanguageSettingsWindow.minimapHideCheckbox.text then
            LanguageSettingsWindow.minimapHideCheckbox.text:SetText(L["hide_minimap"] or "Hide minimap button")
            LanguageSettingsWindow.minimapHideCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["hide_minimap_tooltip"] or "")
                GameTooltip:Show()
            end)
        end
        UIDropDownMenu_SetText(LanguageSettingsWindow.languageDropdown, GetLanguageDisplayName(ConcentrationTrackerSettings.language or "en"))

        -- Оновлення елементів прозорості
        if LanguageSettingsWindow.transparencyLabel then
            LanguageSettingsWindow.transparencyLabel:SetText(L["window_transparency"])
        end
        if LanguageSettingsWindow.transparencySlider then
            LanguageSettingsWindow.transparencySlider:SetValue((ConcentrationTrackerSettings.transparency or DEFAULT_SETTINGS.transparency) * 100)
        end
        if LanguageSettingsWindow.transparencyValue then
            local current = (ConcentrationTrackerSettings.transparency or DEFAULT_SETTINGS.transparency) * 100
            LanguageSettingsWindow.transparencyValue:SetText(string.format("%d%%", current))
        end
        if LanguageSettingsWindow.resetTransparencyButton then
            LanguageSettingsWindow.resetTransparencyButton:SetText(L["reset_short"] or "Reset")
        end
        -- Оновлюємо тултіп для слайдера
        if LanguageSettingsWindow.transparencySlider then
            LanguageSettingsWindow.transparencySlider:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["window_transparency_tooltip"])
            end)
            LanguageSettingsWindow.transparencySlider:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
        end
        LanguageSettingsWindow:SetBackdropColor(0.65, 0.65, 0.65, 1)
        if LanguageSettingsWindow.sectionDataLabel then
            LanguageSettingsWindow.sectionDataLabel:SetText(L["section_data"] or "Data")
        end
        if LanguageSettingsWindow.restoreRateLabel then
            LanguageSettingsWindow.restoreRateLabel:SetText(L["restore_rate"] or "Restore rate (/hour)")
        end
        if LanguageSettingsWindow.restoreRateSlider then
            LanguageSettingsWindow.restoreRateSlider:SetValue(ConcentrationTrackerSettings.restoreRatePerHour or 10)
        end
        if LanguageSettingsWindow.restoreRateValue then
            LanguageSettingsWindow.restoreRateValue:SetText(tostring(ConcentrationTrackerSettings.restoreRatePerHour or 10))
        end
        if LanguageSettingsWindow.logChatCheckbox and LanguageSettingsWindow.logChatCheckbox.text then
            LanguageSettingsWindow.logChatCheckbox.text:SetText(L["log_updates_chat"] or "Print updates to chat")
            LanguageSettingsWindow.logChatCheckbox:SetChecked(ConcentrationTrackerSettings.logUpdatesToChat)
        end
        if LanguageSettingsWindow.notifRaidCheckbox and LanguageSettingsWindow.notifRaidCheckbox.text then
            LanguageSettingsWindow.notifRaidCheckbox.text:SetText(L["notify_raid_warning"] or "Raid warning banner")
            LanguageSettingsWindow.notifRaidCheckbox:SetChecked(ConcentrationTrackerSettings.notificationRaidWarning ~= false)
        end
        if LanguageSettingsWindow.notifChatCheckbox and LanguageSettingsWindow.notifChatCheckbox.text then
            LanguageSettingsWindow.notifChatCheckbox.text:SetText(L["notify_chat_message"] or "Also print to chat")
            LanguageSettingsWindow.notifChatCheckbox:SetChecked(ConcentrationTrackerSettings.notificationChat)
        end
        if LanguageSettingsWindow.notifSoundCheckbox and LanguageSettingsWindow.notifSoundCheckbox.text then
            LanguageSettingsWindow.notifSoundCheckbox.text:SetText(L["notify_sound"] or "Play sound")
            LanguageSettingsWindow.notifSoundCheckbox:SetChecked(ConcentrationTrackerSettings.notificationSound ~= false)
        end
        if LanguageSettingsWindow.sectionIgnoredLabel then
            LanguageSettingsWindow.sectionIgnoredLabel:SetText(L["section_ignored_professions"] or "")
        end
        if LanguageSettingsWindow.ignoredHint then
            LanguageSettingsWindow.ignoredHint:SetText(L["ignored_professions_hint"] or "")
        end
        if LanguageSettingsWindow.clearIgnoredButton then
            LanguageSettingsWindow.clearIgnoredButton:SetText(L["clear_ignored_professions"] or "Clear ignored list")
        end
        RegisterDeleteEntryDialog()
        RegisterStopTrackingDialog()
        RegisterClearIgnoredDialog()
        RegisterResetConfirmDialog()
        if RefreshIgnoredProfessionsSettingsUI then
            RefreshIgnoredProfessionsSettingsUI()
        end
        RefreshLanguageSettingsScrollRange()
    end
end

-- ===========================================================
-- 5. ПОДІЇ ТА КОМАНДИ
-- ===========================================================
-- OnEvent тримає лише 2 upvalues (addonName, ns). Решта логіки — окремі
-- функції на ns, інакше Lua 5.1 падає: "function has more than 60 upvalues".

function ns.HandleSlashCommand(msg)
    if tostring(msg or ""):lower():match("^%s*logincheck%s*$") then
        RefreshCurrentCharacterConcentrationFromAPI()
        print(ADDON_TAG .. "Login scan for " .. (UnitName("player") or "?"))
        for _, line in ipairs(ns.loginScanDiagnostics or {}) do print(line) end
        return
    end
    local m = FirstSlashArg(msg)
    if m == "toggle" or m == "t" then
        if ConcentrationWindow and ConcentrationWindow:IsShown() then
            ConcentrationWindow:Hide()
        else
            ShowConcentrationWindow()
        end
    elseif m == "close" or m == "hide" then
        if ConcentrationWindow then
            ConcentrationWindow:Hide()
        end
    elseif m == "refresh" or m == "r" then
        PerformConcentrationRefresh({ notifyChat = true })
    elseif m == "status" or m == "s" then
        PrintCurrentCharacterStatus()
    elseif m == "me" or m == "self" then
        local meKey = GetCurrentPlayerFilterKey()
        if meKey then
            ConcentrationTrackerSettings.selectedCharacter = meKey
        end
        ShowConcentrationWindow()
    elseif m == "next" or m == "n" then
        PrintNextToFull()
    elseif m == "clear" or m == "filters" then
        ResetAllFilters({ notifyChat = true })
    elseif m == "moxie" or m == "mx" or m == "mox" then
        PrintCurrentCharacterMoxie()
    elseif m == "lowest" or m == "lo" or m == "low" then
        PrintLowestConcentration()
    elseif m == "stale" or m == "old" then
        PrintStaleRows()
    elseif m == "chars" or m == "characters" or m == "alts" then
        PrintTrackedCharacters()
    elseif m == "full" then
        ns.PrintFullRows()
    elseif m == "soon" or m == "2h" then
        ns.PrintSoonRows(tonumber((msg or ""):match("%S+%s+([%d%.]+)")))
    elseif m == "list" or m == "visible" or m == "rows" then
        ns.PrintVisibleRows()
    elseif m == "combat" then
        ns.ToggleHideInCombat({ notifyChat = true })
    elseif m == "search" or m == "find" then
        local rest = (msg or ""):match("^%s*%S+%s+(.-)%s*$")
        ns.SetSearchText(rest or "", { notifyChat = true })
    elseif m == "export" then
        ns.ExportVisibleRows()
    elseif m == "oldest" then
        ns.PrintOldestRow()
    elseif m == "ignored" or m == "ignore" then
        ns.PrintIgnoredSkillLines()
    elseif m == "notify" or m == "alerts" then
        ns.ToggleNotifications({ notifyChat = true })
    elseif m == "weekly" or m == "turnin" or m == "idiot" then
        ns.PrintWeeklyTurnIns()
    elseif m == "focus" or m == "jump" then
        ns.FocusNextToFull({ notifyChat = true })
    elseif m == "hidefull" or m == "hf" then
        ns.ToggleHideFull({ notifyChat = true })
    elseif m == "percent" or m == "pct" then
        ns.ToggleConcentrationPercent({ notifyChat = true })
    elseif m == "compact" then
        ns.ToggleCompactTime({ notifyChat = true })
    elseif m == "today" or m == "daily" then
        ns.PrintTodayRows()
    elseif m == "totals" or m == "sum" or m == "summary" then
        ns.PrintAccountTotals()
    elseif m == "focuslow" or m == "flo" or m == "lowfocus" then
        ns.FocusLowest({ notifyChat = true })
    elseif m == "hidestale" or m == "hs" then
        ns.ToggleHideStale({ notifyChat = true })
    elseif m == "highlight" or m == "hl" or m == "soonhl" then
        ns.ToggleHighlightSoon({ notifyChat = true })
    elseif m == "week" or m == "wreset" then
        ns.PrintWeekRows()
    elseif m == "missing" or m == "gap" or m == "deficit" then
        ns.PrintMissingConcentration()
    elseif m == "moxiecap" or m == "m600" then
        ns.PrintMoxieAtThreshold(tonumber((msg or ""):match("%S+%s+(%d+)")))
    elseif m == "spend" or m == "usable" then
        ns.PrintSpendableRows(tonumber((msg or ""):match("%S+%s+(%d+)")))
    elseif m == "prof" or m == "profession" then
        ns.PrintProfessionRows((msg or ""):match("^%s*%S+%s+(.-)%s*$") or "")
    elseif m == "hidemoxie" or m == "hmo" then
        ns.ToggleHideMoxieOnly({ notifyChat = true })
    elseif m == "lowlight" or m == "lowhl" then
        ns.ToggleHighlightLow({ notifyChat = true })
    elseif m == "below" or m == "under" then
        ns.PrintBelowFill(tonumber((msg or ""):match("%S+%s+(%d+)")))
    elseif m == "char" or m == "alt" then
        ns.PrintCharacterRows((msg or ""):match("^%s*%S+%s+(.-)%s*$") or "")
    elseif m == "autoself" or m == "autome" then
        ns.ToggleAutoFilterThisCharacter({ notifyChat = true })
    elseif m == "refreshopen" or m == "ro" then
        ns.ToggleRefreshOnOpen({ notifyChat = true })
    elseif m == "reach" or m == "target" then
        ns.PrintReachRows(tonumber((msg or ""):match("%S+%s+(%d+)")))
    elseif m == "exp" or m == "expansion" then
        ns.PrintExpansionRows((msg or ""):match("^%s*%S+%s+(.-)%s*$") or "")
    elseif m == "sort" then
        ns.SetSortColumn((msg or ""):match("^%s*%S+%s+(%S+)"))
    elseif m == "col" or m == "column" then
        ns.ToggleTableColumn((msg or ""):match("^%s*%S+%s+(%S+)"))
    elseif m == "rate" then
        ns.PrintOrSetRestoreRate(tonumber((msg or ""):match("%S+%s+([%d%.]+)")))
    elseif m == "chatlog" or m == "updates" then
        ns.ToggleLogUpdates({ notifyChat = true })
    elseif m == "sound" then
        ns.ToggleNotificationSound({ notifyChat = true })
    elseif m == "top" or m == "best" then
        ns.PrintTopRows(tonumber((msg or ""):match("%S+%s+(%d+)")))
    elseif m == "avg" or m == "average" then
        ns.PrintFillAverage()
    elseif m == "scale" then
        ns.PrintOrSetWindowScale(tonumber((msg or ""):match("%S+%s+([%d%.]+)")))
    elseif m == "font" then
        ns.PrintOrSetFontSize(tonumber((msg or ""):match("%S+%s+([%d%.]+)")))
    elseif m == "showmoxie" or m == "sm" then
        ns.ToggleShowMoxie({ notifyChat = true })
    elseif m == "last" or m == "eta" then
        ns.PrintLastToFull()
    elseif m == "alpha" or m == "opacity" then
        ns.PrintOrSetOpacity(tonumber((msg or ""):match("%S+%s+([%d%.]+)")))
    elseif m == "markme" then
        ns.ToggleHighlightThisCharacter({ notifyChat = true })
    elseif m == "fullhl" or m == "fullmark" then
        ns.ToggleHighlightFull({ notifyChat = true })
    elseif m == "realm" then
        ns.ToggleShowRealm({ notifyChat = true })
    elseif m == "copy" then
        ns.CopyCurrentCharacterStatus()
    elseif m == "minimap" or m == "mm" then
        ns.ToggleMinimapButton({ notifyChat = true })
    elseif m == "lock" then
        ns.ToggleWindowLock({ notifyChat = true })
    elseif m == "settings" or m == "cfg" or m == "opt" or m == "options" then
        CreateLanguageSettingsWindow()
    elseif m == "resetui" then
        ResetAddonUI({ notifyChat = true })
    elseif m == "version" or m == "v" then
        PrintAddonVersion()
    elseif m == "help" or m == "?" then
        PrintSlashHelp()
    else
        ShowConcentrationWindow()
    end
end

function ns.RegisterLDB()
    if not LibStub then
        return
    end
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb or ldb:GetDataObjectByName("ConcentrationTracker") then
        return
    end
    ldbObject = ldb:NewDataObject("ConcentrationTracker", {
        type = "launcher",
        text = L["addon_name"] or "Concentration Tracker",
        icon = "Interface\\Icons\\INV_Misc_CuriousCoin",
        OnClick = function(_, button)
            if button == "RightButton" then
                CreateLanguageSettingsWindow()
            elseif ConcentrationWindow and ConcentrationWindow:IsShown() then
                ConcentrationWindow:Hide()
            else
                ShowConcentrationWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            EnsureLocalization()
            tooltip:AddLine("|cFFFFFF00" .. (L["addon_name"] or "Concentration Tracker") .. "|r")
            tooltip:AddLine(L["minimap_open"] or "Click to open window")
            tooltip:AddLine("|cFF00FF00" .. (L["right_click"] or "Right-Click") .. "|r: " .. (L["settings"] or "Settings"))
            local nf, tot = LDBConcentrationSummary()
            if tot > 0 then
                tooltip:AddLine(string.format(L["ldb_not_full"] or "Not at cap: %d / %d", nf, tot), 0.8, 0.8, 0.8)
            end
            local nextEntry = FindNextToFullEntry(false)
            if nextEntry then
                local who = nextEntry.charName
                if ConcentrationTrackerSettings.showRealm then
                    who = FormatCharacterFilterLabel(nextEntry.charName, nextEntry.realm)
                end
                tooltip:AddLine(string.format(
                    LOr("summary_next", "Next: %s (%s) %s"),
                    who,
                    nextEntry.professionName,
                    nextEntry.timeToFull
                ), 0.55, 0.85, 0.55)
            end
            local lastEntry = ns.CollectLastToFull()
            if lastEntry then
                local whoLast = lastEntry.charName
                if ConcentrationTrackerSettings.showRealm then
                    whoLast = FormatCharacterFilterLabel(lastEntry.charName, lastEntry.realm)
                end
                tooltip:AddLine(string.format(
                    LOr("summary_last", "Last: %s (%s) %s"),
                    whoLast,
                    lastEntry.professionName,
                    lastEntry.timeToFull or ""
                ), 0.75, 0.65, 0.95)
            end
            local lowestEntry = FindLowestConcentrationEntry(false)
            if lowestEntry then
                local whoLow = lowestEntry.charName
                if ConcentrationTrackerSettings.showRealm then
                    whoLow = FormatCharacterFilterLabel(lowestEntry.charName, lowestEntry.realm)
                end
                tooltip:AddLine(string.format(
                    LOr("summary_lowest", "Lowest: %s (%s) %d%%"),
                    whoLow,
                    lowestEntry.professionName,
                    lowestEntry.fillPercent or 0
                ), 0.95, 0.7, 0.45)
            end
            tooltip:AddLine(L["slash_hint"] or "/conc, /conclanguage", 0.6, 0.6, 0.6)
            if L["slash_toggle"] then
                tooltip:AddLine(L["slash_toggle"], 0.55, 0.55, 0.55)
            end
            if L["slash_refresh"] then
                tooltip:AddLine(L["slash_refresh"], 0.5, 0.5, 0.5)
            end
            if L["slash_status"] then
                tooltip:AddLine(L["slash_status"], 0.48, 0.48, 0.48)
            end
            if L["slash_me"] then
                tooltip:AddLine(L["slash_me"], 0.45, 0.45, 0.45)
            end
            local soonRows = ns.CollectSoonRows(2, false)
            if #soonRows > 0 then
                tooltip:AddLine(string.format(LOr("summary_soon", "(%d soon)"), #soonRows), 0.95, 0.82, 0.4)
            end
            local todayRows = ns.CollectTodayRows(false)
            if #todayRows > 0 then
                tooltip:AddLine(string.format(LOr("summary_today", "(%d before reset)"), #todayRows), 0.7, 0.9, 0.95)
            end
            local weekRows = ns.CollectWeekRows(false)
            if #weekRows > 0 then
                tooltip:AddLine(string.format(LOr("summary_week", "(%d this week)"), #weekRows), 0.55, 0.75, 0.95)
            end
            local spendRows = ns.CollectSpendableRows()
            if #spendRows > 0 then
                tooltip:AddLine(string.format(LOr("summary_spend", "(%d ready)"), #spendRows), 0.65, 0.9, 0.65)
            end
            local belowRows = ns.CollectBelowFillRows()
            if #belowRows > 0 then
                tooltip:AddLine(string.format(LOr("summary_below", "(%d under 25%%)"), #belowRows), 0.95, 0.55, 0.45)
            end
            local avgPct = ns.CollectFillAverage()
            if avgPct then
                tooltip:AddLine(string.format(LOr("summary_avg", "(%d%% avg)"), avgPct), 0.75, 0.85, 1)
            end
            local weeklyReady = ns.CollectReadyProfessionWeeklies()
            if #weeklyReady > 0 then
                tooltip:AddLine(string.format(LOr("summary_weekly", "Turn in: %d"), #weeklyReady), 1, 0.82, 0.25)
                tooltip:AddLine(ns.FormatWeeklyTurnInLine(weeklyReady[1]), 1, 0.75, 0.2)
            end
        end,
    })
    UpdateLDBText()
end

function ns.MarkLoadedRowsAlreadyAtCap()
    for _, data in pairs(ConcentrationTrackerDB) do
        if type(data) == "table" and data.lastUpdate and data.quantity ~= nil and not data.notifiedAtFull then
            local maxQ = GetEffectiveMaxQuantity(data.maxQuantity)
            local updatedQ = select(1, GetRestorationTimes(data.lastUpdate, data.quantity, maxQ))
            if updatedQ >= maxQ then
                data.notifiedAtFull = true
            end
        end
        if type(data) == "table" then
            local mq = tonumber(data.moxieQuantity) or 0
            local moxieCID = tonumber(data.moxieCurrencyID)
            if mq >= MOXIE_NOTIFY_THRESHOLD then
                if not data.notifiedAtMoxie600 then
                    data.notifiedAtMoxie600 = true
                end
                if moxieCID and data.entryChar and data.entryRealm then
                    local skey = MoxieNotifySettingsKey(data.entryChar, data.entryRealm, moxieCID)
                    ConcentrationTrackerSettings.moxieNotifiedAt600[skey] = true
                end
            end
            if moxieCID and data.entryChar and data.entryRealm then
                local skey = MoxieNotifySettingsKey(data.entryChar, data.entryRealm, moxieCID)
                if ConcentrationTrackerSettings.moxieLastQuantity[skey] == nil then
                    ConcentrationTrackerSettings.moxieLastQuantity[skey] = mq
                end
            end
        end
    end
end

function ns.StartBackgroundTimers()
    frame.loginSyncTimer = C_Timer.NewTimer(3, function()
        frame.loginSyncTimer = nil
        RefreshCurrentCharacterConcentrationFromAPI()
        RefreshCurrentCharacterMoxieFromAPI()
        CheckConcentrationNotifications()
        UpdateLDBText()
    end)
    frame.notificationTicker = C_Timer.NewTicker(30, function()
        CheckConcentrationNotifications()
        UpdateLDBText()
    end)
    frame.moxiePollTicker = C_Timer.NewTicker(MOXIE_POLL_INTERVAL, function()
        RefreshCurrentCharacterMoxieFromAPI()
    end)
end

function ns.OnAddonLoaded()
    CancelAddonTimers()
    ADDON_VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
        or ADDON_VERSION
    ConcentrationTrackerDB = ConcentrationTrackerDB or {}
    ConcentrationTrackerSettings = ConcentrationTrackerSettings or GetDefaultSettings()
    MigrateConcentrationDB()
    PurgeDuplicateMoxieOnlyRows()
    PurgeStaleMoxieOnlyRows()
    ReconcileAllStoredMoxieCurrencies()
    BackfillExpansionKeys()
    SanitizeSettings()
    EnsureMoxieNotifiedTable()
    EnsureColumnSettings()
    if not LanguageSettingsWindowIsComplete(LanguageSettingsWindow or _G.LanguageSettingsWindow) then
        DestroyLanguageSettingsWindow()
    end
    RebuildIgnoredSkillLineSet()
    SanitizeAllFilters()
    ns.MarkLoadedRowsAlreadyAtCap()
    EnsureLocalization()
    RegisterResetConfirmDialog()
    RegisterDeleteEntryDialog()
    RegisterStopTrackingDialog()
    RegisterClearIgnoredDialog()

    SLASH_CONCLANGUAGE1 = "/conclanguage"
    SlashCmdList["CONCLANGUAGE"] = CreateLanguageSettingsWindow
    SLASH_CONCENTRATION1 = "/conc"
    SlashCmdList["CONCENTRATION"] = ns.HandleSlashCommand

    CreateAddonToggleButton()
    CreateMinimapButton()
    if ConcentrationTrackerSettings.hideFloatingButton and ConcentrationTrackerToggleButton then
        ConcentrationTrackerToggleButton:Hide()
    end
    ns.RegisterLDB()
    ns.StartBackgroundTimers()
end

function ns.OnCurrencyDisplayUpdate(arg1)
    if not ConcentrationTrackerDB then
        return
    end
    local currencyID = tonumber(arg1)
    if currencyID then
        SyncStorageFromCurrencyDisplay(currencyID)
        if SyncMoxieFromCurrencyDisplay(currencyID) then
            AfterConcentrationDataChanged()
        end
    else
        RefreshCurrentCharacterConcentrationFromAPI()
        RefreshCurrentCharacterMoxieFromAPI()
    end
end

function ns.OnPlayerEnteringWorld()
    InvalidatePlayerProfessionCache()
    if not ConcentrationTrackerDB then
        return
    end
    PurgeAbandonedProfessionMoxieForCurrentPlayer()
    ScheduleWorldSyncRefresh()
    if frame.worldEnterTimer then
        frame.worldEnterTimer:Cancel()
        frame.worldEnterTimer = nil
    end
    frame.worldEnterTimer = C_Timer.NewTimer(2, function()
        frame.worldEnterTimer = nil
        if ConcentrationTrackerDB then
            RefreshCurrentCharacterMoxieFromAPI()
            CheckConcentrationNotifications()
        end
    end)
end

function ns.OnProfessionEvent(event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        InvalidatePlayerProfessionCache()
    end
    RecordConcentration()
end

function ns.OnGameEvent(event, arg1)
    if event == "PLAYER_LOGOUT" then
        CancelAddonTimers()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        ns.OnCurrencyDisplayUpdate(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.OnPlayerEnteringWorld()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        ns.OnProfessionEvent(event)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ConcentrationTrackerSettings and ConcentrationTrackerSettings.hideInCombat then
            ns.HideMainWindowForCombat()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.RestoreMainWindowAfterCombat()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
        ns.ScheduleWeeklyTurnInCheck()
    end
end

local function OnEvent(_, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            ns.OnAddonLoaded()
        end
        return
    end
    ns.OnGameEvent(event, arg1, ...)
end

frame:SetScript("OnEvent", OnEvent)

-- ===========================================================
-- 6. ФУНКЦІЯ СТВОРЕННЯ КНОПКИ ДЛЯ ВІДКРИТТЯ/ЗАКРИТТЯ
-- ===========================================================
function CreateAddonToggleButton()
    if ConcentrationTrackerToggleButton then
        return
    end
    local toggleButton = CreateFrame("Button", "ConcentrationTrackerToggleButton", UIParent, "BackdropTemplate")
    toggleButton:SetSize(115, 25)
    toggleButton:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    
    toggleButton:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    toggleButton:SetBackdropColor(0, 0, 0, 0.8)
    toggleButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

    local text = toggleButton:CreateFontString(nil, "OVERLAY")
    text:SetFont(ADDON_FONT, 12, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(L["toggle_button"] or "Conc. Tracker")
    toggleButton.text = text

    toggleButton:SetMovable(true)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", toggleButton.StartMoving)
    toggleButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ConcentrationTrackerSettings then
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
            ConcentrationTrackerSettings.buttonPosition = { point, relativePoint, xOfs, yOfs }
        end
    end)

    toggleButton:SetScript("OnClick", function()
        if ConcentrationWindow and ConcentrationWindow:IsShown() then
            ConcentrationWindow:Hide()
        else
            ShowConcentrationWindow()
        end
    end)

    toggleButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        ShowToggleButtonTooltip(self)
    end)
    toggleButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0.8)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
        GameTooltip:Hide()
    end)

    if ConcentrationTrackerSettings.buttonPosition and ConcentrationTrackerSettings.buttonPosition[1] then
        local pos = ConcentrationTrackerSettings.buttonPosition
        toggleButton:ClearAllPoints()
        toggleButton:SetPoint(pos[1], UIParent, pos[2] or "CENTER", pos[3] or 0, pos[4] or -200)
    end
end

-- ===========================================================
-- 7. ФУНКЦІЯ СТВОРЕННЯ КНОПКИ НА МІНІ-КАРТІ
-- ===========================================================
function CreateMinimapButton()
    if ConcentrationTrackerMinimapButton then
        return
    end
    local MinimapButton = CreateFrame("Button", "ConcentrationTrackerMinimapButton", Minimap)
    MinimapButton:SetSize(31, 31)
    MinimapButton:SetFrameLevel(8)
    MinimapButton:SetToplevel(true)
    MinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = MinimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(21, 21)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = MinimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_CuriousCoin")
    icon:SetPoint("TOPLEFT", 7, -5)

    local border = MinimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local function UpdatePosition()
        if not ConcentrationTrackerSettings or not ConcentrationTrackerSettings.minimap then
            return
        end
        local angle = ConcentrationTrackerSettings.minimap.minimapPos or 220
        local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
        local rx, ry = Minimap:GetWidth() / 2 + 3, Minimap:GetHeight() / 2 + 3
        local shapes = {
            ROUND = {true,true,true,true}, SQUARE = {false,false,false,false},
            ["CORNER-TOPLEFT"] = {false,false,false,true},
            ["CORNER-TOPRIGHT"] = {false,false,true,false},
            ["CORNER-BOTTOMLEFT"] = {false,true,false,false},
            ["CORNER-BOTTOMRIGHT"] = {true,false,false,false},
            ["SIDE-LEFT"] = {false,true,false,true},
            ["SIDE-RIGHT"] = {true,false,true,false},
            ["SIDE-TOP"] = {false,false,true,true},
            ["SIDE-BOTTOM"] = {true,true,false,false},
            ["TRICORNER-TOPLEFT"] = {false,true,true,true},
            ["TRICORNER-TOPRIGHT"] = {true,false,true,true},
            ["TRICORNER-BOTTOMLEFT"] = {true,true,false,true},
            ["TRICORNER-BOTTOMRIGHT"] = {true,true,true,false},
        }
        local q = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
        local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
        if not (shapes[shape] or shapes.ROUND)[q] then
            local factor = 1 / math.max(math.abs(x), math.abs(y))
            x, y = x * factor, y * factor
        end
        MinimapButton:ClearAllPoints()
        MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
    end

    MinimapButton:SetMovable(true)
    MinimapButton:RegisterForDrag("LeftButton")
    MinimapButton:SetScript("OnDragStart", function(self)
        EnsureMinimapSettings()
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            ConcentrationTrackerSettings.minimap.minimapPos = angle
            UpdatePosition()
        end)
    end)

    MinimapButton:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)

    MinimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if ConcentrationWindow and ConcentrationWindow:IsShown() then
                ConcentrationWindow:Hide()
            else
                ShowConcentrationWindow()
            end
        elseif button == "RightButton" then
            CreateLanguageSettingsWindow()
        end
    end)

    MinimapButton:SetScript("OnEnter", function(self)
        EnsureLocalization()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFFF00" .. (L["addon_name"] or "Concentration Tracker") .. "|r")
        GameTooltip:AddLine(L["minimap_open"] or "Left-Click to open window")
        GameTooltip:AddLine("|cFF00FF00" .. (L["right_click"] or "Right-Click") .. "|r: " .. (L["settings"] or "Settings"))
        local nf, tot = LDBConcentrationSummary()
        if tot > 0 then
            GameTooltip:AddLine(string.format(L["ldb_not_full"] or "Not at cap: %d / %d", nf, tot), 0.8, 0.8, 0.8)
        end
        local nextEntry = FindNextToFullEntry(false)
        if nextEntry then
            local who = nextEntry.charName
            if ConcentrationTrackerSettings.showRealm then
                who = FormatCharacterFilterLabel(nextEntry.charName, nextEntry.realm)
            end
            GameTooltip:AddLine(string.format(
                LOr("summary_next", "Next: %s (%s) %s"),
                who,
                nextEntry.professionName,
                nextEntry.timeToFull
            ), 0.55, 0.85, 0.55)
        end
        GameTooltip:AddLine("Drag to move around the minimap", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    MinimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Minimap:HookScript("OnSizeChanged", UpdatePosition)
    MinimapButton:HookScript("OnShow", UpdatePosition)
    local geometryCheck = CreateFrame("Frame", nil, MinimapButton)
    local elapsedSinceCheck = 0
    geometryCheck:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceCheck = elapsedSinceCheck + elapsed
        if elapsedSinceCheck >= 1 then
            elapsedSinceCheck = 0
            UpdatePosition()
        end
    end)
    UpdatePosition()
    ApplyMinimapButtonVisibility()
end
