local _, addon = ...

addon.PresetNames = { full = "Full Swap", extras = "Cage Extras", fill = "Fill Collection" }
addon.DefaultSettings = {
    preset = "full", keep = 1, protectFavorites = true, protectNamed = true,
    takeUpgrades = false, takeExtras = false, showMinimap = true,
}

function addon.GetSettings()
    if type(CageHaulSettings) ~= "table" then CageHaulSettings = {} end
    local settings = CageHaulSettings
    for key, default in pairs(addon.DefaultSettings) do
        if type(settings[key]) ~= type(default) then settings[key] = default end
    end
    if not addon.PresetNames[settings.preset] then settings.preset = "full" end
    if not (settings.keep >= 0 and settings.keep <= 3) then settings.keep = 1 end
    settings.keep = math.floor(settings.keep)
    return settings
end

function addon.Profile()
    local settings = addon.GetSettings()
    return {
        preset = settings.preset, keep = settings.keep,
        protectFavorites = settings.protectFavorites, protectNamed = settings.protectNamed,
        takeUpgrades = settings.takeUpgrades, takeExtras = settings.takeExtras,
    }
end

function addon.IsProtectedPet(info, profile)
    return (profile.protectFavorites and info.isFavorite)
        or (profile.protectNamed and info.customName and info.customName ~= "")
end

function addon.PetRank(level, quality)
    return level and quality and quality * 100 + level or nil
end

function addon.JournalRank(id, info)
    local rarity = select(5, C_PetJournal.GetPetStats(id))
    return addon.PetRank(info.petLevel, rarity and rarity - 1)
end

function addon.GetCageLinkInfo(link)
    if not link then return false end
    local data = link:match("|H([^|]+)|h") or link
    local species, level, quality = data:match("^battlepet:(%d+):?(%d*):?(%d*)")
    return species ~= nil or tonumber(data:match("^item:(%d+)")) == 82800,
        tonumber(species), tonumber(level), tonumber(quality)
end

function addon.GetCageTooltipInfo(data)
    if data then
        TooltipUtil.SurfaceArgs(data)
        local species = tonumber(data.battlePetSpeciesID)
        if species or data.type == Enum.TooltipDataType.BattlePet then
            return true, species, tonumber(data.battlePetLevel), tonumber(data.battlePetBreedQuality)
        end
    end
    return false
end
