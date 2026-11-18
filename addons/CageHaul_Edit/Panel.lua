local _, addon = ...
local panel

function addon.RefreshPanel()
    if not panel then return end
    local mode = addon.BankTransferMode()
    panel.Cage:SetText(addon.IsCaging() and "Stop Caging" or "Cage Pets")
    panel.Deposit:SetText(mode == "deposit" and "Stop Deposit" or "Deposit")
    panel.Retrieve:SetText(mode == "retrieve" and "Stop Retrieval" or "Retrieve")
end

local function ToggleBankTransfer(mode)
    if addon.BankTransferMode() == mode then
        addon.StopBankTransfer()
    else
        addon.StartBankTransfer(mode == "retrieve")
    end
end

local function PlaceButton(button, x, y)
    button:SetSize(108, 24)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    return button
end

local function AddButton(callback, x, y)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetScript("OnClick", callback)
    return PlaceButton(button, x, y)
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CageHaulPanel", UIParent, "ButtonFrameTemplate")
    panel:Hide()
    panel:SetSize(252, 106)
    panel:SetPoint("CENTER", UIParent, "CENTER")
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    ButtonFrameTemplate_HidePortrait(panel)
    ButtonFrameTemplate_HideButtonBar(panel)
    panel.TitleContainer.TitleText:SetText("Cage Haul")
    panel.CloseButton:SetScript("OnClick", function() addon.TogglePanel() end)

    local titleDrag = CreateFrame("Frame", nil, panel)
    titleDrag:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -3)
    titleDrag:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -30, -22)
    titleDrag:EnableMouse(true)
    titleDrag:RegisterForDrag("LeftButton")
    titleDrag:SetScript("OnDragStart", function()
        if not InCombatLockdown() then panel:StartMoving() end
    end)
    titleDrag:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)

    panel.Cage = AddButton(CageHaul_ToggleBatch, 13, -31)
    panel.Deposit = AddButton(function() ToggleBankTransfer("deposit") end, 131, -31)
    panel.Retrieve = AddButton(function() ToggleBankTransfer("retrieve") end, 13, -63)
    local learn = addon.CreateLearnButton(panel, nil, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    PlaceButton(learn, 131, -63)
    learn:SetText("Learn")
    learn.tooltipText = "Learn the next eligible cage. One pet per click."
end

function addon.TogglePanel()
    if InCombatLockdown() then
        addon.Message("Leave combat to open or close Cage Haul.")
        return
    end
    if not panel then CreatePanel() end
    addon.RefreshPanel()
    panel:SetShown(not panel:IsShown())
end
