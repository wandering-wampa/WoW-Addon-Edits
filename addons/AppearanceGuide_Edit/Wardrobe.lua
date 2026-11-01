local _, ns = ...
local hooked = setmetatable({}, {__mode="k"})

local function AddGuideMenu(owner, root)
    local wardrobe = WardrobeCollectionFrame and WardrobeCollectionFrame.ItemsCollectionFrame
    if not wardrobe or not owner.GetCollectionFrame or owner:GetCollectionFrame() ~= wardrobe then return end
    local appearance = owner:GetAppearanceInfo()
    local location = wardrobe:GetTransmogLocation()
    if not appearance or appearance.isHideVisual or not location or location:IsIllusion() then return end
    local sources = ns.ResolveSources(appearance.visualID)
    root:CreateDivider()
    if #sources == 0 then
        local entry = root:CreateButton("Appearance data loading - try again")
        entry:SetEnabled(false)
        return
    end
    local menu = root
    if #sources > 1 then menu = root:CreateButton("How to obtain") end
    for _, source in ipairs(sources) do
        local itemID = source.itemID
        local guide = ns.guides[itemID]
        local name = C_Item.GetItemNameByID(itemID) or (guide and guide.name) or ("Item " .. itemID)
        local label = #sources == 1 and "How to obtain" or (name .. (guide and " - Quest guide" or " - No guide yet"))
        menu:CreateButton(label, function() ns.OpenItem(itemID) end)
    end
end
ns.AddGuideMenu = AddGuideMenu

local function HookModels()
    local wardrobe = WardrobeCollectionFrame and WardrobeCollectionFrame.ItemsCollectionFrame
    if not wardrobe then return end
    for _, model in ipairs(wardrobe.Models or {}) do
        if not hooked[model] then
            hooked[model] = true
            model:HookScript("OnMouseUp", function(self, button)
                local info = self:GetAppearanceInfo()
                local location = wardrobe:GetTransmogLocation()
                if button ~= "RightButton" or not info or info.isCollected or info.isHideVisual
                    or not location or location:IsIllusion() or IsModifiedClick() then return end
                -- Blizzard only supplies a context menu for collected models.
                -- Build our own for uncollected ones without replacing scripts.
                MenuUtil.CreateContextMenu(self, function(owner, root)
                    root:CreateTitle("Appearance Guide")
                    AddGuideMenu(owner, root)
                end)
            end)
            model:HookScript("OnEnter", function(self)
                local info = self:GetAppearanceInfo()
                local location = wardrobe:GetTransmogLocation()
                if info and not info.isHideVisual and location and not location:IsIllusion() and GameTooltip:IsShown() then
                    GameTooltip:AddLine("Right-click: How to obtain", .4, .8, 1)
                    GameTooltip:Show()
                end
            end)
        end
    end
end

function ns.InstallWardrobe()
    if ns.wardrobeInstalled then return end
    local wardrobe = WardrobeCollectionFrame and WardrobeCollectionFrame.ItemsCollectionFrame
    if not wardrobe or not Menu or not Menu.ModifyMenu or not MenuUtil then return end
    ns.wardrobeInstalled = true
    Menu.ModifyMenu("MENU_WARDROBE_ITEMS_MODEL_FILTER", AddGuideMenu)
    wardrobe:HookScript("OnShow", HookModels)
    if wardrobe.UpdateItems then hooksecurefunc(wardrobe, "UpdateItems", HookModels) end
    HookModels()
end
ns.InstallWardrobe()
