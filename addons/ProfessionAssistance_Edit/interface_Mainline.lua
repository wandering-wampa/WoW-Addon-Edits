local L = PA_LOCALIZATION

local addonName = ...;
local settingDefaults = {
	MasterChecked = true,
	ShowAllIconChecked = true,
	AuctionatorPrices = true,
	
	-- Professions tab
	-- Herbalism
	HerbalismChecked = true,
	HerbalismChatChecked = true,
	HerbalismKeyChecked = true,
	HerbalismKey = false,
	
	-- Milling
	MillingChecked = true,
	MillingChatChecked = true,
	MillingKey = false,
	MillingIconChecked = false,
	
	HerbChecked = true,
	HerbChatChecked = true,
	HerbKey = false,
	HerbIconChecked = false,
	
	-- Mining
	MiningChecked = true,
	MiningChatChecked = true,
	MiningKey = false,
	
	-- Prospecting
	ProspectingChecked = true,
	ProspectingChatChecked = true,
	ProspectingKey = false,
	ProspectingIconChecked = false,
	
	OreChecked = true,
	OreChatChecked = true,
	OreKey = false,
	OreIconChecked = false,
	
	-- Enchanting
	EnchantingChecked = true,
	EnchantingChatChecked = true,
	EnchantingKey = false,
	EnchantingIconChecked = false,

	MaterialChecked = true,
	MaterialChatChecked = true,
	MaterialKey = false,
	MaterialIconChecked = false
}

local professionOptions = {
	{
		headerLabel = L["Herbalism Locations"],
		enable = {
			key = "HerbalismChecked",
			label = L["Enable Herbalism"],
			description = L["Toggle herbalism locations on herbs"]
		},
		chat = {
			key = "HerbalismChatChecked",
			description = L["Toggle chat herbalism locations on herbs"]
		},
		shift = {
			key = "HerbalismKey",
			description = L["Hold Shift to show Herbalism locations"]
		}
	},
	
	{
		headerLabel = L["Milling"],
		enable = {
			key = "MillingChecked",
			label = L["Enable Milling"],
			description = L["Toggle milling information on herbs"]
		},
		chat = {
			key = "MillingChatChecked",
			description = L["Toggle chat information on herbs"]
		},
		shift = {
			key = "MillingKey",
			description = L["Hold Shift to show milling information"]
		},
		icon = {
			key = "MillingIconChecked"
		}
	},
	
	{
		enable = {
			key = "HerbChecked",
			label = L["Enable Herb"],
			description = L["Toggle herb information on pigments"]
		},
		chat = {
			key = "HerbChatChecked",
			description = L["Toggle chat information on pigments"]
		},
		shift = {
			key = "HerbKey",
			description = L["Hold Shift to show Herb information"]
		},
		icon = {
			key = "HerbIconChecked"
		}
	},
	
	{
		headerLabel = L["Mining Locations"],
		enable = {
			key = "MiningChecked",
			label = L["Enable Mining"],
			description = L["Toggle mining locations on ores"]
		},
		chat = {
			key = "MiningChatChecked",
			description = L["Toggle chat mining locations on ores"]
		},
		shift = {
			key = "MiningKey",
			description = L["Hold Shift to show Mining locations"]
		}
	},
	
	{
		headerLabel = L["Prospecting"],
		enable = {
			key = "ProspectingChecked",
			label = L["Enable Prospecting"],
			description = L["Toggle prospecting information on ores"]
		},
		chat = {
			key = "ProspectingChatChecked",
			description = L["Toggle chat information on ores"]
		},
		shift = {
			key = "ProspectingKey",
			description = L["Hold Shift to show Prospecting information"]
		},
		icon = {
			key = "ProspectingIconChecked"
		}
	},

	{
		enable = {
			key = "OreChecked",
			label = L["Enable Ore"],
			description = L["Toggle ore information on gems"]
		},
		chat = {
			key = "OreChatChecked",
			description = L["Toggle chat information on gems"]
		},
		shift = {
			key = "OreKey",
			description = L["Hold Shift to show Ore information"]
		},
		icon = {
			key = "OreIconChecked"
		}
	},
	
	{
		headerLabel = L["Enchanting"],
		enable = {
			key = "EnchantingChecked",
			label = L["Enable Enchanting"],
			description = L["Toggle Disenchanting information on gear"]
		},
		chat = {
			key = "EnchantingChatChecked",
			description = L["Toggle chat information on gear"]
		},
		shift = {
			key = "EnchantingKey",
			description = L["Hold Shift to show Disenchanting information"]
		},
		icon = {
			key = "EnchantingIconChecked"
		}
	},

	{
		enable = {
			key = "MaterialChecked",
			label = L["Enable Materials"],
			description = L["Toggle gear source information on enchanting materials"]
		},
		chat = {
			key = "MaterialChatChecked",
			description = L["Toggle chat information on enchanting materials"]
		},
		shift = {
			key = "MaterialKey",
			description = L["Hold Shift to show Material information"]
		},
		icon = {
			key = "MaterialIconChecked"
		}
	}
}

---------------------------------
-- Initialize default settings --
---------------------------------
local function InitializeDefaults()
	PA_SavedSettings = PA_SavedSettings or {}

	for key, value in pairs(settingDefaults) do
		if PA_SavedSettings[key] == nil then
			PA_SavedSettings[key] = value
		end
	end
end

-----------------------------
-- Create checkboxes stuff --
-----------------------------
local function CreateCheckboxSetting(category, key, label, tooltip)
	local checkboxSetting = Settings.RegisterAddOnSetting(
		category,
		key,
		key,
		PA_SavedSettings,
		type(PA_SavedSettings[key]),
		label,
		settingDefaults[key]
	)

	return Settings.CreateCheckbox(category, checkboxSetting, tooltip);
end

----------------------------
-- FontText creator stuff --
----------------------------
local function createFontText(parent, x_loc, y_loc, text, fonttemplate)
	local title = parent:CreateFontString(nil, "ARTWORK", fonttemplate);
	title:SetPoint("TOPLEFT", x_loc, y_loc);
	title:SetJustifyH("LEFT");
	title:SetText(text);
end

------------------------------------
-- Registering the settings stuff --
------------------------------------
local function RegisterSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory(addonName);

	Settings.RegisterAddOnCategory(category);

	local masterButton = CreateCheckboxSetting(
		category,
		"MasterChecked",
		L["Enable Master"],
		L["Master switch"]
	);

	local masterIconButton = CreateCheckboxSetting(
		category,
		"ShowAllIconChecked",
		L["Show Icons"],
		L["Show icons in front of result items"]
	);

	local function masterCheck()
		return PA_SavedSettings["MasterChecked"]
	end

	masterIconButton:SetParentInitializer(masterButton, masterCheck);
	local priceButton = CreateCheckboxSetting(
		category,
		"AuctionatorPrices",
		"Show Auctionator prices",
		"Show the Auctionator database price per individual material. No price means no recorded price is available. Requires Auctionator."
	);
	priceButton:SetParentInitializer(masterButton, masterCheck);

	for _, option in ipairs(professionOptions) do
		if option.headerLabel ~= nil then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(option.headerLabel))
		end;

		local mainButton = CreateCheckboxSetting(
			category,
			option.enable.key,
			option.enable.label,
			option.enable.description
		);

		local function mainCheck()
			return PA_SavedSettings[option.enable.key]
		end

		if option.chat then
			local chatButton = CreateCheckboxSetting(
				category,
				option.chat.key,
				option.chat.label or L["Enable chat"],
				option.chat.description
			);
			chatButton:SetParentInitializer(mainButton, mainCheck);
		end

		if option.shift then
			local shiftButton = CreateCheckboxSetting(
				category,
				option.shift.key,
				option.shift.label or L["On Shift"],
				option.shift.description
			);
			shiftButton:SetParentInitializer(mainButton, mainCheck);
		end
			
		if option.icon then
			local iconButton = CreateCheckboxSetting(
				category,
				option.icon.key,
				option.icon.label or L["Show Icons"],
				option.icon.description or L["Show icons in front of result items"]
			);
			iconButton:SetParentInitializer(mainButton, mainCheck);
		end
	end

	return category;
end

---------------------------------
-- Registering opening methods --
---------------------------------
local function RegisterOpenMethods(category)
	SLASH_PA1, SLASH_PA2, SLASH_PA3 = '/' .. L["PA"], '/Profesion Assistance', '/Profession_Assistance';
	SLASH_PA4 = '/ProfessionAssistance_Edit';
	function SlashCmdList.PA()
		Settings.OpenToCategory(category:GetID());
	end
	
	function ProfessionAssistance_OnAddonCompartmentClick(addonName, buttonName)
		Settings.OpenToCategory(category:GetID());
	end
end

-------------------------
-- credits panel stuff --
-------------------------
local function CreateAndRegisterCreditsFrame(mainCategory)
	local PA_CreditsFrame = CreateFrame("Frame", "Credits")

	-- Title
	--createFonttext(Parent, Positionx, Positiony, text, template)
	createFontText(PA_CreditsFrame, 15, -15, addonName, "GameFontNormalLarge");

	local translatorNote = [[
|cffffcc00Special thanks to the following people for translating:|r
Kad_Caiel
XingDvD
hideki66687653
laruskane
x_RazzorX_x
ScaXFuLL
Vanyshing
Donghaerang
Naodtome
아련별
arhkeis
dadec666
takasun39
BNS333
lovesingcat
]]

	-- Content
	createFontText(PA_CreditsFrame, 20, -40, "|cffffcc00Version|r     "..C_AddOns.GetAddOnMetadata(addonName,"Version"), "GameFontHighlight");
	createFontText(PA_CreditsFrame, 20, -55, "|cffffcc00Notes|r       "..C_AddOns.GetAddOnMetadata(addonName,"Notes"), "GameFontHighlight");
	createFontText(PA_CreditsFrame, 20, -85, "|cffffcc00Author|r      "..C_AddOns.GetAddOnMetadata(addonName,"Author"), "GameFontHighlight");
	createFontText(PA_CreditsFrame, 20, -100, "|cffffcc00Credits|r     "..C_AddOns.GetAddOnMetadata(addonName,"X-Credits"), "GameFontHighlight");
	createFontText(PA_CreditsFrame, 20, -130, translatorNote, "GameFontHighlight");
	
	return Settings.RegisterCanvasLayoutSubcategory(
		mainCategory,
		PA_CreditsFrame,
		"Credits"
	)
end

------------------------------------------
-- Creating actual settings frame stuff --
------------------------------------------
local PA_Frame = CreateFrame("Frame");
PA_Frame:RegisterEvent("ADDON_LOADED");
PA_Frame:SetScript("OnEvent", function(_, _, name)
	if name ~= addonName then
		return
	end

	InitializeDefaults();

	local category = RegisterSettings();
	CreateAndRegisterCreditsFrame(category);

	RegisterOpenMethods(category);
end)
