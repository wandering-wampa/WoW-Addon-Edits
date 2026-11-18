local _, addon = ...
local Message = addon.Message
local CAGE_ITEM_ID = 82800
local GLOBAL_COOLDOWN_SPELL = 61304
local LEARN_INTERVAL = 1.5
local LEARN_TIMEOUT = 3
local MAX_ATTEMPTS = 2
local unanswered = {}
local pending
local nextLearnAt = 0

local interactionTypes = {
    "Banker", "GuildBanker", "AccountBanker", "Merchant", "Vendor",
    "Auctioneer", "MailInfo", "TradePartner", "VoidStorageBanker",
}
local interactionFrames = {
    "BankFrame", "GuildBankFrame", "MerchantFrame", "AuctionHouseFrame",
    "MailFrame", "TradeFrame", "VoidStorageFrame",
}

local function IsItemWindowOpen()
    for _, name in ipairs(interactionTypes) do
        local kind = Enum.PlayerInteractionType[name]
        if kind and C_PlayerInteractionManager.IsInteractingWithNpcOfType(kind) then return true end
    end
    for _, name in ipairs(interactionFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then return true end
    end
    return false
end

local function CageKey(bag, slot, info)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return C_Item.GetItemGUID(location) or (bag .. ":" .. slot .. ":" .. (info.hyperlink or info.itemID))
end

local function IsSpeciesFull(species)
    if not species then return false end
    local owned, limit = C_PetJournal.GetNumCollectedInfo(species)
    return owned and limit and limit > 0 and owned >= limit
end

local function FindLearnableCage()
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.isLocked then
                local cage, species = addon.GetCageLinkInfo(info.hyperlink)
                if cage or info.itemID == CAGE_ITEM_ID then
                    if not species then
                        local data = C_TooltipInfo.GetBagItem(bag, slot)
                        if data and data.type == Enum.TooltipDataType.BattlePet then
                            TooltipUtil.SurfaceArgs(data)
                            species = tonumber(data.battlePetSpeciesID)
                        end
                    end
                    local key = CageKey(bag, slot, info)
                    if (unanswered[key] or 0) < MAX_ATTEMPTS and not IsSpeciesFull(species) then
                        return bag, slot, key
                    end
                end
            end
        end
    end
end

local function LearnRequestSettled(now)
    if not pending then return true end
    local info = C_Container.GetContainerItemInfo(pending.bag, pending.slot)
    if info and CageKey(pending.bag, pending.slot, info) == pending.key then
        if now < pending.deadline then return false end
        local count = (unanswered[pending.key] or 0) + 1
        unanswered[pending.key] = count
        if count >= MAX_ATTEMPTS then
            Message("WoW didn't learn that cage after two attempts. Skipping it for this pass.")
        end
    else
        unanswered[pending.key] = nil
    end
    pending = nil
    return true
end

local function GlobalCooldownActive(now)
    if now < nextLearnAt or UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
    local gcd = C_Spell.GetSpellCooldown(GLOBAL_COOLDOWN_SPELL)
    return gcd and gcd.isActive
end

local function ItemCooldownActive(bag, slot, now)
    local start, duration = C_Container.GetContainerItemCooldown(bag, slot)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return true end
    return duration > 0 and start + duration > now
end

-- The player supplies a click. Set the secure item action for that click only.
local function PrepareClick(self)
    if InCombatLockdown() then return end
    self:SetAttribute("type", nil)
    self:SetAttribute("item", nil)
    if IsItemWindowOpen() or GetCursorInfo() then
        Message("Close the bank, merchant, mail, auction or trade window and clear your cursor before learning cages.")
        return
    end
    if addon.BankTransferMode() or not addon.CanStartBankTransfer() then
        Message("Wait for the current Cage Haul batch to finish before learning cages.")
        return
    end
    if C_PetBattles.IsInBattle() or not C_PetJournal.IsJournalUnlocked() then
        Message("The Pet Journal must be writable and out of battle to learn cages.")
        return
    end
    local now = GetTime()
    if GlobalCooldownActive(now) or not LearnRequestSettled(now) then return end

    local bag, slot, key = FindLearnableCage()
    if not bag then
        Message("No eligible cages left. /cagehaul learn resets skipped cages.")
        return
    end
    if ItemCooldownActive(bag, slot, now) then return end

    pending = { bag = bag, slot = slot, key = key, deadline = now + LEARN_TIMEOUT }
    -- The server's GCD can take a frame to appear after a click.
    nextLearnAt = now + LEARN_INTERVAL
    self:SetAttribute("item", bag .. " " .. slot)
    self:SetAttribute("type", "item")
end

local function ClearClick(self)
    if not InCombatLockdown() then
        self:SetAttribute("type", nil)
        self:SetAttribute("item", nil)
    end
end

function addon.CreateLearnButton(parent, name, template)
    local button = CreateFrame("Button", name, parent, template)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetScript("PreClick", PrepareClick)
    button:SetScript("PostClick", ClearClick)
    return button
end

addon.CreateLearnButton(UIParent, "CageHaulLearnButton", "SecureActionButtonTemplate")

function addon.ShowLearnMacro()
    wipe(unanswered)
    Message("Close the bank, then use Learn in /cagehaul or put /click CageHaulLearnButton in a macro. One pet per press.")
end
