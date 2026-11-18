local _, addon = ...
local START_ANGLE = 170

local function CreateLauncher()
    if not Minimap or CageHaulMinimapButton then return end
    local settings = addon.GetSettings()
    if type(settings.minimapAngle) ~= "number" or not (settings.minimapAngle >= 0 and settings.minimapAngle < 360) then
        settings.minimapAngle = START_ANGLE
    end

    local button = CreateFrame("Button", "CageHaulMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:SetToplevel(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(21, 21)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Pet_PetTrap01")
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local function Position()
        local angle = math.rad(settings.minimapAngle)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * (Minimap:GetWidth() / 2 + 3), math.sin(angle) * (Minimap:GetHeight() / 2 + 3))
    end

    button:SetScript("OnClick", addon.TogglePanel)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Cage Haul")
        GameTooltip:AddLine("Click to open or close the window.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            settings.minimapAngle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
            Position()
        end)
    end)
    local function StopDrag(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnHide", function(self)
        StopDrag(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    Minimap:HookScript("OnSizeChanged", Position)
    button:SetScript("OnShow", Position)
    Position()
    addon.RefreshMinimapVisibility()
end

function addon.RefreshMinimapVisibility()
    if CageHaulMinimapButton then
        CageHaulMinimapButton:SetShown(addon.GetSettings().showMinimap)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", CreateLauncher)
