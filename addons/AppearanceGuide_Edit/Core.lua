local _, ns = ...

function ns.QuestName(step)
    return C_QuestLog.GetTitleForQuestID(step.id) or step.name
end

-- Character flags only: an alt's completion must not skip this character's
-- prerequisites. A later active/completed quest proves earlier steps passed,
-- even when a campaign skip did not set every earlier completion flag.
function ns.Progress(guide)
    local frontier = 0
    for i, step in ipairs(guide.steps) do
        if C_QuestLog.IsQuestFlaggedCompleted(step.id) then
            frontier = math.max(frontier, i)
        elseif C_QuestLog.IsOnQuest(step.id) then
            frontier = math.max(frontier, i - 1)
        end
    end
    local result = {states={}, nextIndex=frontier + 1}
    for i, step in ipairs(guide.steps) do
        local status
        if C_QuestLog.IsQuestFlaggedCompleted(step.id) then status = "Complete"
        elseif C_QuestLog.IsOnQuest(step.id) then
            status = C_QuestLog.IsComplete(step.id) and "Ready to turn in" or "In progress"
        elseif i <= frontier then status = "Passed"
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
    return step.map, step.x, step.y, "Quest giver"
end

function ns.Navigate(step)
    if InCombatLockdown() then
        print("Appearance Guide: open the map after combat.")
        return
    end
    local map, x, y = ns.Waypoint(step)
    if map and C_Map.CanSetUserWaypointOnMap(map) then
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

ns.events = CreateFrame("Frame")
ns.events:RegisterEvent("ADDON_LOADED")
ns.events:RegisterEvent("PLAYER_LOGIN")
ns.events:RegisterEvent("QUEST_LOG_UPDATE")
ns.events:RegisterEvent("QUEST_TURNED_IN")
ns.events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
ns.events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
ns.events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ns.events:SetScript("OnEvent", function(_, event)
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
    local id = tonumber(message:match("^%s*(%d+)%s*$")) or tonumber(message:match("item:(%d+)"))
    ns.OpenItem(id or 208198)
end
