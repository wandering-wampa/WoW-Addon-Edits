local _, addon = ...
local category
local SETTING_PREFIX = "CAGEHAUL_"

local function RegisterSettings()
    if category then return end
    local db = addon.GetSettings()
    local defaults = addon.DefaultSettings
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("Cage Haul")

    local function Setting(key, label)
        return Settings.RegisterAddOnSetting(category, SETTING_PREFIX .. key, key, db, type(defaults[key]), label, defaults[key])
    end

    local minimap = Setting("showMinimap", "Show minimap button")
    minimap:SetValueChangedCallback(addon.RefreshMinimapVisibility)
    Settings.CreateCheckbox(category, minimap, "Show the pet trap that opens Cage Haul. /cagehaul always opens the panel.")

    local preset = Setting("preset", "Transfer preset")
    preset:SetValueChangedCallback(addon.RefreshPanel)
    Settings.CreateDropdown(category, preset, function()
        local options = Settings.CreateControlTextContainer()
        options:Add("full", addon.PresetNames.full, "Cage all eligible pets and retrieve any cages from the selected tab.")
        options:Add("extras", addon.PresetNames.extras, "Cage surplus pets according to the copy target and protections below.")
        options:Add("fill", addon.PresetNames.fill, "Retrieve missing learnable species first, then any optional upgrades or extra copies.")
        return options:GetData()
    end, "Applies when you start the next batch. Use /cagehaul status to preview it.")

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Cage Extras"))
    Settings.CreateDropdown(category, Setting("keep", "Copies to keep per species"), function()
        local options = Settings.CreateControlTextContainer()
        for count = 0, 3 do options:Add(count, tostring(count)) end
        return options:GetData()
    end, "Keeps the strongest copies by quality, then by pet level. Zero allows caging the last copy.")
    Settings.CreateCheckbox(category, Setting("protectFavorites", "Keep favorited pets"),
        "Protect every favorited pet while using Cage Extras, even above the copy target.")
    Settings.CreateCheckbox(category, Setting("protectNamed", "Keep named pets"),
        "Protect every pet with a custom name while using Cage Extras, even above the copy target.")

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Fill Collection"))
    Settings.CreateCheckbox(category, Setting("takeUpgrades", "Retrieve upgrades"),
        "After missing species, retrieve a stronger learnable copy if there's room under the species cap. Quality is compared before level.")
    Settings.CreateCheckbox(category, Setting("takeExtras", "Retrieve extra copies"),
        "After missing species and selected upgrades, retrieve learnable extras up to the species cap. Cages already in your bags count toward it.")

    Settings.RegisterAddOnCategory(category)
end

function addon.SetPreset(preset)
    RegisterSettings()
    Settings.SetValue(SETTING_PREFIX .. "preset", preset)
end

function addon.OpenSettings()
    RegisterSettings()
    Settings.OpenToCategory(category:GetID())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", RegisterSettings)
