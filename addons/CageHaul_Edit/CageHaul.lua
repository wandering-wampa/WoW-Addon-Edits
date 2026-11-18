local _, addon = ...
local journal = C_PetJournal
local CAGE_DELAY = 0.35
local CAGE_TIMEOUT = 8
local MAX_ATTEMPTS = 3
local rejected = {}
local activeBatch
local pending
local CageNext
local SendRequest

function addon.Message(text)
    print("|cffefc75eCage Haul:|r " .. text)
end
local Message = addon.Message

function addon.FreeBagSlots()
    local total = 0
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        local slots, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 or bag == Enum.BagIndex.Backpack then
            total = total + slots
        end
    end
    return total
end
local FreeBagSlots = addon.FreeBagSlots

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

local function FindKeepers(ids, profile)
    local speciesGroups, keepers = {}, {}
    for _, id in ipairs(ids) do
        local info = journal.GetPetInfoTableByPetID(id)
        if info and info.speciesID and not journal.PetIsRevoked(id) then
            local group = speciesGroups[info.speciesID] or {}
            speciesGroups[info.speciesID] = group
            local rank = profile.keep > 0 and addon.JournalRank(id, info)
            group[#group + 1] = { id = id, rank = rank or -1, level = info.petLevel or 0 }
            if addon.IsProtectedPet(info, profile) then
                keepers[id] = "protected"
            elseif profile.keep > 0 and not rank then
                keepers[id] = "unknown"
            end
        else
            keepers[id] = "unknown"
        end
    end
    for _, group in pairs(speciesGroups) do
        table.sort(group, function(a, b)
            if a.rank ~= b.rank then return a.rank > b.rank end
            if a.level ~= b.level then return a.level > b.level end
            return a.id < b.id
        end)
        for i = 1, math.min(profile.keep, #group) do
            local id = group[i].id
            keepers[id] = keepers[id] or "kept"
        end
    end
    return keepers
end

local function ScanJournal(profile)
    local queue = {}
    local blocked = { unavailable = 0, slotted = 0, injured = 0, wrapped = 0, rejected = 0,
        kept = 0, protected = 0, unknown = 0 }
    local ids = journal.GetOwnedPetIDs()
    local keepers = profile.preset == "extras" and FindKeepers(ids, profile) or {}
    for _, id in ipairs(ids) do
        local reason = PetBlocker(id) or keepers[id]
        if reason then
            blocked[reason] = blocked[reason] + 1
        else
            queue[#queue + 1] = id
        end
    end
    return queue, blocked
end

local function CanCage(id, info, profile)
    if not info or PetBlocker(id) then return false end
    if profile.preset ~= "extras" then return true end
    if not info.speciesID or addon.IsProtectedPet(info, profile) then return false end
    local owned = journal.GetNumCollectedInfo(info.speciesID)
    return owned and owned > profile.keep
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
    addon.RefreshPanel()
    Message(("%s Caged %d this batch."):format(reason, batch.caged))
end

local function ClearRequest(request)
    request.timer:Cancel()
    pending = nil
end

local function FailRequest(request, reason)
    ClearRequest(request)
    local message = ("%s (%s)"):format(reason, request.name)
    if activeBatch == request.batch then
        Finish(message)
    else
        Message(message)
    end
end

local function Continue(batch)
    C_Timer.After(batch.delay, function() CageNext(batch) end)
end

local function ConfirmCage(request)
    ClearRequest(request)
    local batch = request.batch
    batch.caged = batch.caged + 1
    if activeBatch == batch and not batch.single then
        Continue(batch)
    else
        Message("Caged " .. request.name .. ".")
        if activeBatch == batch then
            activeBatch = nil
            addon.RefreshPanel()
        end
    end
end

local function PetLeftJournal(id)
    if not journal.IsJournalUnlocked() then
        return false
    end
    for _, owned in ipairs(journal.GetOwnedPetIDs()) do
        if owned == id then
            return false
        end
    end
    return true
end

local function RecoverRequest(request)
    if PetLeftJournal(request.id) then
        ConfirmCage(request)
        return
    end
    local batch = request.batch
    if activeBatch ~= batch then
        ClearRequest(request)
        return
    end
    if FreeBagSlots() == 0 then
        ClearRequest(request)
        Finish("Bags are full. Make room and start another batch.")
        return
    end
    if batch.single then
        FailRequest(request, "WoW did not confirm the cage.")
        return
    end
    if request.attempts == MAX_ATTEMPTS then
        ClearRequest(request)
        rejected[request.id] = true
        Message(("Skipping %s after %d cage attempts. Use /cagehaul retry to try it again later.")
            :format(request.name, request.attempts))
        Continue(batch)
        return
    end

    -- Give WoW time to catch up and slow the rest of this batch after a stall.
    if batch.delay == CAGE_DELAY then
        Message("Waiting for WoW to respond. Slowing down and retrying automatically.")
    end
    batch.delay = math.min(1.5, batch.delay * 2)
    request.timer:Cancel()
    request.retrying = true
    request.timer = C_Timer.NewTimer(2 ^ request.attempts, function()
        if pending ~= request then
            return
        end
        if PetLeftJournal(request.id) then
            ConfirmCage(request)
        elseif activeBatch ~= batch then
            ClearRequest(request)
        elseif not CanCage(request.id, journal.GetPetInfoTableByPetID(request.id), batch.profile) then
            ClearRequest(request)
            Continue(batch)
        else
            SendRequest(request)
        end
    end)
end

SendRequest = function(request)
    local blocker = ActionBlocker()
    if blocker or FreeBagSlots() == 0 then
        pending = nil
        Finish(blocker or "Bags are full. Make room and start another batch.")
        return
    end

    request.attempts = request.attempts + 1
    request.retrying = false
    request.timer = C_Timer.NewTimer(CAGE_TIMEOUT, function()
        if pending == request then
            RecoverRequest(request)
        end
    end)
    local ok = pcall(journal.CagePetByID, request.id)
    if not ok and pending == request then
        FailRequest(request, "WoW blocked the cage request. Try /cagehaul one for a single pet.")
    end
end

CageNext = function(batch)
    if activeBatch ~= batch or pending then
        return
    end

    while batch.index <= #batch.queue do
        local id = batch.queue[batch.index]
        batch.index = batch.index + 1
        local info = journal.GetPetInfoTableByPetID(id)
        if CanCage(id, info, batch.profile) then
            local request = { id = id, name = info.name or "Battle pet", batch = batch, attempts = 0 }
            pending = request
            SendRequest(request)
            return
        end
    end

    Finish("Batch complete.")
end

function addon.CanStartBankTransfer()
    return not activeBatch and not pending
end

function addon.IsCaging()
    return activeBatch ~= nil
end

local function Start(single)
    if addon.BankTransferMode() then
        Message("Stop the guild bank transfer before caging more pets.")
        return
    end
    if activeBatch or pending then
        Message("A cage batch or request is already in progress.")
        return
    end
    local blocker = ActionBlocker()
    if blocker then
        Message(blocker)
        return
    end
    local profile = addon.Profile()
    if profile.preset == "fill" then
        Message("Fill Collection is for retrieving cages. Select Cage Extras or Full Swap to cage pets.")
        return
    end
    local slots = FreeBagSlots()
    if slots == 0 then
        Message("Make room in your normal bags before caging.")
        return
    end
    local queue = ScanJournal(profile)
    if #queue == 0 then
        Message("No eligible pets. Use /cagehaul status to see what's skipped.")
        return
    end

    activeBatch = { queue = queue, index = 1, caged = 0, delay = CAGE_DELAY, single = single, profile = profile }
    addon.RefreshPanel()
    if not single then
        Message(("%s: starting a batch of up to %d. Use /cagehaul stop to stop.")
            :format(addon.PresetNames[profile.preset], math.min(#queue, slots)))
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
    local profile = addon.Profile()
    Message(("%s. %d free normal bag slots."):format(addon.PresetNames[profile.preset], FreeBagSlots()))
    if profile.preset ~= "fill" then
        local queue, blocked = ScanJournal(profile)
        Message(("Cage Pets: %d eligible; up to %d fit. Kept %d strongest, %d protected, %d unidentified.")
            :format(#queue, math.min(#queue, FreeBagSlots()), blocked.kept, blocked.protected, blocked.unknown))
        Message(("Skipped: %d unavailable, %d slotted, %d injured, %d to unwrap, %d rejected.")
            :format(blocked.unavailable, blocked.slotted, blocked.injured, blocked.wrapped, blocked.rejected))
    else
        Message("Cage Pets is off in Fill Collection.")
    end
    addon.PreviewBank(profile)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PET_JOURNAL_PET_DELETED")
events:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
events:RegisterEvent("PET_JOURNAL_CAGE_FAILED")
events:SetScript("OnEvent", function(_, event, id)
    local request = pending
    if not request then
        return
    end
    if (event == "PET_JOURNAL_PET_DELETED" and id == request.id)
        or (event == "PET_JOURNAL_LIST_UPDATE" and PetLeftJournal(request.id)) then
        ConfirmCage(request)
    elseif event == "PET_JOURNAL_CAGE_FAILED" and not request.retrying then
        RecoverRequest(request)
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
    if command == "" or command == "panel" then
        addon.TogglePanel()
    elseif command == "settings" then
        addon.OpenSettings()
    elseif command == "start" then
        Start(false)
    elseif command == "stop" then
        if not addon.StopBankTransfer() then Stop() end
    elseif command == "deposit" or command == "retrieve" then
        addon.StartBankTransfer(command == "retrieve")
    elseif command == "learn" then
        addon.ShowLearnMacro()
    elseif command == "one" then
        Start(true)
    elseif command == "retry" then
        wipe(rejected)
        Message("Cleared rejected pets. Start another batch when ready.")
    else
        Preview()
    end
end
