local AddonName, MKPT_env = ...
local Utils, L = MKPT_env.Utils, MKPT_env.L
local contextMenu

function MKPT_env.BuildExpansionMenu(_, root)
  local expansions = {
    { Enum.ExpansionLevel.Midnight, EXPANSION_NAME11 },
    { Enum.ExpansionLevel.WarWithin, EXPANSION_NAME10 },
    { Enum.ExpansionLevel.Dragonflight, EXPANSION_NAME9 },
  }
  for _, expansion in ipairs(expansions) do
    local radio = root:CreateRadio(expansion[2], function(value)
      return MKPT_env.charDb.state.expansion == value
    end, MKPT_env.ToggleExpansion, expansion[1])
    radio:SetEnabled(not InCombatLockdown())
  end
end

function MKPT_env.BuildFilterMenu(root)
  local filters = {
    { "hideUniqueTreasures", Utils.UNIQUE_TREASURE_ICON, "Unique Treasures" },
    { "hideFirstTimeGather", Utils.FIRST_GATHER_ICON, "First Time Gather" },
    { "hideUniqueBooks", Utils.UNIQUE_BOOK_ICON, "Unique/Renown Books" },
    { "hideTreatise", Utils.TREATISE_ICON, "Treatise" },
    { "hideWeeklyQuests", Utils.WEEKLY_QUEST_ICON, "Weekly Quests" },
    { "hideWeeklyTreasures", Utils.WEEKLY_TREASURE_ICON, "Weekly Treasures" },
    { "hideCatchUp", Utils.CATCHUP_ICON, "Catch-Up" },
  }
  for _, filter in ipairs(filters) do
    root:CreateCheckbox(filter[2] .. " " .. L[filter[3]], function(key)
      return not MKPT_env.db.config[key]
    end, function(key)
      MKPT_env.db.config[key] = not MKPT_env.db.config[key]
      MKPT_env.ui:RenderTree()
    end, filter[1])
  end
  if MKPT_env.charDb.state.expansion == Enum.ExpansionLevel.Midnight then
    root:CreateCheckbox(Utils.DUNDUN_ICON .. " " .. MKPT_env.MKPT_ShardOfDundun.name,
      function() return not MKPT_env.db.config.hideDundun end,
      function()
        MKPT_env.db.config.hideDundun = not MKPT_env.db.config.hideDundun
        MKPT_env.ui:RenderTree()
      end)
  end
  root:CreateCheckbox(Utils.FILLED_TREE_ICON .. " " .. Utils.GoldTextColor(L["Filled Tree"]),
    function() return not MKPT_env.charDb.config.professionsHideFilledTree end,
    function()
      MKPT_env.charDb.config.professionsHideFilledTree = not MKPT_env.charDb.config.professionsHideFilledTree
      MKPT_env.ui:RenderTree()
    end)
end

function MKPT_env.ShowRightClickMenu(owner)
  contextMenu = MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
    root:CreateTitle(EXPANSION_FILTER_TEXT)
    MKPT_env.BuildExpansionMenu(nil, root)
    root:CreateDivider()
    root:CreateTitle(L["Show/Hide"])
    MKPT_env.BuildFilterMenu(root)
    root:CreateDivider()
    root:CreateCheckbox(L["Lock Window"], function() return MKPT_env.db.ui.lockWindow end,
      function()
        MKPT_env.SetLockUi(not MKPT_env.db.ui.lockWindow)
        Settings.NotifyUpdate("MKPT_LockWindow")
      end)
    root:CreateCheckbox(L["Auto hide"], function() return MKPT_env.db.ui.autohide end, MKPT_env.ToggleAutoHide)
    local fit = root:CreateButton(L["Fit height to contents"], MKPT_env.FitUiHeight)
    fit:SetEnabled(not MKPT_env.db.ui.lockWindow)
    local settings = root:CreateButton(L["Settings"], function()
      if not InCombatLockdown() then Settings.OpenToCategory(MKPT_env.categoryId) end
    end)
    settings:SetEnabled(not InCombatLockdown())
  end)
end

function MKPT_env.IsShowingRightClickMenu()
  return contextMenu and contextMenu:IsShown() or false
end
