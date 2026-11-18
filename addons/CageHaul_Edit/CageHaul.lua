local journal = C_PetJournal
local CAGE_DELAY = 0.35
local CAGE_TIMEOUT = 8
local rejected = {}
local activeBatch
local pending

local function Message(text)
    print("|cffefc75eCage Haul:|r " .. text)
end

local function FreeBagSlots()
    local total = 0
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        local slots, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 or bag == Enum.BagIndex.Backpack then
            total = total + slots
        end
    end
    return total
end

local function PetBlocker(id)
    if not journal.PetIsTradable(id) or journal.PetIsRevoked(id) or journal.PetIsLockedForConvert(id) then
        return "unavailable"
    elseif journal.PetIsSlotted(id) then
        return "slotted"
    elseif journal.PetIsHurt(id) then
        return "injured"
    elseif journal.PetNeedsFanfare(id) then
        return "wrapped"
    elseif rejected[id] then
        return "rejected"
    end
end

local function ScanJournal()
    local queue = {}
    local blocked = { unavailable = 0, slotted = 0, injured = 0, wrapped = 0, rejected = 0 }
    for _, id in ipairs(journal.GetOwnedPetIDs()) do
        local reason = PetBlocker(id)
        if reason then
            blocked[reason] = blocked[reason] + 1
        else
            queue[#queue + 1] = id
        end
    end
    return queue, blocked
end

local function ActionBlocker()
    if InCombatLockdown() or C_PetBattles.IsInBattle() then
        return "Leave combat or the pet battle before caging."
    elseif not journal.IsJournalUnlocked() then
        return "The Pet Journal is read-only or still loading. Try again when it is ready."
    end
end

local function Finish(reason)
    local batch = activeBatch
    activeBatch = nil
    Message(("%s Caged %d this batch."):format(reason, batch.caged))
end

local function FailRequest(reason)
    local request = pending
    pending = nil
    local message = ("%s (%s)"):format(reason, request.name)
    if activeBatch == request.batch then
        Finish(message)
    else
        Message(message)
    end
end

local function CageNext(batch)
    if activeBatch ~= batch or pending then
        return
    end

    local blocker = ActionBlocker()
    if blocker then
        Finish(blocker)
        return
    end

    while batch.index <= #batch.queue do
        local id = batch.queue[batch.index]
        batch.index = batch.index + 1
        local info = journal.GetPetInfoTableByPetID(id)
        if info and not PetBlocker(id) then
            -- Cap the batch at its starting space in case bag updates trail journal updates.
            if batch.caged >= batch.limit or FreeBagSlots() == 0 then
                Finish("Bag limit reached. Make room and start another batch.")
                return
            end

            local request = { id = id, name = info.name or "Battle pet", batch = batch }
            pending = request
            local ok = pcall(journal.CagePetByID, id)
            if not ok and pending == request then
                FailRequest("WoW blocked the cage request. Try /cagehaul one for a single pet.")
            elseif pending == request then
                C_Timer.After(CAGE_TIMEOUT, function()
                    if pending == request then
                        FailRequest("WoW did not confirm the cage. Check your bags before retrying.")
                    end
                end)
            end
            return
        end
    end

    Finish("Batch complete.")
end

local function Start(single)
    if activeBatch or pending then
        Message("A cage batch or request is already in progress.")
        return
    end
    local blocker = ActionBlocker()
    if blocker then
        Message(blocker)
        return
    end
    local slots = FreeBagSlots()
    if slots == 0 then
        Message("Make room in your normal bags before caging.")
        return
    end
    local queue = ScanJournal()
    if #queue == 0 then
        Message("No eligible pets. Use /cagehaul to see what's skipped.")
        return
    end

    activeBatch = { queue = queue, index = 1, caged = 0, limit = slots, single = single }
    if not single then
        Message(("Starting batch of up to %d. Use /cagehaul stop to stop."):format(math.min(#queue, slots)))
    end
    CageNext(activeBatch)
end

local function Stop()
    if not activeBatch then
        Message("No batch is running.")
        return
    end
    Finish(pending and "Stopped after sending the current request." or "Stopped.")
end

local function Preview()
    local queue, blocked = ScanJournal()
    Message(("%d eligible, %d free normal bag slots. Includes last copies, favorites and named pets.")
        :format(#queue, FreeBagSlots()))
    Message(("Skipped: %d unavailable, %d slotted, %d injured, %d to unwrap, %d rejected.")
        :format(blocked.unavailable, blocked.slotted, blocked.injured, blocked.wrapped, blocked.rejected))
    Message("/cagehaul start to fill your bags, /cagehaul stop to stop, or /cagehaul one for one pet.")
    if blocked.rejected > 0 then
        Message("/cagehaul retry clears the list of pets WoW rejected this session.")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PET_JOURNAL_PET_DELETED")
events:RegisterEvent("PET_JOURNAL_CAGE_FAILED")
events:SetScript("OnEvent", function(_, event, id)
    local request = pending
    if not request then
        return
    end
    if event == "PET_JOURNAL_CAGE_FAILED" then
        rejected[request.id] = true
        FailRequest("WoW rejected the cage. This pet is skipped until /cagehaul retry.")
    elseif id == request.id then
        pending = nil
        local batch = request.batch
        batch.caged = batch.caged + 1
        if activeBatch ~= batch or batch.single then
            Message("Caged " .. request.name .. ".")
            if activeBatch == batch then
                activeBatch = nil
            end
        else
            -- Advance only once the client's journal confirms the requested pet is gone.
            C_Timer.After(CAGE_DELAY, function() CageNext(batch) end)
        end
    end
end)

BINDING_HEADER_CAGEHAUL = "Cage Haul"
BINDING_NAME_CAGEHAUL_TOGGLE_BATCH = "Start or stop a pet cage batch"

function CageHaul_ToggleBatch()
    if activeBatch then
        Stop()
    else
        Start(false)
    end
end

SLASH_CAGEHAUL1 = "/cagehaul"
SlashCmdList.CAGEHAUL = function(message)
    local command = message:match("^%s*(%S*)"):lower()
    if command == "start" then
        Start(false)
    elseif command == "stop" then
        Stop()
    elseif command == "one" then
        Start(true)
    elseif command == "retry" then
        wipe(rejected)
        Message("Cleared rejected pets. Start another batch when ready.")
    else
        Preview()
    end
end
