local AddonName, MKPT_env = ...
local Utils, L = MKPT_env.Utils, MKPT_env.L

-- Personal Retail frame treatment, matching ConcentrationTracker_Edit.
local f = CreateFrame("Frame", "MKPT_Frame", UIParent, "PortraitFrameTemplate,BackdropTemplate")
MKPT_env.ui = f
f:Hide()
local MIN_WIDTH, MIN_HEIGHT = 480, 320
local HEADER, FOOTER = 80, 36
local framePool

local function SavePosition()
  local x, y = f:GetLeft(), f:GetTop() - UIParent:GetHeight() / f:GetScale()
  MKPT_env.db.position = { x = x, y = y }
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

local function StopMoving()
  if not f.moving and not f.sizing then return end
  f:StopMovingOrSizing()
  f.moving, f.sizing = false, false
  SavePosition()
  MKPT_env.db.ui.windowSize = { width = f:GetWidth(), height = f:GetHeight() }
end

local function Tooltip(owner, title, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title)
  if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
  GameTooltip:Show()
end

local function CreateInset(parent, backgroundAtlas)
  local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
  inset:SetFrameLevel(parent:GetFrameLevel() + 1)
  local base = inset:CreateTexture(nil, "BACKGROUND", nil, -8)
  base:SetAllPoints()
  base:SetColorTexture(0.06, 0.06, 0.06, 1)
  if inset.Bg then
    if backgroundAtlas then
      inset.Bg:SetAtlas(backgroundAtlas, false)
      inset.Bg:SetVertexColor(1, 1, 1, 1)
    else
      inset.Bg:SetVertexColor(0.8, 0.8, 0.8, 1)
    end
  end
  return inset
end

local function CreateScroll(parent, inset, name)
  local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
  scroll:SetFrameLevel(inset:GetFrameLevel() + 2)
  scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -27, 6)
  scroll:HookScript("OnScrollRangeChanged", function(self, _, verticalRange)
    self:SetVerticalScroll(math.min(self:GetVerticalScroll(), math.max(0, verticalRange or 0)))
  end)
  return scroll
end

function f:UpdateLayout()
  if not self.tree or self.layingOut then return end
  self.layingOut = true
  local contentWidth = math.max(1, self:GetWidth() - 57)
  self.tree:SetWidth(contentWidth)
  self.detailText:SetWidth(contentWidth)
  local textHeight = self.detailValue and self.detailText:GetStringHeight() or 0
  local detailHeight = self.detailValue and math.min(120, math.max(48, textHeight + 16)) or 0
  self.detailContent:SetSize(contentWidth, math.max(1, textHeight + 4))
  self.detailInset:SetHeight(math.max(1, detailHeight))
  self.detailInset:SetShown(detailHeight > 0)
  self.detailScroll:SetShown(detailHeight > 0)
  self.listInset:ClearAllPoints()
  self.listInset:SetPoint("TOPLEFT", 12, -HEADER)
  self.listInset:SetPoint("BOTTOMRIGHT", -12, FOOTER + (detailHeight > 0 and detailHeight + 6 or 0))
  self.layingOut = false
end

function f:UpdateDetail(text)
  if text ~= self.detailValue then self.detailScroll:SetVerticalScroll(0) end
  self.detailValue = text
  self.detailText:SetText(text or "")
  self:UpdateLayout()
end

function MKPT_env.CreateUI()
  if f.initialized then return f end
  local db = MKPT_env.db
  if not db then return end
  local position = db.position or { x = 100, y = -100 }
  local size = db.ui.windowSize or { width = 540, height = 440 }
  f:SetSize(math.max(MIN_WIDTH, size.width or 540), math.max(MIN_HEIGHT, size.height or 440))
  f:SetScale(db.ui.scale)
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, position.y)
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetResizable(true)
  f:SetBackdrop({ bgFile = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true,
    tileSize = 256, insets = { left = 4, right = 4, top = 24, bottom = 4 } })
  f:SetBackdropColor(0.65, 0.65, 0.65, 1)
  ButtonFrameTemplate_HidePortrait(f)
  f.title = f.TitleContainer.TitleText
  f.title:ClearAllPoints()
  f.title:SetPoint("LEFT", f.TitleContainer, "LEFT", 8, 0)
  f.title:SetPoint("RIGHT", f.TitleContainer, "RIGHT", -8, 0)
  f.title:SetJustifyH("CENTER")
  f.title:SetText(L["Knowledge Point Tracker"])
  f.closeButton = f.CloseButton
  f.closeButton:SetScript("OnClick", function() MKPT_env.ToggleUi() end)

  -- Drag only the title bar; selecting a knowledge source never moves the window.
  f.dragHandle = CreateFrame("Frame", nil, f)
  f.dragHandle:SetPoint("TOPLEFT", 8, -2)
  f.dragHandle:SetPoint("TOPRIGHT", -30, -2)
  f.dragHandle:SetHeight(24)
  f.dragHandle:EnableMouse(true)
  f.dragHandle:RegisterForDrag("LeftButton")
  f.dragHandle:SetScript("OnDragStart", function()
    if not db.ui.lockWindow then f.moving = true; f:StartMoving() end
  end)
  f.dragHandle:SetScript("OnDragStop", StopMoving)
  f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f) end
  end)
  f.dragHandle:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f) end
  end)

  f.expansionDropdown = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
  f.expansionDropdown:SetPoint("TOPLEFT", 16, -41)
  f.expansionDropdown:SetWidth(180)
  f.expansionDropdown:SetupMenu(MKPT_env.BuildExpansionMenu)
  f.settingsButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.settingsButton:SetSize(90, 24)
  f.settingsButton:SetPoint("TOPRIGHT", -16, -42)
  f.settingsButton:SetText(L["Settings"])
  f.settingsButton:SetScript("OnClick", function()
    if not InCombatLockdown() then Settings.OpenToCategory(MKPT_env.categoryId) end
  end)
  f.filterButton = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
  f.filterButton:SetWidth(100)
  f.filterButton:SetPoint("RIGHT", f.settingsButton, "LEFT", -8, 0)
  f.filterButton:SetDefaultText(FILTER or L["Show/Hide"])
  f.filterButton:SetupMenu(function(_, root) MKPT_env.BuildFilterMenu(root) end)
  f.filterButton:OverrideText(FILTER or L["Show/Hide"])

  f.listInset = CreateInset(f, "Professions-background-summarylist")
  f.scrollFrame = CreateScroll(f, f.listInset, "MKPT_ListScrollFrame")
  f.tree = CreateFrame("Frame", nil, f.scrollFrame)
  f.tree:SetSize(480, 1)
  f.scrollFrame:SetScrollChild(f.tree)
  f.detailInset = CreateInset(f)
  f.detailInset:SetPoint("BOTTOMLEFT", 12, FOOTER)
  f.detailInset:SetPoint("BOTTOMRIGHT", -12, FOOTER)
  f.detailScroll = CreateScroll(f, f.detailInset, "MKPT_DetailScrollFrame")
  f.detailContent = CreateFrame("Frame", nil, f.detailScroll)
  f.detailContent:SetSize(480, 1)
  f.detailScroll:SetScrollChild(f.detailContent)
  f.detailText = f.detailContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.detailText:SetPoint("TOPLEFT", 0, -2)
  f.detailText:SetJustifyH("LEFT")
  f.detailText:SetWordWrap(true)
  f.detailText:SetFontHeight(db.ui.fontSize)

  f.hideButton = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  f.hideButton:SetSize(26, 26)
  f.hideButton:SetPoint("BOTTOMLEFT", 12, 6)
  f.hideButton.text = f.hideButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hideButton.text:SetPoint("LEFT", f.hideButton, "RIGHT", 0, 0)
  f.hideButton.text:SetText(L["Auto hide"])
  f.hideButton:SetChecked(db.ui.autohide)
  f.hideButton:SetScript("OnClick", function() MKPT_env.ToggleAutoHide() end)
  f.hideButton:SetScript("OnEnter", function(self)
    Tooltip(self, L["Auto hide"], L["Hides the window when the cursor is not over it"])
  end)
  f.hideButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.helpButton = CreateFrame("Button", nil, f)
  f.helpButton:SetPoint("BOTTOMRIGHT", -30, 9)
  f.helpButton:SetSize(200, 20)
  f.helpButton.text = f.helpButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.helpButton.text:SetAllPoints()
  f.helpButton.text:SetJustifyH("RIGHT")
  f.helpButton.text:SetText(L["Click on an item to track"])
  f.helpButton:SetScript("OnEnter", function(self)
    Tooltip(self, L["Knowledge Points"],
      Utils.WeeklyTextColor(L["Weekly"]) .. " / " .. Utils.CatchUpTextColor(L["Catch-Up"]) .. "\n" ..
      Utils.UniqueTextColor(L["Unique"]) .. " / " .. Utils.MissingTextColor(L["Missing"]) .. " / " ..
      Utils.UnspentKpsTextColor(L["Unspent"]))
  end)
  f.helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.resizeButton = CreateFrame("Button", nil, f)
  f.resizeButton:SetSize(16, 16)
  f.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
  f.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  f.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  f.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  f.resizeButton:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not db.ui.lockWindow then f.sizing = true; f:StartSizing("BOTTOMRIGHT") end
  end)
  f.resizeButton:SetScript("OnMouseUp", StopMoving)
  f:SetScript("OnSizeChanged", function(self) self:UpdateLayout() end)
  f:SetScript("OnHide", function(self)
    StopMoving()
    GameTooltip:Hide()
    self.expansionDropdown:CloseMenu()
    self.filterButton:CloseMenu()
    if not self.temporaryHidden and not self:IsShown() then MKPT_env.charDb.state.show = false end
  end)
  f:SetScript("OnShow", function(self)
    self.autoHideTarget = nil
    self:SetAlpha(1)
    self:RenderTree()
  end)
  f:SetScript("OnUpdate", function(self, elapsed)
    self.hoverElapsed = (self.hoverElapsed or 0) + elapsed
    if self.hoverElapsed < 0.1 then return end
    self.hoverElapsed = 0
    self.settingsButton:SetEnabled(not InCombatLockdown())
    MKPT_env.RefreshAutoHide()
  end)
  table.insert(UISpecialFrames, "MKPT_Frame")
  f.initialized = true
  MKPT_env.SetUiScale(db.ui.scale)
  MKPT_env.SetLockUi(db.ui.lockWindow)
  f:RenderTree()
  return f
end

-- Pool ownership is inside the scroll child, so expanded sources are clipped.
local function PrepareRow(b, kind)
  b:SetParent(f.tree)
  b.kind = kind
  local rowHeight = math.max(24, MKPT_env.db.ui.rowHeight)
  local professionRow = kind == "profession"
  local categoryRow = professionRow or kind == "trainer"
  for _, texture in ipairs(b.headerTextures) do texture:SetShown(categoryRow) end
  b.highlight:SetShown(kind == "item")
  b.expandHighlight:SetShown(professionRow)
  b:SetHeight(professionRow and rowHeight + 20 or rowHeight)
  b.icon:ClearAllPoints()
  b.icon:SetPoint("LEFT", 4, 0)
  b.icon:SetSize(professionRow and 32 or 20, professionRow and 32 or 20)
  b.leftText:ClearAllPoints()
  b.middleText:ClearAllPoints()
  b.rightText:ClearAllPoints()
  for _, text in ipairs({b.leftText, b.middleText, b.rightText}) do
    text:SetHeight(18)
    text:SetFontHeight(MKPT_env.db.ui.fontSize)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")
  end
  b.leftText:SetJustifyH("LEFT")
  b.rightText:SetJustifyH("RIGHT")
  if professionRow then
    b.middleText:SetPoint("TOPLEFT", b, "TOPLEFT", 44, -3)
    b.middleText:SetPoint("TOPRIGHT", b, "TOPRIGHT", -24, -3)
    b.middleText:SetJustifyH("LEFT")
    b.leftText:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 44, 3)
    b.rightText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 3)
    b.expand:Show()
  else
    b.leftText:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.rightText:SetPoint("RIGHT", -6, 0)
    b.middleText:SetPoint("LEFT", b.leftText, "RIGHT", 6, 0)
    b.middleText:SetPoint("RIGHT", b.rightText, "LEFT", -6, 0)
    b.middleText:SetJustifyH("LEFT")
    b.expand:Hide()
    if kind == "currency" then
      b.leftText:SetPoint("RIGHT", b.rightText, "LEFT", -8, 0)
    end
  end
  b.highlight:ClearAllPoints()
  b.highlight:SetAllPoints()
  b.glow:ClearAllPoints()
  b.glow:SetAllPoints()
end

local function SetRowSelected(row, selected)
  row.glow:SetShown(selected)
  -- Match Blizzard's recipe list: selection replaces the hover overlay.
  row.highlight:SetShown(not selected and row.kind == "item")
end

framePool = CreateFramePool(
  "Button",
  f,
  nil,
  function(pool, b)
    b.profession = nil
    b.item = nil
    b.currency = nil
    b.kind = nil
    b:Hide()
    b:ClearAllPoints()
    b.leftText:SetText()
    b.middleText:SetText()
    b.rightText:SetText()
    b.icon:SetTexture()
    b.middleText:SetText()
    b.glow:Hide()
    b.highlight:Hide()
    b.highlight:SetAlpha(0.5)
    for _, texture in ipairs(b.headerTextures) do texture:Hide() end
    b.expandHighlight:Hide()
    if not InCombatLockdown() then
      b:SetPropagateMouseClicks(false)
      b:SetPropagateMouseMotion(false)
    end
    b:SetScript("OnClick", nil)
    b:SetScript("OnEvent", nil)

    b:UnregisterAllEvents()
  end,
  false,
  function(b)
    local buttonHeight = MKPT_env.db.ui.rowHeight
    local fontSize = MKPT_env.db.ui.fontSize

    b:SetHeight(buttonHeight)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Category artwork from ProfessionsRecipeListCategoryTemplate. Retain each
    -- end cap's atlas width and stretch the middle across the two-line summary.
    b.headerLeft = b:CreateTexture(nil, "BACKGROUND")
    b.headerLeft:SetAtlas("Professions-recipe-header-left", true)
    b.headerLeft:SetPoint("TOPLEFT")
    b.headerLeft:SetPoint("BOTTOMLEFT")
    b.headerRight = b:CreateTexture(nil, "BACKGROUND")
    b.headerRight:SetAtlas("Professions-recipe-header-right", true)
    b.headerRight:SetPoint("TOPRIGHT")
    b.headerRight:SetPoint("BOTTOMRIGHT")
    b.headerMiddle = b:CreateTexture(nil, "BACKGROUND")
    b.headerMiddle:SetAtlas("Professions-recipe-header-middle", false)
    b.headerMiddle:SetPoint("TOPLEFT", b.headerLeft, "TOPRIGHT")
    b.headerMiddle:SetPoint("BOTTOMRIGHT", b.headerRight, "BOTTOMLEFT")
    b.headerTextures = { b.headerLeft, b.headerMiddle, b.headerRight }
    b.expand = b:CreateTexture(nil, "OVERLAY")
    b.expand:SetSize(12, 12)
    b.expand:SetPoint("TOPRIGHT", -6, -6)
    b.expandHighlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.expandHighlight:SetPoint("CENTER", b.expand, "CENTER")
    b.expandHighlight:SetBlendMode("ADD")
    b:SetScript("OnEnter", function(self)
      if self.item then
        Tooltip(self, self.item:GetFormattedName() or L["Loading..."], self.item:GetDescription())
      elseif self.profession then
        Tooltip(self, self.profession.expansionName or self.profession.name,
          self.kind == "trainer" and L["Click on an item to track"] or L["Click to expand or collapse"])
      elseif self.currency then
        Tooltip(self, self.currency.name)
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if not InCombatLockdown() then
      b:SetPropagateMouseClicks(false)
      b:SetPropagateMouseMotion(false)
    end


    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("LEFT")
    b.icon:SetSize(buttonHeight, buttonHeight)
    b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon:SetAlpha(1)

    b.leftText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.leftText:SetHeight(buttonHeight)
    b.leftText:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.leftText:SetJustifyH("LEFT")
    b.leftText:SetJustifyV("MIDDLE")
    b.leftText:SetFontHeight(fontSize)

    b.middleText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.middleText:SetPoint("LEFT", b.leftText, "RIGHT")
    b.middleText:SetHeight(buttonHeight)
    b.middleText:SetJustifyH("LEFT")
    b.middleText:SetJustifyV("MIDDLE")
    b.middleText:SetFontHeight(fontSize)
    b.middleText:SetTextColor(1, 1, 1)

    b.rightText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.middleText:SetPoint("RIGHT", b.rightText, "LEFT")
    b.rightText:SetHeight(buttonHeight)
    b.rightText:SetPoint("RIGHT", -4, 0)
    b.rightText:SetJustifyH("RIGHT")
    b.rightText:SetJustifyV("MIDDLE")
    b.rightText:SetFontHeight(fontSize)

    b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.highlight:SetAtlas("Professions_Recipe_Hover", false)
    b.highlight:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", buttonHeight, 0)
    b.highlight:SetPoint("BOTTOMRIGHT")
    b.highlight:SetAlpha(0.5)

    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAtlas("Professions_Recipe_Active", false)
    b.glow:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", buttonHeight, 0)
    b.glow:SetPoint("BOTTOMRIGHT")
    b.glow:SetAlpha(1)
    b.glow:Hide()
  end
)

--- Adds a profession row to the list
---@param profession MKPT_Profession
---@return Frame b - rowFrame
local function AddProfessionButton(profession)
  local b = framePool:Acquire()
  PrepareRow(b, "profession")
  b.profession = profession


  local remaining = profession:CalculateRemainingKps()
  b.leftText:SetText(Utils.WeeklyTextColor(L["W:"] .. remaining.weekly) ..
    Utils.CatchUpTextColor(" " .. remaining.catchUp))

  local missing, unspent, isTreeFilled = profession:CalculateTreeKps()
  local unique = Utils.UniqueTextColor(L["U:"] .. remaining.unique)
  local rightText

  if isTreeFilled then
    rightText = Utils.FILLED_TREE_ICON
  elseif unspent > 0 then
    rightText = Utils.UnspentKpsTextColor(unspent)
  else
    rightText = Utils.MissingTextColor(missing)
  end
  b.rightText:SetText(unique .. " " .. rightText)
  local collapseAtlas = profession.expanded and "Professions-recipe-header-collapse" or "Professions-recipe-header-expand"
  b.expand:SetAtlas(collapseAtlas, true)
  b.expandHighlight:SetAtlas(collapseAtlas, true)

  local middleText = profession.name
  local skillLevel = profession:GetSkillLevel()
  if skillLevel then
    middleText = middleText .. " " .. skillLevel.skillLevel .. "/" ..
        skillLevel.maxSkillLevel .. " +" .. skillLevel.bonusSkill
  end

  b.icon:SetTexture(profession.icon)
  b.middleText:SetText(middleText)
  b.middleText:SetJustifyH("LEFT")

  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f); return end
    if self:IsDragging() then return end
    local ui = MKPT_env.ui
    local profession = self.profession
    if not ui or not profession then return end

    profession.expanded = not profession.expanded

    ui:RenderTree()
  end)

  b:Show()
  return b
end

--- Adds a profession trainer row to the list
---@param profession MKPT_Profession
---@return Frame b - rowFrame
local function AddProfessionTrainerButton(profession)
  local b = framePool:Acquire()
  PrepareRow(b, "trainer")
  b.profession = profession


  b.leftText:SetText(CreateAtlasMarkup("Crosshair_trainer_32"), 16, 16)

  b.rightText:SetText(CreateAtlasMarkup("Waypoint-MapPin-Untracked"), 16, 16)

  local middleText = profession.name
  local skillLevel = profession:GetSkillLevel()
  if skillLevel then
    middleText = middleText .. " " .. skillLevel.skillLevel .. "/" ..
        skillLevel.maxSkillLevel .. " +" .. skillLevel.bonusSkill
  end

  b.icon:SetTexture(profession.icon)
  b.middleText:SetText(profession.expansionTrainerName)
  b.middleText:SetJustifyH("LEFT")

  SetRowSelected(b, profession:IsHighlighted())

  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f); return end
    if self:IsDragging() then return end
    local ui = MKPT_env.ui
    local profession = self.profession
    if not ui or not profession then return end

    profession:ToggleTrack()
    if profession:IsHighlighted() then
      ui:UpdateDetail(profession:GetDescription())
    else
      ui:UpdateDetail()
    end

    ui:RenderTree()
  end)

  b:Show()
  return b
end

--- Adds a kp source row to the list
---@param item MKPT_Item
---@return Frame b - rowFrame
local function AddItemButton(item)
  local b = framePool:Acquire()
  PrepareRow(b, "item")


  b.item = item
  SetRowSelected(b, item:IsHighlighted())
  b.icon:SetTexture(item:GetIcon())
  b.leftText:SetText(item:GetCategoryIcon())
  b.leftText:SetJustifyV("MIDDLE")

  local name = item:GetFormattedName()
  if not name then
    -- Listen to ITEM_DATA_LOAD_RESULT event if the name isn't ready and updates the frame
    b:SetScript("OnEvent", function(self, event, ...)
      if event ~= "ITEM_DATA_LOAD_RESULT" or not self.item then return end
      local name = self.item:GetFormattedName()
      if name then
        self.middleText:SetText(name)
        self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
      end
    end)
    b:RegisterEvent("ITEM_DATA_LOAD_RESULT")
  end

  b.middleText:SetText(name or L["Loading..."])
  b.middleText:SetJustifyH("LEFT")
  b.rightText:SetText("+" .. item:GetRemainingKnowledgePoints())

  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f); return end
    if self:IsDragging() then return end
    self.item:ToggleTrack()
    local ui = MKPT_env.ui
    if self.item:IsHighlighted() then
      ui:UpdateDetail(self.item:GetDescription())
    else
      ui:UpdateDetail()
    end
    ui:RenderTree()
  end)

  b:Show()
  return b
end

--- Adds a currency row to the tree
---@param currency MKPT_Currency
---@return Frame b - rowFrame
local function AddCurrencyButton(currency, currency2)
  local b = framePool:Acquire()
  PrepareRow(b, "currency")
  b.currency = currency


  local quantities = currency:GetQuantity()
  local weeklyText = " +" .. math.max(0, quantities.maxWeeklyEarned - quantities.weeklyEarned)
  local currentText = quantities.quantity .. "/" .. quantities.max

  b.icon:SetTexture(currency.icon)
  b.leftText:SetText(Utils.WhiteTextColor(currency.name .. " " .. currentText) .. weeklyText)

  b.middleText:SetText()
  b.middleText:SetJustifyH("LEFT")

  b.rightText:SetText(CreateTextureMarkup(currency2.icon, 64, 64, 16, 16, 0.05, 0.95, 0.05, 0.95) ..
    " " .. currency2:GetQuantity().quantity)
  b.rightText:SetJustifyH("CENTER")

  b.highlight:SetAlpha(0)
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then MKPT_env.ShowRightClickMenu(f) end
  end)

  b:Show()
  return b
end

-- Refresh rows without changing the user's window size or scroll position.
function f:RenderTree()
  if not self.tree then return end
  local trackedItem = MKPT_env.MKPT_Item.GetTrackedItem()
  if trackedItem and not trackedItem:IsAvailable() then
    trackedItem:Untrack()
    trackedItem = nil
  end
  framePool:ReleaseAll()
  local professionsToShow, professionCount = {}, 0
  for _, profession in pairs(MKPT_env.GetProfessions()) do
    professionCount = professionCount + 1
    if not MKPT_env.charDb.config.professionsHideFilledTree or not profession:IsTreeFilled() then
      table.insert(professionsToShow, profession)
    end
  end
  table.sort(professionsToShow, function(a, b)
    if a.name == b.name then return a.id < b.id end
    return (a.name or "") < (b.name or "")
  end)
  local contentHeight = 2
  local function PlaceRow(row, indent)
    row:SetPoint("TOPLEFT", self.tree, "TOPLEFT", indent or 0, -contentHeight)
    row:SetPoint("TOPRIGHT", self.tree, "TOPRIGHT", 0, -contentHeight)
    contentHeight = contentHeight + row:GetHeight() + 2
  end
  for _, profession in ipairs(professionsToShow) do
    if profession:IsLearned() then PlaceRow(AddProfessionButton(profession))
    else PlaceRow(AddProfessionTrainerButton(profession)) end
    for _, item in ipairs(profession:GetAvailableItems()) do
      if item:Show() then PlaceRow(AddItemButton(item), 12) end
    end
    contentHeight = contentHeight + 4
  end
  local dundun = MKPT_env.MKPT_ShardOfDundun
  if dundun:Show() then PlaceRow(AddCurrencyButton(dundun, MKPT_env.MKPT_UnalloyedAbundance)) end
  self.tree:SetHeight(math.max(1, contentHeight))
  if professionCount == 0 then self:UpdateDetail(L["No professions found"])
  elseif #professionsToShow == 0 then self:UpdateDetail(Utils.FILLED_TREE_ICON .. " " .. L["Professions are complete!"])
  elseif trackedItem then self:UpdateDetail(trackedItem:GetDescription())
  else self:UpdateDetail(nil) end
  self.expansionDropdown:GenerateMenu()
  self:UpdateLayout()
end

-- A temporary combat/instance hide must not overwrite the user's open/closed state.
function MKPT_env.UpdateUiVisibility()
  if not f.initialized then return end
  local inInstance = IsInInstance()
  local inDelve = C_PartyInfo.IsDelveInProgress()
  f.temporaryHidden = inInstance or inDelve or (MKPT_env.db.ui.hideInCombat and InCombatLockdown())
  f:SetShown(MKPT_env.charDb.state.show and not f.temporaryHidden)
end

function MKPT_env.ToggleUi()
  MKPT_env.charDb.state.show = not MKPT_env.charDb.state.show
  MKPT_env.UpdateUiVisibility()
  if f:IsShown() then
    f.autoHideTarget = nil
    f:SetAlpha(1)
  end
end

function MKPT_env.ToggleExpansion(expansionEnum)
  if InCombatLockdown() then return end
  if MKPT_env.charDb.state.expansion == expansionEnum then return end
  local trackedItem = MKPT_env.MKPT_Item.GetTrackedItem()
  if trackedItem then trackedItem:Untrack() end
  MKPT_env.charDb.state.expansion = expansionEnum
  -- Preserve the upstream legacy profession scan, only outside combat.
  for _, profession in pairs(MKPT_env.GetProfessions()) do
    if profession:GetSkillLevel() == nil and profession:IsLearned() then
      C_TradeSkillUI.OpenTradeSkill(profession.skillLine)
      C_TradeSkillUI.CloseTradeSkill()
    end
  end
  f.scrollFrame:SetVerticalScroll(0)
  f:RenderTree()
  MKPT_env.charDb.state.show = true
  MKPT_env.UpdateUiVisibility()
end

function MKPT_env.RefreshTrackedItem()
  local trackedItem = MKPT_env.MKPT_Item.GetTrackedItem()
  if trackedItem and trackedItem:IsAvailable() then f:UpdateDetail(trackedItem:GetDescription())
  elseif trackedItem then trackedItem:Untrack(); f:RenderTree() end
end

function MKPT_env.SetUiScale(scale)
  scale = tonumber(scale)
  if not scale or scale ~= scale then return end
  scale = math.max(0.5, math.min(1.5, scale))
  MKPT_env.db.ui.scale = scale
  f:SetScale(scale)
  local maxWidth = math.max(MIN_WIDTH, UIParent:GetWidth() / scale - 24)
  local maxHeight = math.max(MIN_HEIGHT, UIParent:GetHeight() / scale - 24)
  f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight)
  if f.initialized then
    f:SetSize(math.min(f:GetWidth(), maxWidth), math.min(f:GetHeight(), maxHeight))
    f:UpdateLayout()
  end
end

function MKPT_env.SetLockUi(lock)
  StopMoving()
  MKPT_env.db.ui.lockWindow = lock
  f:SetMovable(not lock)
  f:SetResizable(not lock)
  if f.resizeButton then f.resizeButton:SetShown(not lock) end
end

function MKPT_env.ToggleAutoHide()
  MKPT_env.db.ui.autohide = not MKPT_env.db.ui.autohide
  if f.hideButton then f.hideButton:SetChecked(MKPT_env.db.ui.autohide) end
  MKPT_env.RefreshAutoHide()
  Settings.NotifyUpdate("MKPT_Autohide")
end

function MKPT_env.RevealUi()
  if not f:IsShown() then return end
  f.revealUntil = GetTime() + 1
  f.autoHideTarget = 1
  UIFrameFadeIn(f, 0.1, f:GetAlpha(), 1)
end

function MKPT_env.RefreshAutoHide()
  if not f.initialized or not f:IsShown() then return end
  local menuOpen = MKPT_env.IsShowingRightClickMenu() or f.expansionDropdown:IsMenuOpen() or f.filterButton:IsMenuOpen()
  local visible = not MKPT_env.db.ui.autohide or f:IsMouseOver() or menuOpen or f.moving or f.sizing
    or (f.revealUntil and GetTime() < f.revealUntil)
  local target = visible and 1 or 0
  if target == f.autoHideTarget then return end
  f.autoHideTarget = target
  if visible then UIFrameFadeIn(f, 0.1, f:GetAlpha(), 1)
  else UIFrameFadeOut(f, 0.5, f:GetAlpha(), 0) end
end
