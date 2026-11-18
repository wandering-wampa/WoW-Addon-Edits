local _, addon = ...
local Message = addon.Message
local CAGE_ITEM_ID = 82800
local TRANSFER_TIMEOUT = 8
local deposit
local DepositNext

local function GetOpenTab()
    if GuildBankFrame and GuildBankFrame:IsVisible() and GuildBankFrame.mode == "bank" then
        local tab = GetCurrentGuildBankTab()
        if tab and tab > 0 and tab <= GetNumGuildBankTabs() then
            return tab
        end
    end
end

local function DepositBlocker(tab)
    if InCombatLockdown() then
        return "Leave combat before depositing cages."
    elseif GetOpenTab() ~= tab then
        return "The selected guild bank tab changed or closed."
    end
    local _, _, canView, canDeposit = GetGuildBankTabInfo(tab)
    if not canView or not canDeposit then
        return "You need permission to view and deposit into this guild bank tab."
    end
end

local function Finish(run, reason)
    deposit = nil
    Message(("%s Deposited %d %s into %s."):format(reason, run.count,
        run.count == 1 and "cage" or "cages", run.tabName))
end

local function FindCage()
    local lockedCage
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and (info.itemID == CAGE_ITEM_ID
                or (info.hyperlink and info.hyperlink:find("|Hbattlepet:", 1, true))) then
                if not info.isLocked then
                    return bag, slot
                end
                lockedCage = true
            end
        end
    end
    return nil, nil, lockedCage
end

local function IsEmptySlot(tab, slot)
    local texture, count, locked = GetGuildBankItemInfo(tab, slot)
    return not texture and (not count or count == 0) and not locked and not GetGuildBankItemLink(tab, slot)
end

local function FindEmptySlot(tab)
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
        if IsEmptySlot(tab, slot) then
            return slot
        end
    end
end

local function VerifyTransfer(run, bag, source, target, deadline)
    if deposit ~= run then
        return
    end
    local blocker = DepositBlocker(run.tab)
    if blocker then
        Finish(run, blocker)
        return
    end

    local texture, count, locked = GetGuildBankItemInfo(run.tab, target)
    if texture and count and count > 0 and not locked and not C_Container.GetContainerItemInfo(bag, source) then
        run.count = run.count + 1
        C_Timer.After(0.35, function() DepositNext(run) end)
    elseif GetTime() < deadline then
        C_Timer.After(0.15, function() VerifyTransfer(run, bag, source, target, deadline) end)
    else
        Finish(run, "WoW did not confirm the last transfer. Check the selected tab before restarting.")
    end
end

DepositNext = function(run)
    if deposit ~= run then
        return
    end
    local blocker = DepositBlocker(run.tab)
    if blocker or GetCursorInfo() then
        Finish(run, blocker or "Clear what you're holding on the cursor before depositing.")
        return
    end
    local bag, source, lockedCage = FindCage()
    if not bag then
        Finish(run, lockedCage and "Remaining cages are locked by WoW. Try again when they're ready."
            or "No caged pets left in your bags.")
        return
    end
    local target = FindEmptySlot(run.tab)
    if not target then
        Finish(run, "The selected guild bank tab has no empty slots.")
        return
    end

    local pickedUp = pcall(C_Container.PickupContainerItem, bag, source)
    local cursor = GetCursorInfo()
    if not pickedUp or (cursor ~= "item" and cursor ~= "battlepet") or not IsEmptySlot(run.tab, target) then
        if cursor then ClearCursor() end
        Finish(run, "Couldn't pick up the cage or reserve an empty slot. Try again when the tab is ready.")
        return
    end
    local placed = pcall(PickupGuildBankItem, run.tab, target)
    if not placed or GetCursorInfo() then
        if GetCursorInfo() then ClearCursor() end
        Finish(run, "WoW did not accept the cage in this tab.")
        return
    end
    VerifyTransfer(run, bag, source, target, GetTime() + TRANSFER_TIMEOUT)
end

function addon.IsDepositing()
    return deposit ~= nil
end

function addon.StartDeposit()
    if deposit then
        Message("A guild bank deposit is already running. Use /cagehaul stop to stop.")
        return
    elseif not addon.CanStartDeposit() then
        Message("Wait for the current cage request or batch to finish before depositing.")
        return
    end
    local tab = GetOpenTab()
    if not tab then
        Message("Open the guild bank and select the destination tab, then use /cagehaul deposit.")
        return
    end
    local blocker = DepositBlocker(tab)
    if blocker or GetCursorInfo() then
        Message(blocker or "Clear what you're holding on the cursor before depositing.")
        return
    end

    local run = { tab = tab, tabName = GetGuildBankTabInfo(tab), count = 0, loading = true }
    deposit = run
    Message(("Depositing caged pets into %s. Use /cagehaul stop to stop."):format(run.tabName))
    QueryGuildBankTab(tab)
    C_Timer.After(TRANSFER_TIMEOUT, function()
        if deposit == run and run.loading then
            Finish(run, "WoW did not send the guild bank tab contents. Reopen the tab and try again.")
        end
    end)
end

function addon.StopDeposit()
    if not deposit then return false end
    Finish(deposit, "Stopped. Any transfer already sent may still finish.")
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
events:RegisterEvent("GUILDBANKFRAME_CLOSED")
events:SetScript("OnEvent", function(_, event)
    local run = deposit
    if not run then return end
    if event == "GUILDBANKFRAME_CLOSED" then
        Finish(run, "Guild bank closed.")
    elseif run.loading then
        run.loading = false
        C_Timer.After(0, function() DepositNext(run) end)
    end
end)
