"""Exercise Cage Haul's live slash command, binding, events, and timers in Lua 5.1."""
from pathlib import Path
from xml.etree import ElementTree

from lupa.lua51 import LuaRuntime


ADDON = Path(__file__).resolve().parents[1] / "addons" / "CageHaul_Edit"
SOURCES = [
    (ADDON / line).read_text(encoding="utf-8")
    for line in (ADDON / "CageHaul_Edit.toc").read_text(encoding="utf-8").splitlines()
    if line.endswith(".lua")
]
BINDING = ElementTree.parse(ADDON / "Bindings.xml").find("Binding").text
MOCK = r'''
local now, timers, messages, owned, events = 0, {}, {}, {}, {}
calls, freeSlots, SlashCmdList = {}, 40, {}
petData, speciesLimits = {}, {}
Enum = { BagIndex = { Backpack = 0, Bag_4 = 4 } }
C_Container = { GetContainerNumFreeSlots = function(bag)
    assert(bag >= 0 and bag <= 4, "Only normal bags should be scanned")
    if bag == 0 then return freeSlots, 0 end
    return 30, 32 -- Specialty space does not hold cages.
end }
function InCombatLockdown() return combat or false end
function wipe(table) for key in pairs(table) do table[key] = nil end end
C_PetBattles = { IsInBattle = function() return false end }
function print(text) messages[#messages + 1] = text end
function said(fragment)
    for _, text in ipairs(messages) do
        if text:find(fragment, 1, true) then return true end
    end
end
function CreateFrame(kind)
    assert(kind == "Frame")
    local frame = {
        RegisterEvent = function(self, event)
            events[event] = events[event] or {}
            table.insert(events[event], self)
        end,
        SetScript = function(self, script, handler)
            assert(script == "OnEvent")
            self.onEvent = handler
        end,
    }
    return frame
end
function fire(event, id)
    for _, frame in ipairs(events[event] or {}) do frame:onEvent(event, id) end
end
local function schedule(delay, callback)
    local timer = { at = now + delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
C_Timer = { After = schedule, NewTimer = schedule }
function GetTime() return now end
function advance(seconds)
    local untilTime = now + seconds
    while true do
        local nextTimer
        for i, timer in ipairs(timers) do
            if not timer.cancelled and timer.at <= untilTime
                and (not nextTimer or timer.at < timers[nextTimer].at) then
                nextTimer = i
            end
        end
        if not nextTimer then break end
        local timer = table.remove(timers, nextTimer)
        now = timer.at
        timer.callback()
    end
    now = untilTime
end
function populate(count)
    for i = 1, count do owned[i] = true end
end
function cage(id, event)
    assert(owned[id] and freeSlots > 0, "Fixture attempted an invalid cage")
    owned[id], freeSlots = nil, freeSlots - 1
    if event then fire(event, id) end
end
local function no() return false end
C_PetJournal = {
    IsJournalUnlocked = function() return true end,
    GetOwnedPetIDs = function()
        local list = {}
        for id in pairs(owned) do list[#list + 1] = id end
        table.sort(list)
        return list
    end,
    GetPetInfoTableByPetID = function(id)
        if owned[id] then return petData[id] or { name = "Pet " .. id } end
    end,
    GetPetStats = function(id) return nil, nil, nil, nil, petData[id] and petData[id].rarity end,
    GetNumCollectedInfo = function(species)
        local count = 0
        for id in pairs(owned) do
            if petData[id] and petData[id].speciesID == species then count = count + 1 end
        end
        return count, speciesLimits[species] or 3
    end,
    PetIsTradable = function(id) return owned[id] end,
    PetIsRevoked = no, PetIsLockedForConvert = no, PetIsSlotted = no,
    PetIsHurt = no, PetNeedsFanfare = no,
    CagePetByID = function(id)
        assert(owned[id] and freeSlots > 0, "Addon sent an invalid cage request")
        calls[#calls + 1] = id
        if onCage then onCage(id) end
    end,
}
function slash(command) SlashCmdList.CAGEHAUL(command) end
'''


BANK_MOCK = r'''
local cursor, source
tab, bankVisible, allowed, bankMoves = 1, true, true, {}
bags, tabs = {}, { {}, {} }
withdrawalLimit, withdrawals = -1, {}
Enum.TooltipDataType = { Item = 0, BattlePet = 6 }
-- The live Guild Bank keeps its 98-slot limit local to Blizzard's addon.
assert(MAX_GUILDBANK_SLOTS_PER_TAB == nil)
GuildBankFrame = { mode = "bank", IsVisible = function() return bankVisible end,
    IsShown = function() return bankVisible end }
function GetCurrentGuildBankTab() return tab end
function GetNumGuildBankTabs() return #tabs end
function GetGuildBankTabInfo(id) return "Tab " .. id, 1, true, allowed, withdrawalLimit, withdrawalLimit end
function QueryGuildBankTab(id) assert(id == tab) end
function GetGuildBankItemInfo(id, slot)
    assert(slot >= 1 and slot <= 98, "Only valid guild bank slots should be scanned")
    local item = tabs[id][slot]
    if item then return 123, 1, item.isLocked end
end
function GetGuildBankItemLink(id, slot)
    local item = tabs[id][slot]
    if item and item.hyperlink then return item.hyperlink end
end
C_TooltipInfo = {
    GetGuildBankItem = function(id, slot) return tabs[id][slot] and tabs[id][slot].tooltip end,
    GetBagItem = function(_, slot) return bags[slot] and bags[slot].tooltip end,
}
TooltipUtil = { SurfaceArgs = function(data)
    data.battlePetSpeciesID, data.battlePetLevel, data.battlePetBreedQuality = data.species, data.level, data.quality
end }
function GetCursorInfo() return cursor and "item" end
function ClearCursor() cursor, source = nil, nil end
function C_Container.GetContainerNumSlots(bag) return bag == 0 and 5 or 0 end
function C_Container.GetContainerItemInfo(bag, slot)
    assert(bag == 0)
    return bags[slot]
end
function C_Container.PickupContainerItem(bag, slot)
    assert(bag == 0 and not cursor)
    cursor, source = bags[slot], slot
end
function PickupGuildBankItem(id, slot)
    assert(id == tab and not tabs[id][slot] and cursor)
    if rejectMove then return end
    local item, from = cursor, source
    cursor, source = nil, nil
    table.insert(bankMoves, { id, slot })
    if not silentMove then
        C_Timer.After(0.5, function()
            tabs[id][slot], bags[from] = item, nil
            fire("GUILDBANKBAGSLOTS_CHANGED")
        end)
    end
end
function AutoStoreGuildBankItem(id, slot)
    assert(id == tab and freeSlots > 0 and withdrawalLimit ~= 0)
    local item = assert(tabs[id][slot])
    assert(not item.isLocked)
    table.insert(withdrawals, { id, slot })
    C_Timer.After(0.5, function()
        for bagSlot = 1, 5 do
            if not bags[bagSlot] then
                bags[bagSlot], tabs[id][slot] = item, nil
                freeSlots = freeSlots - 1
                if withdrawalLimit > 0 then withdrawalLimit = withdrawalLimit - 1 end
                return
            end
        end
        error("No bag space in the mock")
    end)
end
'''

UI_MOCK = r'''
UIParent = {}
Minimap = {
    scripts = {},
    GetWidth = function(self) return self.width or 198 end,
    GetHeight = function() return 198 end,
    GetFrameLevel = function() return 10 end,
    GetCenter = function() return 100, 100 end,
    GetEffectiveScale = function() return 2 end,
    HookScript = function(self, event, handler)
        assert(event == "OnSizeChanged")
        self.scripts[event] = handler
    end,
}
function GetCursorPosition() return 200, 400 end
GameTooltip = { Hide = function() end, GetOwner = function() end }
local createEventFrame = CreateFrame
local function noOp() end
local function script(self, event, handler) self.scripts[event] = handler end
function CreateFrame(kind, name, parent, template)
    if kind == "Frame" and not parent then return createEventFrame(kind) end
    local frame = { scripts = {}, template = template, SetScript = script, SetPoint = noOp }
    if name then _G[name] = frame end
    if kind == "Frame" and template == "ButtonFrameTemplate" then
        assert(parent == UIParent)
        frame.SetSize, frame.SetClampedToScreen, frame.SetFrameStrata = noOp, noOp, noOp
        frame.SetMovable, frame.EnableMouse = noOp, noOp
        frame.StartMoving, frame.StopMovingOrSizing = noOp, noOp
        function frame:SetShown(shown) self.shown = shown end
        function frame:IsShown() return self.shown end
        function frame:Hide() self.shown = false end
        frame.CloseButton = { scripts = {}, SetScript = script }
        frame.TitleContainer = { TitleText = { SetText = function(self, text) self.text = text end } }
        frame.children = {}
    elseif kind == "Frame" then
        assert(template == nil and parent == CageHaulPanel)
        frame.EnableMouse, frame.RegisterForDrag = noOp, noOp
    elseif kind == "DropdownButton" then
        assert(template == "WowStyle1DropdownTemplate" and parent == CageHaulPanel)
        frame.SetWidth = noOp
        function frame:OverrideText(label) self.label = label end
        function frame:SetupMenu(generator) self.generator = generator end
        function frame:OpenMenu()
            local radios = {}
            local menu = {}
            function menu:CreateRadio(label, selected, select, value)
                radios[#radios + 1] = { label = label, selected = selected, select = select, value = value }
            end
            self.generator(self, menu)
            return radios
        end
    elseif kind == "Button" and parent == Minimap then
        assert(template == nil and name == "CageHaulMinimapButton")
        frame.SetSize, frame.SetFrameLevel, frame.SetToplevel = noOp, noOp, noOp
        frame.SetHighlightTexture, frame.LockHighlight, frame.UnlockHighlight = noOp, noOp, noOp
        frame.ClearAllPoints = noOp
        function frame:SetShown(shown) self.shown = shown end
        function frame:RegisterForClicks(click) assert(click == "LeftButtonUp") end
        function frame:RegisterForDrag(button) assert(button == "LeftButton") end
        function frame:SetPoint(point, parent, anchor, x, y)
            assert(point == "CENTER" and parent == Minimap and anchor == "CENTER")
            self.x, self.y = x, y
        end
        function frame:CreateTexture(_, layer)
            assert(layer == "BACKGROUND" or layer == "ARTWORK" or layer == "OVERLAY")
            return { SetSize = noOp, SetPoint = noOp, SetTexture = noOp }
        end
    elseif kind == "Button" then
        assert(template == "UIPanelButtonTemplate" or template == "SecureActionButtonTemplate"
            or template == "UIPanelButtonTemplate,SecureActionButtonTemplate")
        function frame:SetText(label)
            assert(self.template:find("UIPanelButtonTemplate", 1, true))
            self.label = label
        end
        frame.SetSize = noOp
        if parent == CageHaulPanel then table.insert(parent.children, frame) end
        if template:find("SecureActionButtonTemplate", 1, true) then
            frame.attributes = {}
            function frame:RegisterForClicks(click) assert(click == "LeftButtonUp") end
            function frame:SetAttribute(key, value)
                assert(not InCombatLockdown())
                self.attributes[key] = value
            end
        end
    else
        error("Unsupported widget")
    end
    return frame
end
function ButtonFrameTemplate_HidePortrait(frame) assert(frame.template == "ButtonFrameTemplate") end
function ButtonFrameTemplate_HideAttic(frame)
    assert(frame.template == "ButtonFrameTemplate")
    frame.insetStartsBelowTitle = true
end
function ButtonFrameTemplate_HideButtonBar(frame) assert(frame.template == "ButtonFrameTemplate") end
function press(button)
    local handler = button.scripts
    if handler.PreClick then handler.PreClick(button) end
    if button.attributes and button.attributes.type == "item" then
        assert(not combat)
        local bag, slot = button.attributes.item:match("^(%d+) (%d+)$")
        assert(tonumber(bag) == 0)
        learnFromSlot(tonumber(slot))
    elseif handler.OnClick then
        handler.OnClick(button)
    end
    if handler.PostClick then handler.PostClick(button) end
end
'''

SETTINGS_MOCK = r'''
local category = { GetID = function() return 123 end }
local layout = { AddInitializer = function(_, header) assert(type(header) == "string") end }
settingsControls = {}
Settings = {}
function Settings.RegisterVerticalLayoutCategory(label)
    assert(label == "Cage Haul")
    return category, layout
end
function Settings.RegisterAddOnSetting(parent, variable, key, db, valueType, label, default)
    assert(parent == category and variable == "CAGEHAUL_" .. key and db == CageHaulSettings)
    assert(type(db[key]) == valueType and type(default) == valueType and #label > 0)
    local setting = {}
    function setting:SetValueChangedCallback(fn) self.callback = fn end
    function setting:SetValue(value)
        assert(type(value) == valueType)
        db[key] = value
        if self.callback then self.callback(self, value) end
    end
    settingsControls[key] = setting
    return setting
end
function Settings.CreateCheckbox(parent, setting, tooltip)
    assert(parent == category and #tooltip > 0)
    setting.widget = "checkbox"
end
function Settings.CreateDropdown(parent, setting, options, tooltip)
    assert(parent == category and #tooltip > 0)
    setting.widget, setting.options = "dropdown", options()
end
function Settings.CreateControlTextContainer()
    local data = {}
    return { Add = function(_, value, label) data[#data + 1] = { value, label } end,
        GetData = function() return data end }
end
function CreateSettingsListSectionHeaderInitializer(label) return label end
function Settings.RegisterAddOnCategory(parent) assert(parent == category); registeredSettings = true end
function Settings.OpenToCategory(id) assert(registeredSettings and id == 123); settingsOpened = true end
function Settings.SetValue(variable, value)
    local key = assert(variable:match("^CAGEHAUL_(.+)$"))
    settingsControls[key]:SetValue(value)
end
'''

LEARN_MOCK = r'''
Enum.PlayerInteractionType = { GuildBanker = 10, Merchant = 5 }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function(kind) return interaction == kind end }
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Item = { GetItemGUID = function(location)
    local item = C_Container.GetContainerItemInfo(location.bag, location.slot)
    return item and item.guid
end }
TooltipUtil = { SurfaceArgs = function(data) data.battlePetSpeciesID = data.species end }
function C_TooltipInfo.GetBagItem(_, slot) return bags[slot].tooltip end
function C_PetJournal.GetNumCollectedInfo(species) return species == 20 and 3 or 0, 3 end
local gcdEnds = 0
C_Spell = { GetSpellCooldown = function(spell)
    assert(spell == 61304)
    return { isActive = math.max(gcdEnds, externalGcdEnds or 0) > GetTime() }
end }
function C_Container.GetContainerItemCooldown(_, slot)
    return 0, bags[slot].cooldownEnds or 0, 1
end
function UnitCastingInfo(unit) assert(unit == "player"); return casting end
function UnitChannelInfo(unit) assert(unit == "player"); return channeling end
learnedSlots = {}
function learnFromSlot(slot)
    learnedSlots[#learnedSlots + 1] = slot
    if not bags[slot].reject and not C_Spell.GetSpellCooldown(61304).isActive
        and (bags[slot].cooldownEnds or 0) <= GetTime() then
        bags[slot] = nil
        gcdEnds = GetTime() + 1.5
    end
end
'''


def scenario(lua_code, bank=False, learn=False):
    lua = LuaRuntime()
    lua.execute(MOCK)
    if bank:
        lua.execute(BANK_MOCK)
    lua.execute(UI_MOCK)
    lua.execute(SETTINGS_MOCK)
    if learn:
        lua.execute(LEARN_MOCK)
    namespace = lua.table()
    for source in SOURCES:
        lua.execute(source, "CageHaul_Edit", namespace)
    lua.execute("function pressKey() " + BINDING + " end")
    lua.execute(lua_code)


scenario(r'''
    populate(45)
    local swallowed
    function onCage(id)
        if id == 26 and not swallowed then
            swallowed = true
            return
        end
        cage(id, "PET_JOURNAL_PET_DELETED")
    end
    slash("start")
    advance(45)
    assert(#calls == 41 and calls[26] == 26 and calls[27] == 26,
        "A dropped request after 25 cages should retry and fill the remaining bags")
    assert(freeSlots == 0 and said("Caged 40 this batch"))
''')

scenario(r'''
    populate(4)
    freeSlots = 3
    function onCage(id)
        if id == 1 then
            fire("PET_JOURNAL_LIST_UPDATE") -- An unrelated journal change.
            cage(id, "PET_JOURNAL_LIST_UPDATE")
        elseif id == 2 then
            cage(id) -- WoW delivers neither confirmation event.
        elseif id == 3 then
            fire("PET_JOURNAL_CAGE_FAILED")
        else
            cage(id, "PET_JOURNAL_PET_DELETED")
        end
    end
    pressKey()
    advance(0.4)
    assert(#calls == 2, "A list update should advance only if the cage target left the journal")
    advance(30)
    assert(table.concat(calls, ",") == "1,2,3,3,3,4" and freeSlots == 0)
    assert(said("Skipping Pet 3") and said("Caged 3 this batch"))
''')

scenario(r'''
    populate(3)
    pressKey()
    advance(8.1)
    slash("stop")
    advance(30)
    assert(#calls == 1, "Stopping during backoff should cancel further requests")
    slash("one")
    cage(1, "PET_JOURNAL_PET_DELETED")
    advance(30)
    assert(#calls == 2, "Single-pet mode should still send just one request")
''')

print("PASS: Cage Haul resumes after missing confirmations, retries failures, fills bags, and stops on request")

scenario(r'''
    local other = { itemID = 123 }
    local cage = { itemID = 82800 }
    local linkedCage = { itemID = 0, hyperlink = "|cff777777|Hbattlepet:1:2:3|h[Pet]|h|r" }
    for slot = 1, 96 do tabs[2][slot] = other end
    bags[1], bags[2], bags[3], bags[4] = other, cage, linkedCage, cage
    tab = 2
    slash("deposit")
    advance(0.2)
    assert(#bankMoves == 0, "Wait for the selected tab contents to load")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(0.4)
    assert(#bankMoves == 1, "Wait for the first cage to arrive before moving another")
    advance(2)
    assert(#bankMoves == 2 and #tabs[1] == 0 and tabs[2][2] == other)
    assert(tabs[2][97] == cage and tabs[2][98] == linkedCage)
    assert(bags[1] == other and bags[4] == cage and not bags[2] and not bags[3])
    assert(said("Deposited 2 cages into Tab 2"))
    tab = 1
    slash("deposit")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(2)
    assert(not bags[4] and bags[1] == other and said("No caged pets left"))
''', bank=True)

scenario(r'''
    local cage = { itemID = 82800 }
    bags[1], bags[2] = cage, cage
    allowed = false
    slash("deposit")
    assert(said("need permission") and #bankMoves == 0)
    allowed = true
    slash("deposit")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(0.6)
    tab = 2
    advance(2)
    assert(#bankMoves == 1 and not tabs[2][1] and bags[2] == cage)

    slash("deposit")
    fire("GUILDBANKFRAME_CLOSED")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(10)
    assert(#bankMoves == 1)

    rejectMove = true
    slash("deposit")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(0.2)
    assert(#bankMoves == 1 and not GetCursorInfo() and bags[2] == cage)
    assert(said("did not accept the cage"))

    rejectMove, silentMove = false, true
    slash("deposit")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(10)
    assert(#bankMoves == 2 and said("did not confirm the last transfer"))
''', bank=True)

print("PASS: guild deposits only move cages into empty slots on the selected tab and verify each transfer")

scenario(r'''
    local other = { itemID = 123, hyperlink = "|Hitem:123:0|h[Other]|h" }
    local cage = { itemID = 82800, hyperlink = "|Hitem:82800:0|h[Pet Cage]|h" }
    local linkedCage = { hyperlink = "|Hbattlepet:1:2:3|h[Pet]|h" }
    local tooltipCage = { itemID = 82800, tooltip = { type = Enum.TooltipDataType.BattlePet } }
    tabs[1][1], tabs[2][1] = cage, other
    tabs[2][96], tabs[2][97], tabs[2][98] = cage, linkedCage, tooltipCage
    tab, freeSlots, allowed = 2, 2, false -- View and withdraw without deposit rights.
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(0.4)
    assert(#withdrawals == 1 and withdrawals[1][2] == 96)
    advance(3)
    assert(#withdrawals == 2 and freeSlots == 0 and said("normal bags are full"))
    assert(said("Retrieved 2 cages from Tab 2") and tabs[1][1] == cage and tabs[2][1] == other)
    assert(bags[1] == cage and bags[2] == linkedCage and tabs[2][98] == tooltipCage)

    freeSlots = 2
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(3)
    assert(#withdrawals == 3 and bags[3] == tooltipCage and said("No caged pets left"))
''', bank=True)

scenario(r'''
    local cage = { itemID = 82800, hyperlink = "item:82800" }
    tabs[1][1], tabs[1][2] = cage, cage
    freeSlots, withdrawalLimit = 2, 1
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(3)
    assert(#withdrawals == 1 and said("No withdrawals available") and said("Retrieved 1 cage"))
    assert(tabs[1][2] == cage)
    withdrawalLimit = -1
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    slash("stop")
    advance(3)
    assert(#withdrawals == 1 and tabs[1][2] == cage)
''', bank=True)

print("PASS: guild withdrawals recognize cage formats and honor bag space, withdrawal limits, and manual stop")

scenario(r'''
    assert(not CageHaulPanel, "The panel should start closed")
    slash("")
    local panel = CageHaulPanel
    local cage, deposit, retrieve, learn = unpack(panel.children)
    assert(panel:IsShown() and #panel.children == 4)
    assert(panel.insetStartsBelowTitle, "Both button rows should sit inside the stock inset")
    assert(cage.label == "Cage Pets" and deposit.label == "Deposit"
        and retrieve.label == "Retrieve" and learn.label == "Learn")
    press(deposit)
    assert(deposit.label == "Stop Deposit")
    press(deposit)
    assert(deposit.label == "Deposit")
    press(retrieve)
    assert(retrieve.label == "Stop Retrieval")
    press(retrieve)
    assert(retrieve.label == "Retrieve")
    populate(2)
    press(cage)
    assert(cage.label == "Stop Caging" and #calls == 1)
    press(cage)
    assert(cage.label == "Cage Pets")
    fire("PET_JOURNAL_PET_DELETED", 1)
    press(panel.CloseButton)
    assert(not panel:IsShown())
    slash("panel")
    assert(panel:IsShown())
''', bank=True)

scenario(r'''
    bags[1] = { itemID = 123, guid = "ordinary" }
    bags[2] = { itemID = 82800, guid = "capped", tooltip = { type = Enum.TooltipDataType.BattlePet, species = 20 } }
    bags[3] = { hyperlink = "|Hbattlepet:21:1:0|h[Pet]|h", guid = "reject", reject = true }
    bags[4] = { itemID = 82800, guid = "learnable" }
    bags[5] = { itemID = 82800, guid = "macro" }
    slash("")
    local learn = CageHaulPanel.children[4]
    press(learn)
    assert(#learnedSlots == 0 and said("Close the bank"))
    bankVisible, combat = false, true
    press(learn)
    assert(#learnedSlots == 0)
    combat, interaction = false, Enum.PlayerInteractionType.Merchant
    press(learn)
    assert(#learnedSlots == 0)
    interaction = nil
    press(learn)
    press(learn)
    assert(#learnedSlots == 1 and learnedSlots[1] == 3)
    advance(3)
    press(learn)
    assert(#learnedSlots == 2 and learnedSlots[2] == 3 and bags[3])
    advance(3)
    press(learn)
    assert(#learnedSlots == 3 and learnedSlots[3] == 4 and not bags[4])
    assert(not learn.attributes.item and not learn.attributes.type)
    slash("panel")
    press(CageHaulLearnButton)
    assert(#learnedSlots == 3 and bags[5])
    advance(1.5)
    press(CageHaulLearnButton)
    assert(#learnedSlots == 4 and learnedSlots[4] == 5 and bags[1] and bags[2] and not bags[5])
''', bank=True, learn=True)

print("PASS: the Retail panel opens on command and its four buttons exercise the real addon callbacks")

scenario(r'''
    bankVisible = false
    externalGcdEnds = 2
    bags[1] = { itemID = 82800, guid = "first" }
    bags[2] = { itemID = 82800, guid = "second", cooldownEnds = 5 }
    bags[3] = { itemID = 82800, guid = "third" }
    slash("")
    local learn = CageHaulPanel.children[4]
    for i = 1, 10 do press(learn); advance(0.1) end
    assert(#learnedSlots == 0, "Clicks during an active GCD must not attempt to use a cage")
    advance(1.1)
    press(learn)
    assert(#learnedSlots == 1 and not bags[1])
    for i = 1, 25 do press(learn); advance(0.1) end
    assert(#learnedSlots == 1 and bags[2], "A cooling-down item should remain next in line")
    advance(0.5)
    press(learn)
    assert(#learnedSlots == 2 and not bags[2])
    for i = 1, 10 do press(learn); advance(0.1) end
    assert(#learnedSlots == 2 and bags[3])
    advance(0.6)
    press(learn)
    assert(#learnedSlots == 3 and not bags[3])
    assert(not said("Skipping it for this pass"))
''', bank=True, learn=True)

print("PASS: rapid Learn clicks wait for cooldowns and keep the next cage in the queue")

scenario(r'''
    CageHaulSettings = { minimapAngle = 180 }
    fire("PLAYER_LOGIN")
    local button = CageHaulMinimapButton
    assert(button and not CageHaulPanel)
    assert(math.abs(button.x + 102) < 0.001 and math.abs(button.y) < 0.001)
    Minimap.width = 220
    Minimap.scripts.OnSizeChanged()
    assert(math.abs(button.x + 113) < 0.001)
    press(button)
    assert(CageHaulPanel:IsShown())
    press(button)
    assert(not CageHaulPanel:IsShown())
    button.scripts.OnDragStart(button)
    button.scripts.OnUpdate(button)
    button.scripts.OnDragStop(button)
    assert(CageHaulSettings.minimapAngle == 90 and math.abs(button.y - 102) < 0.001)
    assert(not button.scripts.OnUpdate)
''')

print("PASS: minimap launcher initializes at login, toggles the panel, and saves scaled drag positioning")

scenario(r'''
    CageHaulSettings = { minimapAngle = 195, showMinimap = false }
    fire("PLAYER_LOGIN")
    assert(registeredSettings and not CageHaulMinimapButton.shown)
    assert(settingsControls.showMinimap.widget == "checkbox" and #settingsControls.preset.options == 3)
    assert(#settingsControls.keep.options == 4 and settingsControls.keep.options[1][1] == 0)
    settingsControls.showMinimap:SetValue(true)
    assert(CageHaulMinimapButton.shown and CageHaulSettings.minimapAngle == 195)
    press(CageHaulMinimapButton)
    settingsControls.preset:SetValue("fill")
    assert(CageHaulPanel.TitleContainer.TitleText.text == "Cage Haul")
    assert(CageHaulPanel.Preset.label == "Fill Collection")
    local menu = CageHaulPanel.Preset:OpenMenu()
    assert(#menu == 3 and menu[3].selected(menu[3].value))
    menu[2].select(menu[2].value)
    assert(CageHaulSettings.preset == "extras" and CageHaulPanel.Preset.label == "Cage Extras")
    settingsControls.showMinimap:SetValue(false)
    assert(not CageHaulMinimapButton.shown)
    slash("")
    assert(not CageHaulPanel:IsShown())
    slash("settings")
    assert(settingsOpened)
''')

scenario(r'''
    CageHaulSettings = { preset = "extras", keep = 1 }
    populate(5)
    petData[1] = { speciesID = 10, petLevel = 9, rarity = 4 }
    petData[2] = { speciesID = 10, petLevel = 9, rarity = 2 }
    petData[3] = { speciesID = 10, petLevel = 25, rarity = 3, isFavorite = true }
    petData[4] = { speciesID = 10, petLevel = 2, rarity = 2, customName = "Named" }
    petData[5] = { speciesID = 12, petLevel = 1, rarity = 1 }
    function onCage(id) cage(id, "PET_JOURNAL_PET_DELETED") end
    slash("status")
    assert(#calls == 0 and said("1 eligible") and said("2 protected"))
    slash("start")
    advance(2)
    assert(#calls == 1 and calls[1] == 2)
    CageHaulSettings.keep, CageHaulSettings.protectFavorites, CageHaulSettings.protectNamed = 0, false, false
    slash("start")
    advance(3)
    assert(table.concat(calls, ",") == "2,1,3,4,5", "A zero-copy target intentionally includes last copies")
''')

scenario(r'''
    local function pet(species, level, quality)
        return { itemID = 82800, hyperlink = ("battlepet:%d:%d:%d"):format(species, level, quality) }
    end
    CageHaulSettings = { preset = "fill" }
    populate(2)
    petData[1] = { speciesID = 200, petLevel = 20, rarity = 2 }
    petData[2] = { speciesID = 900, petLevel = 25, rarity = 1 }
    bags[1] = pet(400, 10, 1)
    tabs[1][1], tabs[1][2], tabs[1][3] = pet(100, 1, 1), pet(100, 4, 3), pet(200, 10, 3)
    tabs[1][4], tabs[1][5], tabs[1][6] = { itemID = 82800, hyperlink = "item:82800" }, pet(500, 26, 3), pet(400, 10, 1)
    tabs[1][98] = { itemID = 82800, hyperlink = "item:82800",
        tooltip = { type = Enum.TooltipDataType.BattlePet, species = 600, level = 1, quality = 1 } }
    fire("GUILDBANKBAGSLOTS_CHANGED")
    slash("status")
    assert(said("2 missing species, 0 upgrades, 0 extra copies"))
    assert(said("1 species covered by bag cages, 1 above level 25") and said("1 unidentified"))
    slash("start")
    assert(#calls == 0 and said("Select Cage Extras or Full Swap"))
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(4)
    assert(#withdrawals == 2 and withdrawals[1][2] == 2 and withdrawals[2][2] == 98)
    assert(tabs[1][1] and tabs[1][3] and tabs[1][4] and tabs[1][5] and tabs[1][6])
''', bank=True)

scenario(r'''
    local function pet(species, level, quality)
        return { itemID = 82800, hyperlink = ("battlepet:%d:%d:%d"):format(species, level, quality) }
    end
    CageHaulSettings = { preset = "fill", takeUpgrades = true, takeExtras = true }
    populate(1)
    petData[1] = { speciesID = 200, petLevel = 25, rarity = 2 }
    bags[1] = pet(200, 8, 1)
    tabs[1][1], tabs[1][2], tabs[1][3], tabs[1][4] = pet(200, 12, 3), pet(200, 22, 2), pet(99, 2, 0), pet(99, 1, 0)
    fire("GUILDBANKBAGSLOTS_CHANGED")
    slash("status")
    assert(said("1 missing species, 1 upgrades, 1 extra copies"))
    slash("retrieve")
    fire("GUILDBANKBAGSLOTS_CHANGED")
    advance(5)
    assert(#withdrawals == 3 and withdrawals[1][2] == 3 and withdrawals[2][2] == 1 and withdrawals[3][2] == 4)
    assert(tabs[1][2], "Existing pets and bag cages must count against the species cap")
''', bank=True)

print("PASS: native settings, saved minimap toggle, Cage Extras protections, and Fill Collection priority and limits")

scenario(r'''
    populate(2)
    petData[1] = { speciesID = 10, petLevel = 1, rarity = 2 }
    petData[2] = { speciesID = 10, petLevel = 2, rarity = 2 }
    slash("")
    local panel = CageHaulPanel
    local menu = panel.Preset:OpenMenu()
    menu[2].select(menu[2].value)
    press(panel.Cage)
    assert(#calls == 1 and calls[1] == 1)
    menu[1].select(menu[1].value)
    assert(panel.Preset.label == "Full Swap")
    cage(1, "PET_JOURNAL_PET_DELETED")
    advance(0.5)
    assert(#calls == 1, "A preset selection must not change the current batch")
    press(panel.Cage)
    assert(#calls == 2 and calls[2] == 2, "The next batch should use the new preset")
''')

print("PASS: the panel dropdown and AddOns settings share a preset and changes apply to the next batch")
