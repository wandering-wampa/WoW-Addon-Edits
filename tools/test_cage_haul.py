"""Exercise Cage Haul's live slash command, binding, events, and timers in Lua 5.1."""
from pathlib import Path
from xml.etree import ElementTree

from lupa.lua51 import LuaRuntime


ADDON = Path(__file__).resolve().parents[1] / "addons" / "CageHaul_Edit"
SOURCE = (ADDON / "CageHaul.lua").read_text(encoding="utf-8")
DEPOSIT = (ADDON / "GuildDeposit.lua").read_text(encoding="utf-8")
BINDING = ElementTree.parse(ADDON / "Bindings.xml").find("Binding").text
MOCK = r'''
local now, timers, messages, owned, events = 0, {}, {}, {}, {}
calls, freeSlots, SlashCmdList = {}, 40, {}
Enum = { BagIndex = { Backpack = 0, Bag_4 = 4 } }
C_Container = { GetContainerNumFreeSlots = function(bag)
    assert(bag >= 0 and bag <= 4, "Only normal bags should be scanned")
    if bag == 0 then return freeSlots, 0 end
    return 30, 32 -- Specialty space does not hold cages.
end }
function InCombatLockdown() return false end
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
        if owned[id] then return { name = "Pet " .. id } end
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
-- The live Guild Bank keeps its 98-slot limit local to Blizzard's addon.
assert(MAX_GUILDBANK_SLOTS_PER_TAB == nil)
GuildBankFrame = { mode = "bank", IsVisible = function() return bankVisible end }
function GetCurrentGuildBankTab() return tab end
function GetNumGuildBankTabs() return #tabs end
function GetGuildBankTabInfo(id) return "Tab " .. id, 1, true, allowed end
function QueryGuildBankTab(id) assert(id == tab) end
function GetGuildBankItemInfo(id, slot)
    assert(slot >= 1 and slot <= 98, "Only valid guild bank slots should be scanned")
    local item = tabs[id][slot]
    if item then return 123, 1, false end
end
function GetGuildBankItemLink(id, slot)
    local item = tabs[id][slot]
    if item and item.hyperlink then return item.hyperlink end
end
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
'''


def scenario(lua_code, bank=False):
    lua = LuaRuntime()
    lua.execute(MOCK)
    if bank:
        lua.execute(BANK_MOCK)
    namespace = lua.table()
    lua.execute(SOURCE, "CageHaul_Edit", namespace)
    lua.execute(DEPOSIT, "CageHaul_Edit", namespace)
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
