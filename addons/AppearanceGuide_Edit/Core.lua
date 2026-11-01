local _, ns = ...

local function ValidItemID(value)
    local id = tonumber(value)
    return id and id > 0 and id < 2147483647 and id == math.floor(id) and id or nil
end

function ns.Settings()
    if type(AppearanceGuideEditDB) ~= "table" then AppearanceGuideEditDB = {} end
    local db = AppearanceGuideEditDB
    local angle = tonumber(db.minimapAngle)
    db.minimapAngle = angle and angle == angle and math.abs(angle) < math.huge and angle % 360 or 135
    return db
end

function ns.CharacterSettings()
    local account = ns.Settings()
    if type(AppearanceGuideEditCharDB) ~= "table" then AppearanceGuideEditCharDB = {} end
    local character = AppearanceGuideEditCharDB
    -- Consume the old shared target once, on the first character to load this
    -- version. Never overwrite an existing character target or seed every alt
    -- from another character's choice.
    character.activeItemID = ValidItemID(character.activeItemID) or ValidItemID(account.activeItemID) or 208198
    account.activeItemID = nil
    return character
end

function ns.ActiveItemID()
    return ns.CharacterSettings().activeItemID
end

function ns.SetActiveItem(itemID)
    local id = ValidItemID(itemID)
    if not id then return false end
    ns.CharacterSettings().activeItemID = id
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    if ns.RefreshLauncher then ns.RefreshLauncher() end
    if ns.window and ns.window:IsShown() then ns.Refresh() end
    return true
end

function ns.OpenActiveItem()
    ns.OpenItem(ns.ActiveItemID())
end

function ns.QuestName(step)
    return C_QuestLog.GetTitleForQuestID(step.id) or step.name
end

-- Character flags only: an alt's completion must not skip this character's
-- prerequisites. A later active/completed quest proves earlier steps passed,
-- even when a campaign skip did not set every earlier completion flag.
function ns.Progress(guide)
    if guide.independent then return ns.PrerequisiteProgress(guide) end
    local frontier, completed, active = 0, {}, {}
    for i, step in ipairs(guide.steps) do
        completed[i] = C_QuestLog.IsQuestFlaggedCompleted(step.id)
        active[i] = C_QuestLog.IsOnQuest(step.id)
        if completed[i] then
            frontier = math.max(frontier, i)
        elseif active[i] then
            frontier = math.max(frontier, i - 1)
        end
    end
    local result = {states={}, nextIndex=frontier + 1, completedCount=0, passedCount=0, total=#guide.steps}
    for i, step in ipairs(guide.steps) do
        local status
        if completed[i] then
            status = "Complete"
            result.completedCount = result.completedCount + 1
        elseif active[i] then
            status = C_QuestLog.IsComplete(step.id) and "Ready to turn in" or "In progress"
        elseif i <= frontier then
            status = "Passed"
            result.passedCount = result.passedCount + 1
        elseif i == result.nextIndex then status = "Next"
        else status = "Later" end
        result.states[i] = status
    end
    if result.nextIndex > #guide.steps then result.nextIndex = nil end
    return result
end

function ns.IsCollected(itemID)
    local appearanceID = C_TransmogCollection.GetItemInfo(itemID)
    if not appearanceID then return false end
    for _, source in ipairs(C_TransmogCollection.GetAppearanceSources(appearanceID) or {}) do
        if source.isCollected then return true end
    end
    return false
end

function ns.ResolveSources(appearanceID)
    local result, seen = {}, {}
    for _, source in ipairs(C_TransmogCollection.GetAppearanceSources(appearanceID) or {}) do
        local itemID = source.itemID
        if not itemID and source.sourceID then
            local info = C_TransmogCollection.GetSourceInfo(source.sourceID)
            itemID = info and info.itemID
        end
        if itemID and not seen[itemID] then
            seen[itemID] = true
            result[#result + 1] = {itemID=itemID, sourceID=source.sourceID}
        end
    end
    table.sort(result, function(a, b)
        local ak, bk = ns.guides[a.itemID] ~= nil, ns.guides[b.itemID] ~= nil
        if ak ~= bk then return ak end
        return a.itemID < b.itemID
    end)
    return result
end

function ns.Waypoint(step)
    if C_QuestLog.IsOnQuest(step.id) and C_QuestLog.GetNextWaypoint then
        local map, x, y = C_QuestLog.GetNextWaypoint(step.id)
        if map and x and y and (x > 0 or y > 0) then
            return map, x, y, "Quest objective"
        end
        -- Do not send an active player back to an outdated quest-giver pin.
        return nil
    end
    if step.live then
        local offered = ns.AvailableQuest(step.id, step.scanMaps)
        if offered then return offered.map, offered.x, offered.y, "Quest start (live)" end
        return nil
    end
    if step.map and step.x and step.y then
        return step.map, step.x, step.y, step.pinLabel or "Quest giver"
    end
end

function ns.Navigate(step)
    if InCombatLockdown() then
        print("Appearance Guide: open the map after combat.")
        return
    end
    local map, x, y = ns.Waypoint(step)
    if map and x and y and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        OpenWorldMap(map)
    elseif C_QuestLog.IsOnQuest(step.id) then
        C_SuperTrack.SetSuperTrackedQuestID(step.id)
        OpenWorldMap()
        if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(step.id) end
    else
        OpenWorldMap(step.map)
    end
end

function ns.HasTomTom()
    return TomTom and type(TomTom.AddWaypoint) == "function" and type(TomTom.SetCrazyArrow) == "function"
end

-- Use the coordinates displayed on the button, rather than silently choosing a
-- different destination if live quest data changes between display and click.
function ns.SetArrow(target)
    if not target then return end
    if not ns.HasTomTom() then
        ns.Navigate(target.step)
        return
    end
    local title = "Appearance Guide: " .. ns.QuestName(target.step)
    if target.kind == "Quest giver" then title = title .. " - " .. target.step.npc end
    local uid = TomTom:AddWaypoint(target.map, target.x, target.y, {
        title=title, from="AppearanceGuide_Edit", persistent=false, crazy=false,
    })
    if uid then
        local arrival = TomTom.profile and TomTom.profile.arrow and TomTom.profile.arrow.arrival or 15
        -- AddWaypoint returns existing waypoints early, so explicitly retarget
        -- the arrow on every click, including a repeated click at the same pin.
        TomTom:SetCrazyArrow(uid, arrival, title)
    end
end

local function Completed(id)
    return C_QuestLog.IsQuestFlaggedCompleted(id)
end

-- Map offers are positive evidence only. An empty result can mean uncached
-- data or a hidden low-level quest, rather than an unmet prerequisite.
function ns.ScanOffers(maps)
    local result = {}
    if not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then return result end
    for _, map in ipairs(maps or {}) do
        for _, offer in ipairs(C_QuestLine.GetAvailableQuestLines(map) or {}) do
            if offer.questID and not offer.isHidden and not offer.inProgress
                and not Completed(offer.questID) and offer.x and offer.y
                and offer.x >= 0 and offer.x <= 1 and offer.y >= 0 and offer.y <= 1
                and (offer.x > 0 or offer.y > 0) then
                -- Coordinates belong to the queried map, not startMapID.
                result[offer.questID] = {map=map, x=offer.x, y=offer.y, name=offer.questName}
            end
        end
    end
    return result
end

function ns.AvailableQuest(id, maps)
    if ns.offerMaps == maps and ns.offers then return ns.offers[id] end
    return ns.ScanOffers(maps)[id]
end

function ns.TargetBlocker(guide)
    local api = C_CampaignInfo
    if not api or not api.GetCampaignID or not api.GetFailureReason then return nil end
    local campaignID = api.GetCampaignID(guide.campaignAnchors[1])
    if not campaignID or campaignID == 0 then return nil end
    local failure = api.GetFailureReason(campaignID)
    if failure and failure.questID and failure.questID > 0 and not Completed(failure.questID) then
        for i, step in ipairs(guide.steps) do
            if step.id == failure.questID then return nil end
            if C_QuestLog.IsOnQuest(step.id) or (i > 1 and Completed(step.id)) then return nil end
            if ns.AvailableQuest(step.id, guide.scanMaps) then return nil end
        end
        return failure.questID
    end
end

function ns.RequestGuideData(guide)
    ns.requestedQuests = {}
    if C_QuestLine and C_QuestLine.RequestQuestLinesForMap then
        for _, map in ipairs(guide.scanMaps or {}) do C_QuestLine.RequestQuestLinesForMap(map) end
    end
    for _, step in ipairs(guide.steps) do
        ns.requestedQuests[step.id] = true
        C_QuestLog.RequestLoadQuestByID(step.id)
    end
end

local function RequestQuest(id)
    ns.requestedQuests = ns.requestedQuests or {}
    if not ns.requestedQuests[id] then
        ns.requestedQuests[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
end

-- Campaign/quest-line metadata is read from the installed client. It is not a
-- universal prerequisite database: distinguish an explicit blocker from a
-- related campaign that the player may inspect for phasing or missing unlocks.
function ns.PrerequisiteGuide(base)
    local route = {name=base.name, steps={}, independent=true, scanMaps=base.scanMaps,
        note=base.note, unlockNote=base.unlockNote, notices={},
        minimumLevel=base.minimumLevel}
    if base.minimumLevel and UnitLevel then
        route.notices[#route.notices + 1] = string.format("The introduction requires level %d. You're level %d.", base.minimumLevel, UnitLevel("player"))
    end
    local seen, campaigns, known = {}, {}, {}
    for _, step in ipairs(base.steps) do known[step.id] = step end
    local function AddQuest(id, chapter, map)
        if not id or id == 0 or seen[id] then return end
        seen[id] = true
        RequestQuest(id)
        local step = {}
        if known[id] then
            for k, v in pairs(known[id]) do step[k] = v end
        else
            step = {id=id, name="Quest " .. id, npc="the quest giver shown on the map", live=true,
                map=map, scanMaps=base.scanMaps,
                note="Accept this campaign quest at its marked location, then complete the objectives below. The coordinate button follows your current objective once the quest is active."}
        end
        step.chapter = chapter
        route.steps[#route.steps + 1] = step
    end
    local function AddLine(id, chapter, map)
        local info = C_QuestLine and C_QuestLine.GetQuestLineInfo and C_QuestLine.GetQuestLineInfo(id, map)
        local quests = info and info.questLineID and C_QuestLine.GetQuestLineQuests and C_QuestLine.GetQuestLineQuests(info.questLineID)
        if quests and #quests > 0 then
            for _, questID in ipairs(quests) do AddQuest(questID, chapter, map) end
        else
            route.incompleteData = true
            AddQuest(id, chapter, map)
        end
    end
    local api = C_CampaignInfo
    local function AddCampaign(campaignID, related)
        if not campaignID or campaignID == 0 or campaigns[campaignID] then return end
        campaigns[campaignID] = true -- also stops cyclic failure-reason references
        local info = api.GetCampaignInfo(campaignID)
        local name = info and info.name or ("Campaign " .. campaignID)
        local failure = api.GetFailureReason and api.GetFailureReason(campaignID)
        local state = api.GetState and api.GetState(campaignID)
        local stateName = state == 1 and "Complete" or state == 2 and "In progress" or state == 3 and "Stalled" or "Unknown"
        route.notices[#route.notices + 1] = name .. ": " .. stateName
        if failure and failure.text and failure.text ~= "" then
            route.notices[#route.notices + 1] = "Game reports: " .. failure.text
        end
        if related then
            route.notices[#route.notices + 1] = "Related Dragonflight campaign: these are its actual steps, but the game has not confirmed that every chapter is required for this item."
        end
        if failure and failure.questID and failure.questID > 0 then
            local blockerID = failure.questID
            if not Completed(blockerID) then
                if not related then route.blockerID = blockerID end
            end
            local parentID = api.GetCampaignID(blockerID)
            if parentID ~= campaignID then AddCampaign(parentID, related) end
        end
        local chapterIDs = api.GetChapterIDs and api.GetChapterIDs(campaignID)
        for _, chapterID in ipairs(chapterIDs or {}) do
            local chapter = api.GetCampaignChapterInfo(chapterID)
            if chapter and chapter.rewardQuestID and chapter.rewardQuestID > 0 then
                AddLine(chapter.rewardQuestID, chapter.name, nil)
            end
        end
        if failure and failure.questID and failure.questID > 0 and not seen[failure.questID] then
            AddLine(failure.questID, "Campaign requirement: " .. name, failure.mapID)
        end
        if not chapterIDs or #chapterIDs == 0 then route.incompleteData = true end
    end
    if api and api.GetCampaignID and api.GetCampaignInfo then
        for i, anchor in ipairs(base.campaignAnchors or {}) do
            AddCampaign(api.GetCampaignID(anchor), i > 1)
        end
    else
        route.notices[#route.notices + 1] = "Campaign information is unavailable from the client."
        route.incompleteData = true
    end
    AddQuest(base.steps[1].id, "Introduction to The Silver Purpose", base.steps[1].map)
    if route.incompleteData then
        route.notices[#route.notices + 1] = "Some campaign step lists have not been supplied by the game. Missing data is not treated as completion or as proof that a quest is available."
    end
    return route
end

-- Campaign lists can have parallel objectives or optional branches. Never use
-- the reward chain's linear-frontier inference to mark these quests passed.
function ns.PrerequisiteProgress(guide)
    local p = {states={}, completedCount=0, passedCount=0, total=#guide.steps}
    local first, activeIndex, offeredIndex, blockerIndex
    for i, step in ipairs(guide.steps) do
        if Completed(step.id) then
            p.states[i] = "Complete"
            p.completedCount = p.completedCount + 1
        elseif C_QuestLog.IsOnQuest(step.id) then
            p.states[i] = C_QuestLog.IsComplete(step.id) and "Ready to turn in" or "In progress"
            activeIndex = activeIndex or i
        else
            local offered = ns.AvailableQuest(step.id, guide.scanMaps)
            p.states[i] = offered and "Available" or "Later"
            if offered then offeredIndex = offeredIndex or i end
        end
        if p.states[i] ~= "Complete" then
            first = first or i
            if step.id == guide.blockerID then blockerIndex = i end
        end
    end
    p.nextIndex = blockerIndex or activeIndex or offeredIndex or first
    if p.nextIndex and p.states[p.nextIndex] == "Later" then p.states[p.nextIndex] = "Unverified" end
    return p
end

function ns.Readiness(guide, step)
    if Completed(step.id) or C_QuestLog.IsOnQuest(step.id) then return nil end
    if ns.AvailableQuest(step.id, guide.scanMaps) then
        return "The game currently lists this quest as available."
    end
    if not guide.independent and guide.minimumLevel and UnitLevel and UnitLevel("player") < guide.minimumLevel then
        return string.format("Requires level %d. You're level %d. Continue leveling before attempting this unlock.", guide.minimumLevel, UnitLevel("player"))
    end
    if guide.independent then
        return "This step is unfinished, but the game has not confirmed that you can accept it yet."
    end
    return "Quest availability is not confirmed. Prerequisites checks this character's campaign progress and expands the campaign into individual quest steps."
end

ns.events = CreateFrame("Frame")
ns.events:RegisterEvent("ADDON_LOADED")
ns.events:RegisterEvent("PLAYER_LOGIN")
ns.events:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.events:RegisterEvent("QUEST_LOG_UPDATE")
ns.events:RegisterEvent("QUEST_TURNED_IN")
ns.events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
ns.events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
ns.events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ns.events:RegisterEvent("PLAYER_LEVEL_UP")
ns.events:RegisterEvent("QUESTLINE_UPDATE")
ns.events:SetScript("OnEvent", function(_, event, addonName)
    if (event == "ADDON_LOADED" and addonName == "AppearanceGuide_Edit") or event == "PLAYER_LOGIN" then
        ns.CharacterSettings()
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
    end
    if event == "GET_ITEM_INFO_RECEIVED" and ns.RefreshLauncher then ns.RefreshLauncher() end
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        if ns.InstallWardrobe then ns.InstallWardrobe() end
    end
    if ns.window and ns.window:IsShown() and not ns.refreshQueued then
        ns.refreshQueued = true
        C_Timer.After(0.15, function()
            ns.refreshQueued = false
            if ns.window and ns.window:IsShown() then ns.Refresh() end
        end)
    end
end)

SLASH_APPEARANCEGUIDEEDIT1 = "/appearanceguide"
SLASH_APPEARANCEGUIDEEDIT2 = "/ag"
SlashCmdList.APPEARANCEGUIDEEDIT = function(message)
    message = (message or ""):match("^%s*(.-)%s*$")
    if message == "" then ns.OpenActiveItem(); return end
    local track = message:match("^track%s+(.+)$")
    if message == "track" then
        local id = ns.window and ns.window:IsShown() and ns.window.itemID or ns.ActiveItemID()
        if ns.SetActiveItem(id) then ns.OpenActiveItem() end
        return
    end
    local target = track or message
    local id = ValidItemID(target:match("^(%d+)$") or target:match("item:(%d+)"))
    if id then
        if track then ns.SetActiveItem(id) end
        ns.OpenItem(id)
    else
        print("Appearance Guide: /ag opens your active item. /ag <item ID or link> previews an item; /ag track [item ID or link] makes it active.")
    end
end
