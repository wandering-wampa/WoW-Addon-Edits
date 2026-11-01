local _, ns = ...
local gold, white, muted = {1, .82, 0}, {.92, .89, .83}, {.65, .65, .65}
local colors = {Complete={.35, .85, .4}, Passed=muted, Next=gold,
    ["In progress"]={.4, .8, 1}, ["Ready to turn in"]=gold, Later=muted}

local function Button(parent, label, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end

local function CreateWindow()
    local f = CreateFrame("Frame", "AppearanceGuideEditWindow", UIParent, "PortraitFrameTemplate,BackdropTemplate")
    ns.window = f
    f:Hide()
    f:SetSize(490, 640)
    f:SetScale(math.min(1, (UIParent:GetHeight() - 40) / 640, (UIParent:GetWidth() - 40) / 490))
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.TitleContainer.TitleText:SetText("Appearance Guide")
    f.TitleContainer.TitleText:SetTextColor(unpack(gold))
    f:SetBackdrop({bgFile="Interface\\FrameGeneral\\UI-Background-Rock", tile=true, tileSize=256,
        insets={left=4, right=4, top=24, bottom=4}})
    f:SetBackdropColor(.65, .65, .65, 1)
    local opaque = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    opaque:SetPoint("TOPLEFT", 4, -24)
    opaque:SetPoint("BOTTOMRIGHT", -4, 4)
    opaque:SetColorTexture(.08, .075, .065, 1)
    f.CloseButton:SetScript("OnClick", function() f:Hide() end)
    tinsert(UISpecialFrames, "AppearanceGuideEditWindow")

    f.itemName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.itemName:SetPoint("TOPLEFT", 70, -42)
    f.itemName:SetPoint("TOPRIGHT", -22, -42)
    f.itemName:SetJustifyH("LEFT")
    f.itemName:SetHeight(42)
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", 24, -92)
    f.status:SetPoint("TOPRIGHT", -24, -92)
    f.status:SetJustifyH("LEFT")
    f.status:SetHeight(30)

    f.inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    f.inset:SetPoint("TOPLEFT", 18, -130)
    f.inset:SetPoint("BOTTOMRIGHT", -18, 54)
    f.scroll = CreateFrame("ScrollFrame", nil, f.inset, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -12)
    f.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(412, 1)
    f.scroll:SetScrollChild(f.content)
    f.texts, f.rows = {}, {}

    f.mapButton = Button(f, "Show on map", 140, function()
        if f.selectedStep then ns.Navigate(f.selectedStep) end
    end)
    f.mapButton:SetPoint("BOTTOMLEFT", 24, 17)
    f.nextButton = Button(f, "Next step", 110, function()
        f.followNext = true
        ns.Refresh()
        f.scroll:SetVerticalScroll(0)
    end)
    f.nextButton:SetPoint("LEFT", f.mapButton, "RIGHT", 10, 0)
    local close = Button(f, "Close", 100, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -24, 17)

    f.reference = CreateFrame("EditBox", nil, f.content, "InputBoxTemplate")
    f.reference:SetAutoFocus(false)
    f.reference:SetSize(390, 22)
    f.reference:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.reference:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.reference:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    return f
end

function ns.Refresh()
    local f = ns.window
    if not f then return end
    local itemID, guide = f.itemID, ns.guides[f.itemID]
    local itemName = C_Item.GetItemNameByID(itemID)
    f.itemName:SetText(itemName or (guide and guide.name) or ("Item " .. itemID))
    local portrait = f.PortraitContainer and f.PortraitContainer.portrait
    if portrait then portrait:SetTexture(C_Item.GetItemIconByID(itemID) or 134400) end
    for _, text in ipairs(f.texts) do text:Hide() end
    for _, row in ipairs(f.rows) do row:Hide() end
    f.reference:Hide()
    local y, textIndex = 0, 0
    local function Text(value, color, font)
        textIndex = textIndex + 1
        local t = f.texts[textIndex]
        if not t then
            t = f.content:CreateFontString(nil, "OVERLAY")
            f.texts[textIndex] = t
        end
        t:SetFontObject(font or "GameFontHighlight")
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -y)
        t:SetWidth(406)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(true)
        t:SetTextColor(unpack(color or white))
        t:SetText(value)
        t:Show()
        y = y + t:GetStringHeight() + 10
    end

    f.selectedStep = nil
    if not guide then
        f.status:SetText("No quest guide available for this item yet.")
        Text("Guide not available", gold, "GameFontNormalLarge")
        Text("This first version covers Tyr's Guard Bulwark. Other appearances can be opened here, but their prerequisite chains have not been added yet.")
        Text("Item reference (click and press Ctrl+C)", muted, "GameFontHighlightSmall")
        f.reference:SetText("https://www.wowhead.com/item=" .. itemID)
    else
        local progress = ns.Progress(guide)
        local collected = ns.IsCollected(itemID)
        if collected then
            f.status:SetText("Appearance collected. Quest progress below is for this character.")
        elseif not progress.nextIndex then
            f.status:SetText("Reward quest complete. Use the shield item to learn its appearance.")
        else
            f.status:SetText("Quest reward - Dragonflight\nProgress checked on " .. UnitName("player"))
        end
        if f.followNext or not f.selectedIndex then
            f.selectedIndex = progress.nextIndex or #guide.steps
        end
        local step = guide.steps[f.selectedIndex]
        f.selectedStep = step
        Text(progress.states[f.selectedIndex] .. ": " .. ns.QuestName(step), gold, "GameFontNormalLarge")
        Text(step.chapter, muted, "GameFontHighlightSmall")
        Text(step.note or ("Continue with " .. step.npc .. ". Accept the quest and follow the objectives shown below or in your quest tracker."))
        local isActive = C_QuestLog.IsOnQuest(step.id)
        if isActive then
            local objectives = C_QuestLog.GetQuestObjectives(step.id) or {}
            for _, objective in ipairs(objectives) do
                if objective.text and objective.text ~= "" then
                    Text((objective.finished and "Done: " or "- ") .. objective.text,
                        objective.finished and colors.Complete or white, "GameFontHighlightSmall")
                end
            end
            if #objectives == 0 then Text("Open the quest log for the current objective.", muted) end
        end
        local map, x, z, pinType = ns.Waypoint(step)
        if map then
            local info = C_Map.GetMapInfo(map)
            Text(string.format("%s: %s (%.1f, %.1f)", pinType, info and info.name or "Map", x*100, z*100), muted, "GameFontHighlightSmall")
            if not isActive then Text("Speak to " .. step.npc .. ".", white, "GameFontHighlightSmall") end
        else
            Text("Use Show on map to track the active quest. Its objective pin may be inside an instance.", muted, "GameFontHighlightSmall")
        end
        if f.selectedIndex == 1 then Text(guide.unlockNote, muted, "GameFontHighlightSmall") end
        Text(guide.note, muted, "GameFontHighlightSmall")
        Text("Quest reference (click and press Ctrl+C)", muted, "GameFontHighlightSmall")
        f.reference:SetText("https://www.wowhead.com/quest=" .. step.id)
        f.reference:ClearAllPoints()
        f.reference:SetPoint("TOPLEFT", 6, -y)
        f.reference:Show()
        y = y + 36
        Text("Quest steps", gold, "GameFontNormalLarge")
        Text("Select a step to inspect it. Passed means later progress was detected; it is not a completion flag.", muted, "GameFontHighlightSmall")
        local chapter
        for i, entry in ipairs(guide.steps) do
            if chapter ~= entry.chapter then
                chapter = entry.chapter
                Text(chapter, gold, "GameFontNormal")
            end
            local row = f.rows[i]
            if not row then
                row = CreateFrame("Button", nil, f.content)
                row:SetWidth(406)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.label:SetPoint("TOPLEFT", 10, -6)
                row.label:SetWidth(386)
                row.label:SetJustifyH("LEFT")
                row.state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.state:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
                f.rows[i] = row
            end
            local index = i
            row:SetScript("OnClick", function()
                f.selectedIndex, f.followNext = index, false
                ns.Refresh()
                f.scroll:SetVerticalScroll(0)
            end)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row.label:SetText(ns.QuestName(entry))
            row.state:SetText(progress.states[i])
            row.state:SetTextColor(unpack(colors[progress.states[i]] or muted))
            row.bg:SetColorTexture(.65, .5, .2, i == f.selectedIndex and .22 or .04)
            local height = row.label:GetStringHeight() + 28
            row:SetHeight(height)
            row:Show()
            y = y + height + 4
        end
    end
    if not guide then
        f.reference:ClearAllPoints()
        f.reference:SetPoint("TOPLEFT", 6, -y)
        f.reference:Show()
        y = y + 36
    end
    f.mapButton:SetEnabled(f.selectedStep ~= nil)
    f.nextButton:SetEnabled(guide ~= nil)
    f.content:SetHeight(math.max(1, y + 4))
end

function ns.OpenItem(itemID)
    local f = ns.window or CreateWindow()
    f.itemID, f.selectedIndex, f.followNext = itemID, nil, true
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    local guide = ns.guides[itemID]
    if guide then
        for _, step in ipairs(guide.steps) do C_QuestLog.RequestLoadQuestByID(step.id) end
    end
    if not f:IsShown() then
        f:ClearAllPoints()
        if CollectionsJournal and CollectionsJournal:IsShown() then
            f:SetPoint("TOPLEFT", CollectionsJournal, "TOPRIGHT", 8, 0)
        else
            f:SetPoint("CENTER")
        end
    end
    f:Show()
    ns.Refresh()
    f.scroll:SetVerticalScroll(0)
end
