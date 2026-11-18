local _, addon = ...
local Message = addon.Message
local CAGE_ITEM_ID = 82800
local LEARN_TIMEOUT = 3
local skipped = {}
local pending

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
                    if not skipped[key] and not IsSpeciesFull(species) then
                        return bag, slot, key
                    end
                end
            end
        end
    end
end

local function LearnRequestSettled()
    if not pending then return true end
    local info = C_Container.GetContainerItemInfo(pending.bag, pending.slot)
    if info and CageKey(pending.bag, pending.slot, info) == pending.key then
        if GetTime() < pending.deadline then return false end
        skipped[pending.key] = true
        Message("WoW didn't learn that cage. Skipping it for this pass.")
    end
    pending = nil
    return true
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
    if not LearnRequestSettled() then return end

    local bag, slot, key = FindLearnableCage()
    if not bag then
        Message("No eligible cages left. /cagehaul learn resets skipped cages.")
        return
    end
    pending = { bag = bag, slot = slot, key = key, deadline = GetTime() + LEARN_TIMEOUT }
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
    wipe(skipped)
    Message("Close the bank, then use Learn in /cagehaul or put /click CageHaulLearnButton in a macro. One pet per press.")
end
