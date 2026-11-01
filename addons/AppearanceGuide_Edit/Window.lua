local _, ns = ...
local gold, white, muted = {1, .82, 0}, {.92, .89, .83}, {.65, .65, .65}
local colors = {Complete={.35, .85, .4}, Passed=muted, Next=gold,
    ["In progress"]={.4, .8, 1}, ["Ready to turn in"]=gold, Later=muted, Available=gold, Unverified=muted}
local labels = {Complete="Completed", Passed="Earlier step (inferred)", Next="Next in chain",
    ["In progress"]="Current quest", ["Ready to turn in"]="Ready to turn in", Later="Not started",
    Available="Available (game reports)", Unverified="Availability not confirmed"}

local function Scroll(parent, top)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", 12, -top)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(412, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll.ScrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 10, -2)
    scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 10, 2)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, scroll.ScrollBar)
    return scroll, content
end

local function Button(parent, label, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end

local function ReadingInset(parent)
    local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    if inset.Bg then inset.Bg:Hide() end
    inset.readingBackground = inset:CreateTexture(nil, "BACKGROUND")
    inset.readingBackground:SetPoint("TOPLEFT", 3, -3)
    inset.readingBackground:SetPoint("BOTTOMRIGHT", -3, 3)
    inset.readingBackground:SetColorTexture(.075, .07, .06, 1)
    return inset
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
    f.itemName:SetHeight(28)
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", 24, -74)
    f.status:SetPoint("TOPRIGHT", -24, -74)
    f.status:SetJustifyH("LEFT")
    f.status:SetHeight(30)

    f.trackButton = Button(f, "Track this item", 150, function()
        ns.SetActiveItem(f.itemID)
    end)
    f.trackButton:SetPoint("TOPLEFT", 24, -108)
    f.activeButton = Button(f, "Open active item", 150, ns.OpenActiveItem)
    f.activeButton:SetPoint("LEFT", f.trackButton, "RIGHT", 10, 0)

    f.listInset = ReadingInset(f)
    f.listInset:ClearAllPoints()
    f.listInset:SetPoint("TOPLEFT", 18, -142)
    f.listInset:SetPoint("TOPRIGHT", -18, -142)
    f.listInset:SetHeight(200)
    local listTitle = f.listInset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 12, -12)
    listTitle:SetText("Quest progress")
    f.listTitle = listTitle
    f.listScroll, f.listContent = Scroll(f.listInset, 34)

    f.inset = ReadingInset(f)
    f.inset:ClearAllPoints()
    f.inset:SetPoint("TOPLEFT", 18, -352)
    f.inset:SetPoint("BOTTOMRIGHT", -18, 54)
    f.scroll, f.content = Scroll(f.inset, 12)
    f.texts, f.rows, f.chapters = {}, {}, {}

    f.mapButton = Button(f, "Show on map", 140, function()
        if f.selectedStep then ns.Navigate(f.selectedStep) end
    end)
    f.mapButton:SetPoint("BOTTOMLEFT", 24, 17)
    f.nextButton = Button(f, "Current quest", 110, function()
        f.followNext = true
        f.focusList = true
        f.showHelp = false
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
    f.helpButton = Button(f.content, "Help & reference", 140, function()
        f.showHelp = not f.showHelp
        ns.Refresh()
    end)
    f.prerequisiteButton = Button(f.content, "Prerequisites", 170, function()
        f.routeChoice = "manual"
        f.showPrerequisites = not f.showPrerequisites
        f.selectedIndex, f.selectedQuestID = nil, nil
        f.followNext, f.focusList, f.showHelp = true, true, false
        ns.Refresh()
        f.scroll:SetVerticalScroll(0)
    end)
    f.coordinateButton = Button(f.content, "", 406, function()
        ns.SetArrow(f.coordinateTarget)
    end)
    f.coordinateButton:SetNormalFontObject("GameFontNormalSmall")
    f.coordinateButton:SetHighlightFontObject("GameFontHighlightSmall")
    f.coordinateButton:GetFontString():SetWidth(382)
    f.coordinateButton:GetFontString():SetWordWrap(true)
    f.coordinateButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.HasTomTom() and "Set TomTom arrow" or "Show on map")
        GameTooltip:AddLine(ns.HasTomTom() and "Click to point the arrow at these coordinates." or "TomTom is not loaded. Click to use the built-in map.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.coordinateButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.coordinateButton:SetScript("OnHide", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    return f
end

local function RefreshList(f, guide, progress)
    local y, chapterIndex, chapter = 0, 0, nil
    if not guide then
        f.listContent:SetHeight(1)
        return
    end
    for i, entry in ipairs(guide.steps) do
        if chapter ~= entry.chapter then
            chapter, chapterIndex = entry.chapter, chapterIndex + 1
            local heading = f.chapters[chapterIndex]
            if not heading then
                heading = f.listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                f.chapters[chapterIndex] = heading
            end
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT", 6, -y)
            heading:SetWidth(394)
            heading:SetJustifyH("LEFT")
            heading:SetText(chapter)
            heading:Show()
            y = y + heading:GetStringHeight() + 10
        end
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Button", nil, f.listContent)
            row:SetWidth(406)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.hover = row:CreateTexture(nil, "HIGHLIGHT")
            row.hover:SetAllPoints()
            row.hover:SetColorTexture(.55, .43, .2, .14)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetPoint("TOPLEFT", 5, -6)
            row.icon:SetSize(18, 18)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("TOPLEFT", 30, -5)
            row.label:SetWidth(368)
            row.label:SetJustifyH("LEFT")
            row.state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.state:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
            f.rows[i] = row
        end
        local index = i
        row:SetScript("OnClick", function()
            f.selectedIndex, f.followNext, f.showHelp = index, index == f.currentIndex, false
            f.selectedQuestID = entry.id
            ns.Refresh()
            f.scroll:SetVerticalScroll(0)
        end)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row.offset = y
        local state = progress.states[i]
        row.label:SetText(ns.QuestName(entry))
        row.label:SetTextColor(unpack(state == "Complete" and colors.Complete or white))
        row.state:SetText(labels[state])
        row.state:SetTextColor(unpack(colors[state] or muted))
        row.icon:Hide()
        if state == "Complete" then
            row.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            row.icon:Show()
        elseif state == "Available" or state == "In progress" or state == "Ready to turn in" then
            row.icon:SetTexture(state == "Available" and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon")
            row.icon:Show()
        end
        row.bg:SetColorTexture(.65, .5, .2, i == f.selectedIndex and .18 or .025)
        local height = row.label:GetStringHeight() + 25
        row:SetHeight(height)
        row:Show()
        y = y + height + 2
    end
    f.listContent:SetHeight(y + 4)
    f.listScroll:UpdateScrollChildRect()
    if f.focusList or (f.followNext and f.lastNext ~= progress.nextIndex) then
        -- Keep the preceding two steps in view, so completed history stays visible.
        local start = math.max(1, (f.selectedIndex or 1) - 2)
        local offset = start == 1 and 0 or f.rows[start].offset
        f.listScroll:SetVerticalScroll(math.min(offset, math.max(0, y + 4 - f.listScroll:GetHeight())))
    end
    f.lastNext, f.focusList = progress.nextIndex, false
end

function ns.Refresh()
    local f = ns.window
    if not f then return end
    local itemID, guide = f.itemID, ns.guides[f.itemID]
    local isActiveItem = itemID == ns.ActiveItemID()
    f.trackButton:SetText(isActiveItem and "Active item" or "Track this item")
    f.trackButton:SetEnabled(not isActiveItem)
    f.activeButton:SetShown(not isActiveItem)
    ns.offerMaps = guide and guide.scanMaps or nil
    ns.offers = ns.ScanOffers(ns.offerMaps)
    if guide and f.routeChoice == "auto" and not f.showPrerequisites and ns.TargetBlocker(guide) then
        f.showPrerequisites, f.selectedIndex, f.selectedQuestID = true, nil, nil
        f.followNext, f.focusList = true, true
    end
    if guide and f.showPrerequisites then guide = ns.PrerequisiteGuide(guide) end
    local itemName = C_Item.GetItemNameByID(itemID)
    f.itemName:SetText(itemName or (guide and guide.name) or ("Item " .. itemID))
    local portrait = f.PortraitContainer and f.PortraitContainer.portrait
    if portrait then portrait:SetTexture(C_Item.GetItemIconByID(itemID) or 134400) end
    for _, text in ipairs(f.texts) do text:Hide() end
    for _, row in ipairs(f.rows) do row:Hide() end
    for _, chapter in ipairs(f.chapters) do chapter:Hide() end
    f.reference:Hide()
    f.helpButton:Hide()
    f.prerequisiteButton:Hide()
    f.coordinateButton:Hide()
    f.coordinateTarget = nil
    f.listInset:SetShown(guide ~= nil)
    f.inset:ClearAllPoints()
    f.inset:SetPoint("TOPLEFT", 18, guide and -352 or -142)
    f.inset:SetPoint("BOTTOMRIGHT", -18, 54)
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

    f.selectedStep, f.currentIndex = nil, nil
    if not guide then
        f.status:SetText("No quest guide available for this item yet.")
        Text("Guide not available", gold, "GameFontNormalLarge")
        Text("This first version covers Tyr's Guard Bulwark. Other appearances can be opened here, but their prerequisite chains have not been added yet.")
        Text("Item reference (click and press Ctrl+C)", muted, "GameFontHighlightSmall")
        f.reference:SetText("https://www.wowhead.com/item=" .. itemID)
        RefreshList(f)
    else
        f.listTitle:SetText(guide.independent and "Prerequisites and campaign steps" or "Quest progress")
        local progress = ns.Progress(guide)
        f.currentIndex = progress.nextIndex
        local collected = ns.IsCollected(itemID)
        local summary = string.format("%s: %d / %d quests completed", UnitName("player"), progress.completedCount, progress.total)
        if progress.passedCount > 0 then summary = summary .. " - " .. progress.passedCount .. " earlier steps passed" end
        if collected then
            f.status:SetText(summary .. "\nAppearance collected")
        elseif guide.independent then
            f.status:SetText(summary .. "\nCharacter quest flags - campaign requirements checked live")
        elseif not progress.nextIndex then
            f.status:SetText(summary .. "\nReward quest complete - use the shield to learn its appearance")
        elseif progress.completedCount == 0 and progress.passedCount == 0 and progress.states[1] == "Next" then
            f.status:SetText(summary .. "\nNo progress found in this chain on this character")
        else
            f.status:SetText(summary .. string.format("\nCurrent step: %d of %d - %s", progress.nextIndex, progress.total, labels[progress.states[progress.nextIndex]]))
        end
        if f.followNext or not f.selectedIndex then
            f.selectedIndex = progress.nextIndex or #guide.steps
        elseif f.selectedQuestID then
            -- Quest metadata may arrive asynchronously and insert earlier rows.
            -- Preserve the selected quest, not its former array position.
            for i, entry in ipairs(guide.steps) do
                if entry.id == f.selectedQuestID then f.selectedIndex = i; break end
            end
        end
        f.selectedIndex = math.min(f.selectedIndex, #guide.steps)
        local step = guide.steps[f.selectedIndex]
        f.selectedQuestID = step.id
        f.selectedStep = step
        RefreshList(f, guide, progress)
        Text(labels[progress.states[f.selectedIndex]] .. ": " .. ns.QuestName(step), gold, "GameFontNormal")
        Text(step.chapter, muted, "GameFontHighlightSmall")
        f.prerequisiteButton:ClearAllPoints()
        f.prerequisiteButton:SetPoint("TOPLEFT", 0, -y)
        f.prerequisiteButton:SetText(guide.independent and "Back to reward chain" or "Prerequisites")
        f.prerequisiteButton:Show()
        y = y + 34
        if guide.independent then
            for _, notice in ipairs(guide.notices) do Text(notice, muted, "GameFontHighlightSmall") end
        end
        local readiness = ns.Readiness(guide, step)
        if readiness then Text(readiness, muted, "GameFontHighlightSmall") end
        if progress.states[f.selectedIndex] == "Complete" then
            Text("Completed on this character.", colors.Complete)
        elseif progress.states[f.selectedIndex] == "Passed" then
            Text("A later quest is active or complete. This earlier step was passed or skipped; its own completion flag is not set.", muted)
        end
        Text(step.note or ("Continue with " .. step.npc .. ". Follow the quest objectives in your tracker."))
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
        if map and x and z then
            local info = C_Map.GetMapInfo(map)
            f.coordinateTarget = {step=step, map=map, x=x, y=z, kind=pinType}
            f.coordinateButton:ClearAllPoints()
            f.coordinateButton:SetPoint("TOPLEFT", 0, -y)
            f.coordinateButton:SetText(string.format("%s: %s (%.1f, %.1f)", pinType, info and info.name or "Map", x*100, z*100))
            local height = math.max(28, f.coordinateButton:GetFontString():GetStringHeight() + 12)
            f.coordinateButton:SetHeight(height)
            f.coordinateButton:Show()
            y = y + height + 10
            if not isActive then Text("Speak to " .. step.npc .. ".", white, "GameFontHighlightSmall") end
        elseif isActive then
            Text("Use Show on map to track the active quest. Its objective pin may be inside an instance.", muted, "GameFontHighlightSmall")
        else
            Text("No verified quest-start coordinates are available for this step. Show on map opens the known zone, if supplied; it does not invent a quest-giver location.", muted, "GameFontHighlightSmall")
        end
        f.helpButton:ClearAllPoints()
        f.helpButton:SetPoint("TOPLEFT", 0, -y)
        f.helpButton:SetText(f.showHelp and "Hide help" or "Help & reference")
        f.helpButton:Show()
        y = y + 36
        if f.showHelp then
            if f.selectedIndex == 1 then Text(guide.unlockNote, muted, "GameFontHighlightSmall") end
            Text(guide.note, muted, "GameFontHighlightSmall")
            Text("Quest reference (click and press Ctrl+C)", muted, "GameFontHighlightSmall")
            f.reference:SetText("https://www.wowhead.com/quest=" .. step.id)
            f.reference:ClearAllPoints()
            f.reference:SetPoint("TOPLEFT", 6, -y)
            f.reference:Show()
            y = y + 36
        end
    end
    if not guide then
        f.reference:ClearAllPoints()
        f.reference:SetPoint("TOPLEFT", 6, -y)
        f.reference:Show()
        y = y + 36
    end
    f.mapButton:SetEnabled(f.selectedStep ~= nil and (f.selectedStep.map ~= nil or C_QuestLog.IsOnQuest(f.selectedStep.id) or f.coordinateTarget ~= nil))
    f.nextButton:SetEnabled(f.currentIndex ~= nil and f.selectedIndex ~= f.currentIndex)
    f.content:SetHeight(math.max(1, y + 4))
    f.scroll:UpdateScrollChildRect()
    f.scroll:SetVerticalScroll(math.min(f.scroll:GetVerticalScroll(), f.scroll:GetVerticalScrollRange()))
end

function ns.OpenItem(itemID)
    local f = ns.window or CreateWindow()
    f.itemID, f.selectedIndex, f.followNext = itemID, nil, true
    f.selectedQuestID, f.showPrerequisites = nil, false
    f.routeChoice = "auto"
    f.focusList, f.showHelp = true, false
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    local guide = ns.guides[itemID]
    if guide then
        ns.RequestGuideData(guide)
        ns.offerMaps, ns.offers = guide.scanMaps, ns.ScanOffers(guide.scanMaps)
        f.showPrerequisites = ns.TargetBlocker(guide) ~= nil
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
