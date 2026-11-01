local _, ns = ...

local shapes = {
    ROUND={true,true,true,true}, SQUARE={false,false,false,false},
    ["CORNER-TOPLEFT"]={false,false,false,true}, ["CORNER-TOPRIGHT"]={false,false,true,false},
    ["CORNER-BOTTOMLEFT"]={false,true,false,false}, ["CORNER-BOTTOMRIGHT"]={true,false,false,false},
    ["SIDE-LEFT"]={false,true,false,true}, ["SIDE-RIGHT"]={true,false,true,false},
    ["SIDE-TOP"]={false,false,true,true}, ["SIDE-BOTTOM"]={true,true,false,false},
    ["TRICORNER-TOPLEFT"]={false,true,true,true}, ["TRICORNER-TOPRIGHT"]={true,false,true,true},
    ["TRICORNER-BOTTOMLEFT"]={true,true,false,true}, ["TRICORNER-BOTTOMRIGHT"]={true,true,true,false},
}

function ns.PositionLauncher()
    local button = ns.minimapButton
    if not button then return end
    local angle = math.rad(ns.Settings().minimapAngle)
    local x, y = math.cos(angle), math.sin(angle)
    local q = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if not (shapes[shape] or shapes.ROUND)[q] then
        local factor = 1 / math.max(math.abs(x), math.abs(y))
        x, y = x * factor, y * factor
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth()/2 + 3), y * (Minimap:GetHeight()/2 + 3))
end

function ns.RefreshLauncher()
    local button = ns.minimapButton
    if not button then return end
    local id = ns.ActiveItemID()
    button.icon:SetTexture(C_Item.GetItemIconByID(id) or "Interface\\Icons\\INV_Chest_Cloth_17")
    if GameTooltip:GetOwner() == button then
        local guide = ns.guides[id]
        GameTooltip:SetText("Appearance Guide")
        GameTooltip:AddLine("Active: " .. (C_Item.GetItemNameByID(id) or (guide and guide.name) or ("Item " .. id)), 1, .82, 0, true)
        GameTooltip:AddLine("Left-click to open your active item.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", .65, .65, .65)
        GameTooltip:Show()
    end
end

function ns.CreateMinimapButton()
    if ns.minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "AppearanceGuideEditMinimapButton", Minimap)
    ns.minimapButton = button
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
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", 7, -5)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then ns.OpenActiveItem() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        ns.RefreshLauncher()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:LockHighlight()
        GameTooltip:Hide()
    end)
    local function StopDrag(self)
        self.dragging = false
        self:UnlockHighlight()
    end
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnHide", function(self)
        StopDrag(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    local sinceCheck = 0
    button:SetScript("OnUpdate", function(self, elapsed)
        if self.dragging then
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            -- Cursor pixels and map coordinates must use the same scale.
            ns.Settings().minimapAngle = math.deg(math.atan2(py/scale-my, px/scale-mx)) % 360
            ns.PositionLauncher()
        else
            sinceCheck = sinceCheck + elapsed
            if sinceCheck >= 1 then sinceCheck = 0; ns.PositionLauncher() end
        end
    end)
    Minimap:HookScript("OnSizeChanged", ns.PositionLauncher)
    button:HookScript("OnShow", ns.PositionLauncher)
    ns.RefreshLauncher()
    ns.PositionLauncher()
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(ns.ActiveItemID()) end
end
