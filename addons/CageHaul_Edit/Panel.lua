local _, addon = ...
local panel

function addon.RefreshPanel()
    if not panel then return end
    local mode = addon.BankTransferMode()
    panel.Preset:OverrideText(addon.PresetNames[addon.GetSettings().preset])
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

local function CreatePresetDropdown()
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(142)
    dropdown:SetPoint("TOP", panel, "TOP", 0, -29)
    dropdown:SetupMenu(function(_, menu)
        local function IsSelected(preset) return addon.GetSettings().preset == preset end
        for _, preset in ipairs({ "full", "extras", "fill" }) do
            menu:CreateRadio(addon.PresetNames[preset], IsSelected, addon.SetPreset, preset)
        end
    end)
    return dropdown
end

local function CreatePanel()
    panel = CreateFrame("Frame", "CageHaulPanel", UIParent, "ButtonFrameTemplate")
    panel:Hide()
    panel:SetSize(252, 136)
    panel:SetPoint("CENTER", UIParent, "CENTER")
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    ButtonFrameTemplate_HidePortrait(panel)
    ButtonFrameTemplate_HideAttic(panel)
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

    panel.Preset = CreatePresetDropdown()
    panel.Cage = AddButton(CageHaul_ToggleBatch, 13, -61)
    panel.Deposit = AddButton(function() ToggleBankTransfer("deposit") end, 131, -61)
    panel.Retrieve = AddButton(function() ToggleBankTransfer("retrieve") end, 13, -93)
    local learn = addon.CreateLearnButton(panel, nil, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    PlaceButton(learn, 131, -93)
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
