"""Exercise the actual Retail startup and tooltip callbacks in Lua 5.1.

Run with lupa installed. Mocks verify behavior, not live-client rendering.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/ProfessionAssistance_Edit"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
addonName = "ProfessionAssistance_Edit"
ns = {}; frames = {}; timers = {}; settings = {}; prices = {}; queries = {}
SlashCmdList = {}; metadata = {}; uncached = {}; itemOverrides = {}
WOW_PROJECT_ID = 1; WOW_PROJECT_CLASSIC = 2; WOW_PROJECT_MISTS_CLASSIC = 19
WOW_PROJECT_CATACLYSM_CLASSIC = 14; WOW_PROJECT_WRATH_CLASSIC = 11
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
ARMOR = "Armor"; WEAPON = "Weapon"; ZONE = "Zone"
ITEM_QUALITY_COLORS = {}
for i = 0, 7 do
    ITEM_QUALITY_COLORS[i] = {hex = "|cffffffff"}
    _G["ITEM_QUALITY" .. i .. "_DESC"] = "Quality" .. i
end
function GetLocale() return "enUS" end
function IsShiftKeyDown() return shiftDown or false end
-- Current Retail exposes this only through C_CurrencyInfo. Do not invent the
-- removed global: doing so hid a real failure before the first material row.
GetCoinTextureString = nil
C_CurrencyInfo = {GetCoinTextureString = function(price) return "coins:" .. price end}
function itemID(item)
    if type(item) == "number" then return item end
    return type(item) == "string" and tonumber(item:match("item:(%d+)")) or nil
end
function link(id) return "|cffffffff|Hitem:" .. id .. ":0|h[Material " .. id .. "]|h|r" end
function GetItemInfoFromHyperlink(item) return itemID(item) end
C_Item = {
    GetItemInfo = function(item)
        local id = itemID(item)
        if not id or uncached[id] then return end
        local o = itemOverrides[id] or {}
        return "Material " .. id, link(id), o.quality or 2, 100, 1, "", "",
            200, o.equipLoc or "", 123, 0, o.class or 7, 0, 0, o.expansion or 0
    end,
    GetItemIconByID = function() return 123 end,
    IsCosmeticItem = function() return false end,
}
C_Map = {GetMapInfo = function(id) return {name = "Zone " .. id} end}
C_AddOns = {GetAddOnMetadata = function(name, key)
    assert(name == addonName, "metadata lookup used original addon name")
    assert(metadata[key], "missing TOC metadata: " .. key)
    return metadata[key]
end}
local frameMethods = {}
function frameMethods:RegisterEvent(event) self.event = event end
function frameMethods:SetScript(event, fn) self[event] = fn end
function frameMethods:CreateFontString()
    return {SetPoint = function() end, SetJustifyH = function() end,
        SetText = function(_, text) assert(type(text) == "string") end}
end
function CreateFrame(kind, name)
    assert(kind == "Frame")
    local frame = setmetatable({name = name}, {__index = frameMethods})
    frames[#frames + 1] = frame
    return frame
end
Settings = {}
function Settings.RegisterVerticalLayoutCategory(name)
    assert(name == addonName)
    return {GetID = function() return 73 end}, {AddInitializer = function() end}
end
function Settings.RegisterAddOnCategory() end
function Settings.RegisterAddOnSetting(category, variable, key, saved, valueType, label, default)
    assert(type(saved[key]) == valueType)
    settings[key] = {saved = saved, default = default}
    return settings[key]
end
function Settings.CreateCheckbox() return {SetParentInitializer = function() end} end
function Settings.RegisterCanvasLayoutSubcategory() end
function Settings.OpenToCategory(id) assert(id == 73); opened = (opened or 0) + 1 end
function CreateSettingsListSectionHeaderInitializer(label) return {label = label} end
Enum = {TooltipDataType = {Item = 0}}
TooltipDataProcessor = {AddTooltipPostCall = function(kind, callback)
    assert(kind == Enum.TooltipDataType.Item and not tooltipCallback)
    tooltipCallback = callback
end}
TooltipUtil = {GetDisplayedItem = function(tooltip) return "item", tooltip.item end}
C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}
function flushTimers()
    local pending = timers; timers = {}
    for _, callback in ipairs(pending) do callback() end
end
Item = {}
function Item:CreateFromItemID(id)
    return {ContinueOnItemLoad = function(_, callback) callback() end,
        GetItemLink = function() return link(id) end}
end
function Item:CreateFromItemLink(value) return self:CreateFromItemID(itemID(value)) end
function enableAuctionator()
    Auctionator = {API = {v1 = {GetAuctionPriceByItemID = function(caller, id)
        assert(caller == addonName and type(id) == "number")
        queries[#queries + 1] = id
        if throwPrice then error("database not ready") end
        return prices[id]
    end}}}
end
enableAuctionator()
local tooltipMethods = {}
function tooltipMethods:GetName() return self.name end
function tooltipMethods:NumLines() return #self.lines end
function tooltipMethods:IsShown() return self.shown end
function tooltipMethods:Show() self.shown = true end
function tooltipMethods:AddLine(left, ...)
    self.lines[#self.lines + 1] = {left = tostring(left)}
    local line = self.lines[#self.lines]
    _G[self.name .. "TextLeft" .. #self.lines] = {
        GetText = function() return line.left end,
        SetText = function(_, value) line.left = value end,
    }
end
function tooltipMethods:AddDoubleLine(left, right, ...)
    self:AddLine(left)
    self.lines[#self.lines].right = right
end
function tooltipMethods:Reset(id)
    self.item = link(id); self.lines = {}; self.shown = true
    self:AddLine("Original item line")
end
function tooltip(id, name)
    local result = setmetatable({name = name or "GameTooltip"}, {__index = tooltipMethods})
    result:Reset(id)
    return result
end
function render(id, name)
    local result = tooltip(id, name); tooltipCallback(result); return result
end
function materialRow(tooltip, id)
    for _, row in ipairs(tooltip.lines) do
        if row.left:find("|Hitem:" .. id .. ":", 1, true) then return row end
    end
    error("missing material row " .. id)
end
function contains(tooltip, text)
    for _, row in ipairs(tooltip.lines) do
        if row.left:find(text, 1, true) or (row.right and row.right:find(text, 1, true)) then return true end
    end
    return false
end
''')

toc = (ADDON / "ProfessionAssistance_Edit.toc").read_text(encoding="utf-8")
assert "## OptionalDeps: Auctionator" in toc
assert "## SavedVariables: PA_SavedSettings" in toc
loader = lua.eval("function(code, name) return assert(loadstring(code, name))(addonName, ns) end")
for line in toc.splitlines():
    if line.startswith("## "):
        key, value = line[3:].split(":", 1)
        lua.globals().metadata[key] = value.strip()
    elif line.strip() and not line.startswith("#"):
        source = ADDON / line.strip()
        assert source.name in {p.name for p in ADDON.iterdir()}, "TOC filename case mismatch"
        loader(source.read_text(encoding="utf-8-sig"), source.name)

lua.execute(r'''
-- The real TOC load, ADDON_LOADED and both settings entry points.
assert(#render(765).lines == 1, "tooltip ran before settings initialization")
frames[1].OnEvent(frames[1], "ADDON_LOADED", "Profession_Assistance")
assert(not PA_SavedSettings)
PA_SavedSettings = {MillingIconChecked = true, OreKey = true}
frames[1].OnEvent(frames[1], "ADDON_LOADED", addonName)
assert(PA_SavedSettings.MillingIconChecked and PA_SavedSettings.OreKey)
assert(settings.AuctionatorPrices.default and PA_SavedSettings.AuctionatorPrices)
SlashCmdList.PA(); ProfessionAssistance_OnAddonCompartmentClick(addonName, "LeftButton")
assert(opened == 2 and SLASH_PA4 == "/ProfessionAssistance_Edit")
PA_SavedSettings.OreKey = false

-- Audit every Retail expansion/rarity entry, not only Dawn Crystals on blues.
-- Duplicate expansion IDs previously hid Midnight's epic results entirely.
for _, quality in ipairs({2, 3, 4}) do
    local expansions = {}
    for _, entry in ipairs(table_gear[quality]) do
        assert(not expansions[entry.expansion], "duplicate disenchant expansion " .. entry.expansion)
        expansions[entry.expansion] = true
        for _, slot in ipairs({"armor", "weapon"}) do
            for _, group in ipairs(entry[slot].items) do
                assert(group.chance ~= "±30%" and group.chance ~= "±35%", "unverified bonus group remains")
            end
        end
    end
    for expansion = 0, 11 do assert(expansions[expansion], "missing disenchant expansion " .. expansion) end
end
for _, entry in pairs(table_disenchant) do
    for _, group in ipairs(entry.text) do
        assert(group.chance ~= "±30%" and group.chance ~= "±35%", "reverse source still advertises bonus")
    end
end

-- Reported failure: a rare Midnight helm stopped after its 100% heading when
-- the first material had a price and the old global coin formatter was absent.
itemOverrides[270477] = {quality = 3, class = 4, equipLoc = "INVTYPE_HEAD", expansion = 11}
prices[243602] = 123456; prices[243603] = 234567
prices[243605] = 345678; prices[243606] = nil
local midnightHelm = render(270477)
assert(not contains(midnightHelm, "%"))
assert(materialRow(midnightHelm, 243602).right == "coins:123456")
assert(materialRow(midnightHelm, 243603).right == "coins:234567")
assert(not contains(midnightHelm, "|Hitem:243605:"))
assert(not contains(midnightHelm, "|Hitem:243606:"))

-- A missing/broken formatter must never hide the material or later groups.
local currencyAPI = C_CurrencyInfo
prices[243603] = nil
for _, brokenFormatter in ipairs({
    {},
    {GetCoinTextureString = function() error("formatter failure") end},
    {GetCoinTextureString = function() return nil end},
    {GetCoinTextureString = function() return "" end},
}) do
    C_CurrencyInfo = brokenFormatter
    local degraded = render(270477)
    assert(materialRow(degraded, 243602).right == "Price unavailable")
    assert(materialRow(degraded, 243603).right == "No price")
end
C_CurrencyInfo = nil
assert(materialRow(render(270477), 243602).right == "Price unavailable")
C_CurrencyInfo = currencyAPI
prices[243603] = 234567

-- Reviewed primary materials, every quality rank and both armor/weapon paths.
-- Constants are independently checked item IDs, not read back from the addon.
local expectedMaterials = {
    [9] = {[2] = {194123}, [3] = {194124}, [4] = {200113}},
    [10] = {[2] = {219946, 219947, 219948}, [3] = {219949, 219950, 219951}, [4] = {219952, 219954, 219955}},
    [11] = {[2] = {243599, 243600}, [3] = {243602, 243603}, [4] = {243605, 243606}},
}
for expansion, qualities in pairs(expectedMaterials) do
    for quality, materialIDs in pairs(qualities) do
        for _, materialID in ipairs(materialIDs) do prices[materialID] = materialID end
        for _, class in ipairs({2, 4}) do
            local gearID = 910000 + expansion * 100 + quality * 10 + class
            itemOverrides[gearID] = {class = class, quality = quality, expansion = expansion,
                equipLoc = class == 2 and "INVTYPE_WEAPON" or "INVTYPE_CHEST"}
            for _, tooltipName in ipairs({"GameTooltip", "ItemRefTooltip"}) do
                local result = render(gearID, tooltipName); flushTimers()
                assert(not contains(result, "%"), "disenchant probability still visible")
                local materialCount = 0
                for _, row in ipairs(result.lines) do
                    if row.left:find("|Hitem:", 1, true) then materialCount = materialCount + 1 end
                end
                assert(materialCount == #materialIDs, "wrong result count for expansion/quality " .. expansion .. "/" .. quality)
                for _, materialID in ipairs(materialIDs) do
                    assert(materialRow(result, materialID).right == "coins:" .. materialID)
                end
            end
        end
        for _, materialID in ipairs(materialIDs) do
            local result = render(materialID)
            assert(not contains(result, "%"), "reverse source probability still visible")
            assert(contains(result, "Quality" .. quality), "reverse source quality mismatch")
            for _, otherQuality in ipairs({2, 3, 4}) do
                if otherQuality ~= quality then assert(not contains(result, "Quality" .. otherQuality)) end
            end
        end
    end
end

-- Actual milling and prospecting data; prices are per item, not chance-weighted.
prices[39151] = 123456
local herb = render(765)
assert(materialRow(herb, 39151).right == "coins:123456")
assert(contains(herb, "100%") and contains(herb, "Auctionator / each"))
assert(contains(herb, "|T123:14|t"), "existing icon setting was lost")
local ore = render(2770)
local gem = table_ore[2770].items[1][1]
assert(materialRow(ore, gem).right == "No price")
prices[gem] = 8765
assert(materialRow(render(2770), gem).right == "coins:8765", "scan update was cached away")

-- Reverse source lists, material nodes and non-item node descriptions.
prices[765] = 72
assert(materialRow(render(39151), 765).right == "coins:72")
prices[785] = 18; prices[2450] = 45
local nodes = render(2452)
assert(materialRow(nodes, 785).right == "coins:18")
assert(materialRow(nodes, 2450).right == "coins:45")
local before = #queries
local generic = tooltip(765)
ns.AddMaterialLine(generic, "Frozen Herb", "Frozen Herb")
assert(#queries == before and generic.lines[2].right == nil)

-- Disenchant results from actual gear data and renamed expansion artwork.
itemOverrides[900001] = {class = 4, equipLoc = "INVTYPE_CHEST", expansion = 1}
prices[22445] = 2345
local gear = render(900001)
assert(materialRow(gear, 22445).right == "coins:2345")
assert(contains(gear, "Interface\\AddOns\\ProfessionAssistance_Edit\\Images\\bc.tga"))

-- Missing dependency, disabled setting, incomplete API and failed database calls.
Auctionator = nil
assert(materialRow(render(765), 39151).right == nil)
Auctionator = {API = {v1 = {}}}
assert(materialRow(render(765), 39151).right == nil)
enableAuctionator()
PA_SavedSettings.AuctionatorPrices = false
assert(materialRow(render(765), 39151).right == nil)
PA_SavedSettings.AuctionatorPrices = true
throwPrice = true
assert(materialRow(render(765), 39151).right == "No price")
throwPrice = false
for _, badPrice in ipairs({0, -1, "invalid", math.huge, 0/0}) do
    prices[39151] = badPrice
    assert(materialRow(render(765), 39151).right == "No price")
end
prices[39151] = 123456

-- Numeric IDs still price uncached items; quality IDs stay separate.
uncached[39151] = true
local uncachedTip = render(765)
assert(contains(uncachedTip, "39151") and contains(uncachedTip, "coins:123456"))
uncached[39151] = nil
local ranked = tooltip(765)
prices[210796] = 101; prices[210797] = 202
ns.AddMaterialLine(ranked, 210796, link(210796))
ns.AddMaterialLine(ranked, link(210797), link(210797))
assert(materialRow(ranked, 210796).right == "coins:101")
assert(materialRow(ranked, 210797).right == "coins:202")

-- The actual deferred chat-link path mutates IDs into links; both must price.
local chat = render(765, "ItemRefTooltip")
flushTimers()
assert(materialRow(chat, 39151).right == "coins:123456")
assert(materialRow(render(765), 39151).right == "coins:123456")
local reused = tooltip(765, "ItemRefTooltip")
tooltipCallback(reused); tooltipCallback(reused); flushTimers()
local count = 0
for _, row in ipairs(reused.lines) do if row.right == "coins:123456" then count = count + 1 end end
assert(count == 1, "deferred tooltip appended duplicate prices")
local replaced = render(765, "ItemRefTooltip")
replaced:Reset(2770); tooltipCallback(replaced); flushTimers()
assert(not contains(replaced, "|Hitem:39151:"), "stale chat material appended to another item")
local closed = render(765, "ItemRefTooltip"); closed.shown = false
local lineCount = #closed.lines; flushTimers()
assert(not closed.shown and #closed.lines == lineCount)

-- Existing visibility controls still govern the material rows.
PA_SavedSettings.MillingKey = true
assert(not contains(render(765), "|Hitem:39151:"))
shiftDown = true
assert(materialRow(render(765), 39151).right == "coins:123456")
shiftDown = false; PA_SavedSettings.MillingKey = false
PA_SavedSettings.MillingChatChecked = false
local disabledChat = render(765, "ItemRefTooltip"); flushTimers()
assert(not contains(disabledChat, "|Hitem:39151:"))
PA_SavedSettings.MasterChecked = false
assert(#render(765).lines == 1)
''')
print("PASS: Retail startup, settings, material prices, dependency fallback, scan refresh, and chat tooltips")
