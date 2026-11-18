"""Exercise Cage Haul's live slash command, binding, events, and timers in Lua 5.1."""
from pathlib import Path
from xml.etree import ElementTree

from lupa.lua51 import LuaRuntime


ADDON = Path(__file__).resolve().parents[1] / "addons" / "CageHaul_Edit"
SOURCE = (ADDON / "CageHaul.lua").read_text(encoding="utf-8")
BINDING = ElementTree.parse(ADDON / "Bindings.xml").find("Binding").text
MOCK = r'''
local now, timers, messages, owned, events = 0, {}, {}, {}, {}
local onEvent
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
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, script, handler)
            assert(script == "OnEvent")
            onEvent = handler
        end,
    }
end
function fire(event, id)
    if events[event] then onEvent(nil, event, id) end
end
local function schedule(delay, callback)
    local timer = { at = now + delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
C_Timer = { After = schedule, NewTimer = schedule }
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


def scenario(lua_code):
    lua = LuaRuntime()
    lua.execute(MOCK)
    lua.execute(SOURCE)
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
