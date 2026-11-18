local _, addon = ...
local journal = C_PetJournal

function addon.GetCollectionRanks()
    local highest, best = 1, {}
    for _, id in ipairs(journal.GetOwnedPetIDs()) do
        local info = journal.GetPetInfoTableByPetID(id)
        if info and info.speciesID and not journal.PetIsRevoked(id) then
            highest = math.max(highest, info.petLevel or 1)
            local rank = addon.JournalRank(id, info)
            if rank and rank > (best[info.speciesID] or -1) then best[info.speciesID] = rank end
        end
    end
    return { highest = highest, best = best }
end

function addon.PlanFillCollection(cages, bagCages, profile, collection)
    local state = {}
    local summary = { missing = 0, upgrades = 0, extras = 0, inBags = 0,
        highLevel = 0, unidentified = 0, locked = 0, capped = 0 }
    local function Species(id)
        if not state[id] then
            local owned, limit = journal.GetNumCollectedInfo(id)
            state[id] = { owned = owned, limit = limit, reserved = 0, learnable = 0, best = collection.best[id] }
        end
        return state[id]
    end

    for _, cage in ipairs(bagCages) do
        if cage.species then
            local info = Species(cage.species)
            info.reserved = info.reserved + cage.count
            if cage.level and cage.level >= 1 and cage.level <= collection.highest then
                info.learnable = info.learnable + cage.count
                local rank = addon.PetRank(cage.level, cage.quality)
                if rank and rank > (info.best or -1) then info.best = rank end
            end
        end
    end

    for _, cage in ipairs(cages) do
        cage.rank = addon.PetRank(cage.level, cage.quality)
    end
    table.sort(cages, function(a, b)
        local left, right = a.rank or -1, b.rank or -1
        if left ~= right then return left > right end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return a.slot < b.slot
    end)

    local groups = { missing = {}, upgrades = {}, extras = {} }
    for _, cage in ipairs(cages) do
        if cage.locked then
            summary.locked = summary.locked + 1
        elseif not cage.species or not cage.level or cage.level < 1 then
            summary.unidentified = summary.unidentified + 1
        elseif cage.level > collection.highest then
            summary.highLevel = summary.highLevel + 1
        else
            local info = Species(cage.species)
            if info.owned == 0 and info.learnable > 0 and not info.reportedInBags then
                summary.inBags = summary.inBags + 1
                info.reportedInBags = true
            end
            local group
            if not info.owned or not info.limit or info.limit <= 0 then
                summary.unidentified = summary.unidentified + 1
            elseif info.owned + info.reserved + (cage.count or 1) > info.limit then
                summary.capped = summary.capped + 1
            elseif info.owned == 0 and info.learnable == 0 and not info.selected then
                group = "missing"
            elseif profile.takeUpgrades and not info.selected and info.best and cage.rank and cage.rank > info.best then
                group = "upgrades"
            elseif profile.takeExtras then
                group = "extras"
            end
            if group then
                info.reserved = info.reserved + (cage.count or 1)
                info.selected = true
                local list = groups[group]
                list[#list + 1] = cage
            end
        end
    end

    local plan = {}
    for _, group in ipairs({ "missing", "upgrades", "extras" }) do
        summary[group] = #groups[group]
        for _, cage in ipairs(groups[group]) do plan[#plan + 1] = cage end
    end
    return plan, summary
end
