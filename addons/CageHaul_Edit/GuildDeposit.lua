local _, addon = ...
local Message = addon.Message
local CAGE_ITEM_ID = 82800
-- Matches the private slot count in Retail's Blizzard_GuildBankUI.
local GUILD_BANK_SLOTS_PER_TAB = 98
local TRANSFER_TIMEOUT = 8
local bankRun
local MoveNext
local loadedTab

local function GetOpenTab()
    if GuildBankFrame and GuildBankFrame:IsVisible() and GuildBankFrame.mode == "bank" then
        local tab = GetCurrentGuildBankTab()
        if tab and tab > 0 and tab <= GetNumGuildBankTabs() then
            return tab
        end
    end
end

local function ContextBlocker(tab)
    if InCombatLockdown() then
        return "Leave combat before moving cages."
    elseif GetOpenTab() ~= tab then
        return "The selected guild bank tab changed or closed."
    end
end

local function Finish(run, reason)
    bankRun = nil
    addon.RefreshPanel()
    local result = run.retrieving and "Retrieved %d %s from %s." or "Deposited %d %s into %s."
    Message(reason .. " " .. result:format(run.count, run.count == 1 and "cage" or "cages", run.tabName))
end

local function ScanBagCages(details)
    local firstBag, firstSlot
    local count = 0
    local unlocked = 0
    local cages = details and {}
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local isCage, species, level, quality
            if info then isCage, species, level, quality = addon.GetCageLinkInfo(info.hyperlink) end
            if info and (info.itemID == CAGE_ITEM_ID or isCage) then
                local stack = info.stackCount or 1
                count = count + stack
                if not info.isLocked then
                    unlocked = unlocked + stack
                    if not firstBag then firstBag, firstSlot = bag, slot end
                end
                if details then
                    if not species or not level or not quality then
                        local _, tooltipSpecies, tooltipLevel, tooltipQuality = addon.GetCageTooltipInfo(C_TooltipInfo.GetBagItem(bag, slot))
                        species, level, quality = species or tooltipSpecies, level or tooltipLevel, quality or tooltipQuality
                    end
                    cages[#cages + 1] = { species = species, level = level, quality = quality, count = stack }
                end
            end
        end
    end
    return firstBag, firstSlot, count, cages, unlocked
end

local function IsEmptySlot(tab, slot)
    local texture, count, locked = GetGuildBankItemInfo(tab, slot)
    return not texture and (not count or count == 0) and not locked and not GetGuildBankItemLink(tab, slot)
end

local function FindEmptySlot(tab)
    for slot = 1, GUILD_BANK_SLOTS_PER_TAB do
        if IsEmptySlot(tab, slot) then
            return slot
        end
    end
end

local function BankCages(tab, details)
    local cages = {}
    for slot = 1, GUILD_BANK_SLOTS_PER_TAB do
        local texture, count, locked = GetGuildBankItemInfo(tab, slot)
        if texture and count and count > 0 then
            local link = GetGuildBankItemLink(tab, slot)
            local isCage, species, level, quality = addon.GetCageLinkInfo(link)
            if not link or (details and isCage and (not species or not level or not quality)) then
                local data = C_TooltipInfo.GetGuildBankItem(tab, slot)
                if details then
                    local tooltipCage, tooltipSpecies, tooltipLevel, tooltipQuality = addon.GetCageTooltipInfo(data)
                    isCage = isCage or tooltipCage
                    species, level, quality = species or tooltipSpecies, level or tooltipLevel, quality or tooltipQuality
                else
                    isCage = data and data.type == Enum.TooltipDataType.BattlePet
                end
            end
            if isCage then
                cages[#cages + 1] = { slot = slot, species = species, level = level, quality = quality,
                    count = count, locked = locked }
            end
        end
    end
    return cages
end

local function FillPlan(tab, profile, collection, selection)
    local _, _, count, bagCages = ScanBagCages(true)
    local candidates = BankCages(tab, true)
    if selection then
        local matches = {}
        for _, cage in ipairs(candidates) do
            local original = selection[cage.slot]
            if original and original.species == cage.species and original.level == cage.level
                and original.quality == cage.quality then
                matches[#matches + 1] = cage
            end
        end
        candidates = matches
    end
    local plan, summary = addon.PlanFillCollection(candidates, bagCages, profile, collection)
    return plan, summary, count
end

function addon.PreviewBank(profile)
    local tab = GetOpenTab()
    if not tab then
        Message("Open a guild bank tab for the Deposit and Retrieve preview.")
        return
    end
    if loadedTab ~= tab then
        Message("Wait for the selected guild bank tab to load, then try /cagehaul status again.")
        return
    end
    local name, _, canView, canDeposit, _, remaining = GetGuildBankTabInfo(tab)
    if not canView then return end
    local _, _, bagCount, _, unlocked = ScanBagCages()
    local empty = 0
    for slot = 1, GUILD_BANK_SLOTS_PER_TAB do
        if IsEmptySlot(tab, slot) then empty = empty + 1 end
    end
    Message(("%s: Deposit can move %d of %d bag cages into %d empty slots.")
        :format(name, canDeposit and math.min(unlocked, empty) or 0, bagCount, empty))

    local eligible = 0
    if profile.preset == "fill" then
        if not C_PetJournal.IsJournalUnlocked() then
            Message("The Pet Journal must be ready for the Fill Collection preview.")
            return
        end
        local collection = addon.GetCollectionRanks()
        local plan, summary = FillPlan(tab, profile, collection)
        eligible = #plan
        Message(("Retrieve: %d missing species, %d upgrades, %d extra copies.")
            :format(summary.missing, summary.upgrades, summary.extras))
        Message(("Left in the tab: %d species covered by bag cages, %d above level %d, %d at cap, %d unidentified, %d locked.")
            :format(summary.inBags, summary.highLevel, collection.highest,
                summary.capped, summary.unidentified, summary.locked))
    else
        for _, cage in ipairs(BankCages(tab)) do
            if not cage.locked then eligible = eligible + 1 end
        end
    end
    local quota = remaining and (remaining < 0 and eligible or remaining) or 0
    Message(("Retrieve can move %d of %d eligible cages now."):format(math.min(eligible, addon.FreeBagSlots(), quota), eligible))
end

local function VerifyTransfer(run, Confirmed, deadline)
    if bankRun ~= run then
        return
    end
    local blocker = ContextBlocker(run.tab)
    if blocker then
        Finish(run, blocker)
        return
    end

    if Confirmed() then
        run.count = run.count + 1
        C_Timer.After(0.35, function() MoveNext(run) end)
    elseif GetTime() < deadline then
        C_Timer.After(0.15, function() VerifyTransfer(run, Confirmed, deadline) end)
    else
        Finish(run, "WoW did not confirm the last transfer. Check the selected tab before restarting.")
    end
end

local function DepositCage(run)
    local bag, source, count = ScanBagCages()
    if not bag then
        Finish(run, count > 0 and "Remaining cages are locked by WoW. Try again when they're ready."
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
    VerifyTransfer(run, function()
        local texture, count, locked = GetGuildBankItemInfo(run.tab, target)
        return texture and count and count > 0 and not locked and not C_Container.GetContainerItemInfo(bag, source)
    end, GetTime() + TRANSFER_TIMEOUT)
end

local function RetrieveCage(run)
    if addon.FreeBagSlots() == 0 then
        Finish(run, "Your normal bags are full.")
        return
    end
    local source, before, lockedCage
    local filtered = run.profile.preset == "fill"
    if filtered then
        if not C_PetJournal.IsJournalUnlocked() then
            Finish(run, "The Pet Journal must be ready to retrieve with Fill Collection.")
            return
        end
        run.collection = run.collection or addon.GetCollectionRanks()
        local plan, _, count = FillPlan(run.tab, run.profile, run.collection, run.selection)
        if not run.selection then
            -- Restrict the batch to the planned cages even if newly withdrawn bag metadata is still loading.
            run.selection = {}
            for _, cage in ipairs(plan) do run.selection[cage.slot] = cage end
        end
        source, before = plan[1] and plan[1].slot, count
    else
        for _, cage in ipairs(BankCages(run.tab)) do
            if not cage.locked then
                source = cage.slot
                break
            end
            lockedCage = true
        end
        local _, _, count = ScanBagCages()
        before = count
    end
    if not source then
        Finish(run, filtered and "No cages match Fill Collection in the selected tab."
            or lockedCage and "Remaining cages are locked by WoW. Try again when they're ready."
            or "No caged pets left in the selected tab.")
        return
    end
    if not pcall(AutoStoreGuildBankItem, run.tab, source) then
        Finish(run, "WoW blocked the cage withdrawal.")
        return
    end
    VerifyTransfer(run, function()
        if not IsEmptySlot(run.tab, source) then return false end
        local _, _, current = ScanBagCages()
        if current <= before then return false end
        if run.selection then run.selection[source] = nil end
        return true
    end, GetTime() + TRANSFER_TIMEOUT)
end

MoveNext = function(run)
    if bankRun ~= run then return end
    local blocker = ContextBlocker(run.tab)
    if blocker or GetCursorInfo() then
        Finish(run, blocker or "Clear what you're holding on the cursor before moving cages.")
        return
    end
    local _, _, canView, canDeposit, _, remaining = GetGuildBankTabInfo(run.tab)
    if not canView then
        Finish(run, "You need permission to view this guild bank tab.")
    elseif run.retrieving then
        if not remaining or remaining == 0 then
            Finish(run, "No withdrawals available from this guild bank tab.")
        else
            RetrieveCage(run)
        end
    elseif not canDeposit then
        Finish(run, "You need permission to deposit into this guild bank tab.")
    else
        DepositCage(run)
    end
end

function addon.BankTransferMode()
    if bankRun then
        return bankRun.retrieving and "retrieve" or "deposit"
    end
end

function addon.StartBankTransfer(retrieving)
    if bankRun then
        Message("A guild bank transfer is already running. Use /cagehaul stop to stop.")
        return
    elseif not addon.CanStartBankTransfer() then
        Message("Wait for the current cage request or batch to finish before moving cages.")
        return
    end
    local tab = GetOpenTab()
    if not tab then
        Message("Open the guild bank and select a tab, then run the command again.")
        return
    end
    local blocker = ContextBlocker(tab)
    if blocker or GetCursorInfo() then
        Message(blocker or "Clear what you're holding on the cursor before moving cages.")
        return
    end
    local tabName, _, canView, canDeposit = GetGuildBankTabInfo(tab)
    if not canView or (not retrieving and not canDeposit) then
        Message(retrieving and "You need permission to view this guild bank tab."
            or "You need permission to view and deposit into this guild bank tab.")
        return
    end

    local run = { tab = tab, tabName = tabName, count = 0, loading = true, retrieving = retrieving,
        profile = addon.Profile() }
    bankRun = run
    addon.RefreshPanel()
    local action = retrieving and "Retrieving caged pets from " or "Depositing caged pets into "
    Message(action .. tabName .. ". Use /cagehaul stop to stop.")
    QueryGuildBankTab(tab)
    C_Timer.After(TRANSFER_TIMEOUT, function()
        if bankRun == run and run.loading then
            Finish(run, "WoW did not send the guild bank tab contents. Reopen the tab and try again.")
        end
    end)
end

function addon.StopBankTransfer()
    if not bankRun then return false end
    Finish(bankRun, "Stopped. Any transfer already sent may still finish.")
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
events:RegisterEvent("GUILDBANKFRAME_CLOSED")
events:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
events:SetScript("OnEvent", function(_, event)
    local run = bankRun
    if event == "GUILDBANKFRAME_CLOSED" then
        loadedTab = nil
        if run then Finish(run, "Guild bank closed.") end
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        loadedTab = GetOpenTab()
        if run and run.loading and loadedTab == run.tab then
            run.loading = false
            C_Timer.After(0, function() MoveNext(run) end)
        end
    elseif run then
        run.collection = nil
    end
end)
