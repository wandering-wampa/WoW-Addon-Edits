-- Simulate frame lifecycle, pooling, menus and events with explicit API stubs.
-- Font metrics are approximate; Blizzard's renderer still needs an in-game check.
local frames, pools = {}, {}
local Frame = {}
Frame.__index = Frame
local function newFrame(parent)
  local f = setmetatable({parent=parent, scripts={}, points={}, events={}, shown=true,
    width=0, height=0, scale=1, alpha=1, frameLevel=1}, Frame)
  table.insert(frames, f)
  return f
end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback)
  local previous = self.scripts[name]
  self.scripts[name] = function(...)
    if previous then previous(...) end
    callback(...)
  end
end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:SetPoint(...) table.insert(self.points, {...}) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetAllPoints() self.allPoints = true end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetParent() return self.parent end
function Frame:SetSize(w, h)
  local changed = self.width ~= w or self.height ~= h
  self.width, self.height = w, h
  if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
end
function Frame:SetWidth(w) self:SetSize(w, self.height) end
function Frame:SetHeight(h) self:SetSize(self.width, h) end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return self.scale end
function Frame:GetLeft() return 100 end
function Frame:GetTop() return 700 end
function Frame:SetFrameLevel(level) self.frameLevel = level end
function Frame:GetFrameLevel() return self.frameLevel end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha end
function Frame:Show()
  if self.shown then return end
  self.shown = true
  if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
  if not self.shown then return end
  self.shown = false
  if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:SetText(text) self.textValue = text and tostring(text) or "" end
function Frame:GetText() return self.textValue end
function Frame:SetFontHeight(size) self.fontSize = size end
function Frame:SetTextColor(...) self.textColor = {...} end
function Frame:GetStringHeight()
  return math.ceil(math.max(1, #(self.textValue or "")) / math.max(1, self.width / 7)) * (self.fontSize or 13)
end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:SetAtlas(atlas) self.atlas = atlas end
function Frame:SetVertexColor(...) self.vertexColor = {...} end
function Frame:SetBackdropColor(...) self.backdropColor = {...} end
function Frame:SetChecked(checked) self.checked = checked end
function Frame:SetEnabled(enabled) self.enabled = enabled end
function Frame:CreateTexture() return newFrame(self) end
function Frame:CreateFontString() return newFrame(self) end
function Frame:SetNormalTexture(texture) self.normalTexture = texture end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.verticalScroll = value end
function Frame:GetVerticalScroll() return self.verticalScroll or 0 end
function Frame:GetVerticalScrollRange()
  return self.testRange or math.max(0, (self.scrollChild and self.scrollChild:GetHeight() or 0) - self:GetHeight())
end
function Frame:SetResizeBounds(...) self.resizeBounds = {...} end
function Frame:SetMovable(value) self.movable = value end
function Frame:SetResizable(value) self.resizable = value end
function Frame:IsDragging() return false end
function Frame:StartMoving() self.didMove = true end
function Frame:StartSizing() self.didSize = true end
function Frame:StopMovingOrSizing() self.stopped = true end
function Frame:IsMouseOver() return self.mouseOver or false end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsMenuOpen() return self.menuOpen or false end
function Frame:CloseMenu() self.menuOpen = false end
function Frame:SetDefaultText(text)
  assert(self.template == "WowStyle1DropdownTemplate", "SetDefaultText requires DropdownSelectionTextMixin; filter templates only have SetText")
  self.defaultText = text
end
function Frame:OverrideText(text)
  assert(self.template == "WowStyle1DropdownTemplate", "OverrideText requires DropdownSelectionTextMixin; filter templates only have SetText")
  self.overrideText = text
end
for _, method in ipairs({"SetFrameStrata", "SetToplevel", "SetClampedToScreen", "EnableMouse", "EnableMouseWheel", "SetBackdrop",
  "SetJustifyH", "SetJustifyV", "SetWordWrap", "RegisterForDrag", "RegisterForClicks",
  "SetTexCoord", "SetColorTexture", "SetHighlightTexture", "SetPushedTexture", "SetPropagateMouseClicks", "SetBlendMode",
  "SetPropagateMouseMotion", "SetOwner", "AddLine"}) do
  Frame[method] = function() end
end
-- Model the native adapter's contract: wheel/arrow/thumb inputs drive the
-- ScrollFrame, and range changes update the thumb without losing the clamp hook.
ScrollUtil = {InitScrollFrameWithScrollBar=function(scroll, bar)
  function scroll:SetPanExtent(value) self.panExtent = value end
  function bar:SetScrollPercentage(value)
    self.percentage = math.max(0, math.min(1, value))
    scroll:SetVerticalScroll(self.percentage * scroll:GetVerticalScrollRange())
  end
  function bar:ScrollStepInDirection(direction)
    local range = scroll:GetVerticalScrollRange()
    if range > 0 then self:SetScrollPercentage((scroll:GetVerticalScroll() + direction * scroll.panExtent) / range) end
  end
  scroll:SetScript("OnMouseWheel", function(_, value) bar:ScrollStepInDirection(-value) end)
  scroll:SetScript("OnScrollRangeChanged", function(self, _, range)
    self.nativeScrollRange = range
    bar.visibleExtent = self:GetHeight() / (range + self:GetHeight())
  end)
end}
function CreateFrame(kind, name, parent, template)
  local f = newFrame(parent)
  f.template, f.name = template, name
  if name then _G[name] = f end
  if template and template:find("PortraitFrameTemplate") then
    f.TitleContainer = newFrame(f)
    f.TitleContainer.TitleText = newFrame(f.TitleContainer)
    f.PortraitContainer = {portrait=newFrame(f)}
    f.CloseButton = newFrame(f)
  elseif template == "UIPanelScrollFrameTemplate" then
    f.scripts.OnScrollRangeChanged = function(self, _, range) self.nativeScrollRange = range end
  elseif template == "InsetFrameTemplate" then f.Bg = newFrame(f) end
  return f
end
function CreateFramePool(kind, parent, template, reset, _, init)
  local pool = {active={}, free={}}
  function pool:Acquire()
    local row = table.remove(self.free)
    if not row then row = CreateFrame(kind, nil, parent, template); init(row) end
    table.insert(self.active, row)
    return row
  end
  function pool:ReleaseAll()
    for _, row in ipairs(self.active) do reset(self, row); table.insert(self.free, row) end
    self.active = {}
  end
  table.insert(pools, pool)
  return pool
end
local function menuRoot()
  local root = {entries={}}
  local function add(self, kind, text, selected, callback, data)
    local entry = {kind=kind, text=text, selected=selected, callback=callback, data=data, enabled=true}
    function entry:SetEnabled(value) self.enabled = value end
    table.insert(self.entries, entry)
    return entry
  end
  function root:CreateRadio(...) return add(self, "radio", ...) end
  function root:CreateCheckbox(...) return add(self, "checkbox", ...) end
  function root:CreateTitle(text) return add(self, "title", text) end
  function root:CreateDivider() return add(self, "divider") end
  function root:CreateButton(text, callback) return add(self, "button", text, nil, callback) end
  return root
end
function Frame:SetupMenu(generator) self.menuGenerator=generator; self:GenerateMenu() end
function Frame:GenerateMenu()
  self.menu = menuRoot()
  self.menuGenerator(self, self.menu)
end
MenuUtil = {CreateContextMenu=function(owner, generator)
  local menu = newFrame(owner)
  menu.root = menuRoot()
  generator(owner, menu.root)
  _G.lastContextMenu = menu
  return menu
end}
UIParent = newFrame()
UIParent:SetSize(1600, 900)
UISpecialFrames, SlashCmdList = {}, {}
GameTooltip = newFrame()
local combat, instance, delve, now = false, false, false, 0
local controlDown = false
function IsControlKeyDown() return controlDown end
function InCombatLockdown() return combat end
function IsInInstance() return instance end
C_PartyInfo = {IsDelveInProgress=function() return delve end}
C_TradeSkillUI = {OpenTradeSkill=function() end, CloseTradeSkill=function() end}
function GetTime() return now end
function ButtonFrameTemplate_HidePortrait(f)
  f.portraitShown = false
  f.border = "ButtonFrameTemplateNoPortrait"
end
function UIFrameFadeIn(f, duration, from, target) f:SetAlpha(target) end
function UIFrameFadeOut(f, duration, from, target) f:SetAlpha(target) end
function CreateAtlasMarkup(name) return "["..name.."]" end
function CreateTextureMarkup(name) return "[texture]" end
function WrapTextInColorCode(text, color) return "|c"..color..tostring(text).."|r" end
function strsplit(separator, text) return text:match("^(%S+)%s*(.*)$") end
date, time, difftime = os.date, os.time, os.difftime
Enum = {ExpansionLevel={Dragonflight=9, WarWithin=10, Midnight=11}}
function GetExpansionLevel() return 11 end
EXPANSION_NAME9, EXPANSION_NAME10, EXPANSION_NAME11 = "Dragonflight", "The War Within", "Midnight"
EXPANSION_FILTER_TEXT, FILTER = "Expansion", "Filter"
Settings = {NotifyUpdate=function() end, OpenToCategory=function() end}
local function category()
  return {GetID=function() return 1 end}, {AddInitializer=function() end}
end
Settings.RegisterVerticalLayoutCategory = category
Settings.RegisterVerticalLayoutSubcategory = category
Settings.RegisterProxySetting = function(_, name, _, _, _, getter, setter)
  Settings[name] = {get=getter, set=setter}
  return Settings[name]
end
Settings.CreateSliderOptions = function() return {SetLabelFormatter=function() end} end
for _, method in ipairs({"CreateCheckbox", "CreateSlider", "CreateColorSwatch", "RegisterAddOnCategory"}) do
  Settings[method] = function() end
end
function CreateSettingsListSectionHeaderInitializer() end
function CreateSettingsButtonInitializer() end
MinimalSliderWithSteppersMixin = {Label={Right=1}}
local minimapBroker, minimapRegistration
local savedDatabase, defaultVisibility
function LibStub(name)
  if name == "AceDB-3.0" then return {New=function(_, _, defaults)
    defaultVisibility = defaults.char.state.show
    savedDatabase = savedDatabase or defaults
    return savedDatabase
  end} end
  if name == "AceAddon-3.0" then return {NewAddon=function() return {} end} end
  if name == "LibDataBroker-1.1" then
    return {NewDataObject=function(_, _, broker) minimapBroker = broker; return broker end}
  end
  if name == "LibDBIcon-1.0" then
    return {Register=function(_, name, broker) minimapRegistration = {name=name, broker=broker} end,
      Show=function() end, Hide=function() end}
  end
  error("Unexpected library: "..name)
end
local env = {}
local function load(name) assert(loadfile(ADDON_DIR.."/"..name))(ADDON_NAME, env) end
load("locales/Core.lua")
load("MKPT_Config.lua")
env.InitializeSavedVariables()
load("Utils.lua")
load("MKPT_Ui.lua")
load("MKPT_RightClickMenu.lua")
load("MKPT_SlashCommand.lua")
load("MKPT_Options.lua")
load("MKPT_MinimapIcon.lua")
env.InitializeOptionsMenu()
env.InitializeSlashCommand()
env.InitializeMinimapIcon()
local professions = {}
env.GetProfessions = function() return professions end
env.MKPT_Item = {GetTrackedItem=function() return env.trackedItem end}
local currencyShown = false
env.MKPT_ShardOfDundun = {name="Shard of Dundun", icon=1,
  Show=function() return currencyShown end,
  GetQuantity=function() return {quantity=100, max=200, maxWeeklyEarned=20, weeklyEarned=30} end}
env.MKPT_UnalloyedAbundance = {icon=2, GetQuantity=function() return {quantity=500} end}
local function profession(id, name, learned)
  local p = {id=id, name=name, icon=1, expansionName=name, expansionTrainerName="Learn "..name,
    expanded=false, entries={}, learned=learned}
  function p:IsLearned() return self.learned end
  function p:IsTreeFilled() return self.filled or false end
  function p:CalculateRemainingKps() return {weekly=5, catchUp=9, unique=60} end
  function p:CalculateTreeKps() return 200, 2, self.filled end
  function p:GetSkillLevel() return {skillLevel=100, maxSkillLevel=100, bonusSkill=6} end
  function p:GetAvailableItems() return self.entries end
  function p:IsHighlighted() return env.trackedItem == self end
  function p:IsAvailable() return not self.learned end
  function p:GetDescription() return "Trainer location" end
  function p:Untrack() env.trackedItem = nil end
  function p:ToggleTrack() env.trackedItem = env.trackedItem ~= self and self or nil end
  return p
end
local function item(p, name)
  local i = {name=name, available=true}
  function i:Show() return p.expanded and self.available end
  function i:GetFormattedName() return self.name end
  function i:GetName() return self.name end
  function i:MeetRequirements() return not self.locked end
  function i:GetIcon() return 1 end
  function i:GetCategoryIcon() return "[W]" end
  function i:GetRemainingKnowledgePoints() return 2 end
  function i:GetDescription() return string.rep("Requirements and location. ", 100) end
  function i:IsHighlighted() return env.trackedItem == self end
  function i:IsAvailable() return self.available end
  function i:Untrack() env.trackedItem = nil end
  function i:ToggleTrack() env.trackedItem = env.trackedItem ~= self and self or nil end
  table.insert(p.entries, i)
  return i
end
local checks = 0
local function check(condition, description)
  assert(condition, description)
  checks = checks + 1
end
local function findRow(kind, target)
  for _, row in ipairs(pools[1].active) do
    if row.kind == kind and (not target or row.item == target or row.profession == target) then return row end
  end
  error("Missing row: "..kind)
end
local function click(row, button) row.scripts.OnClick(row, button or "LeftButton") end
local ui = env.CreateUI()
env.UpdateUiVisibility()
check(not defaultVisibility and not ui:IsShown() and not env.charDb.state.show, "New install defaults to a closed window")
check(ui.detailValue == "No professions found", "Empty state")
check(ui.backdropColor[4] == 1 and UISpecialFrames[1] == "MKPT_Frame", "Opaque panel and Escape registration")
check(env.CreateUI() == ui and #UISpecialFrames == 1, "Initialization is idempotent")
check(ui.filterButton.template == "WowStyle1FilterDropdownTemplate" and ui.filterButton:GetText() == "Filter",
  "Filter uses the fixed-text API, so initialization reaches completion")
check(minimapRegistration.name == ADDON_NAME and minimapRegistration.broker == minimapBroker,
  "Actual minimap broker is registered for the installed addon name")
minimapBroker.OnClick(nil, "LeftButton")
check(ui:IsShown() and env.charDb.state.show, "First minimap click opens the initially closed window")
minimapBroker.OnClick(nil, "LeftButton")
check(not ui:IsShown() and not env.charDb.state.show, "Minimap click closes initialized window")
minimapBroker.OnClick(nil, "LeftButton")
check(ui:IsShown() and env.charDb.state.show, "Minimap click reopens window")
minimapBroker.OnClick(nil, "RightButton")
check(env.IsShowingRightClickMenu(), "Minimap right click opens native menu")
lastContextMenu:Hide()
controlDown = true
minimapBroker.OnClick(nil, "LeftButton")
check(env.db.ui.autohide and env.charDb.state.show, "Minimap Ctrl-click changes autohide without closing window")
minimapBroker.OnClick(nil, "LeftButton")
controlDown = false
check(ui.listInset.Background.atlas == "Professions-background-summarylist" and not ui.listInset.Bg:IsShown(),
  "Recipe background does not inherit the tiled marble texture")
check(ui.scrollFrame.ScrollBar.template == "MinimalScrollBar" and ui.detailScroll.ScrollBar.template == "MinimalScrollBar",
  "Both panes use Retail slim scrollbars")
local a, z = profession(2, "Alchemy", true), profession(1, "Tailoring", true)
professions = {[1]=z, [2]=a}
local pending = item(a, nil)
for n=1,60 do item(a, "Knowledge source "..n) end
ui:RenderTree()
check(#pools[1].active == 2 and pools[1].active[1].profession == a, "Collapsed rows sorted by name")
check(findRow("profession", a).parent == ui.tree, "Rows are owned by scroll child")
check(findRow("profession", a).headerLeft:IsShown() and not findRow("profession", a).highlight:IsShown(),
  "Profession categories retain their header treatment without a recipe hover strip")
local header = findRow("profession", a)
check(header.headerArea:GetHeight() == 25 and #header.headerLeft.points == 1 and #header.headerRight.points == 1,
  "Category end caps keep native height instead of stretching across the summary")
check(header.middleText:GetText() == "Alchemy" and header.rightText:GetText() == "100/100 +6" and
  header.leftText:GetText():find("Weekly:", 1, true) and header.summaryStatus:GetText():find("Unspent:", 1, true),
  "Profession, skill and labeled knowledge totals occupy separate fields")
check(header.middleText.textColor[2] == 0.82 and ui:GetHeight() == 240,
  "Collapsed list uses gold headings and a compact window")
click(findRow("profession", a))
check(a.expanded and #pools[1].active == 63 and ui.tree:GetHeight() > ui:GetHeight(), "Expanded list can scroll")
check(ui:GetHeight() == 560, "Automatic height is bounded for long lists")
local row = findRow("item", pending)
check(not row.headerLeft:IsShown() and row.highlight:IsShown(), "Source entries remain distinct from category headers")
check(row.middleText:GetText() == "Loading..." and row.events.ITEM_DATA_LOAD_RESULT, "Uncached item placeholder")
row.scripts.OnEvent(row, "UNRELATED_EVENT")
check(row.events.ITEM_DATA_LOAD_RESULT, "Unrelated event ignored")
pending.name = "Loaded item"
row.scripts.OnEvent(row, "ITEM_DATA_LOAD_RESULT")
check(row.middleText:GetText() == pending.name and not row.events.ITEM_DATA_LOAD_RESULT, "Item load refresh")
pending.GetFormattedName = function() return "|cffff0000Colored tooltip|r" end
pending.locked = true
ui:RenderTree()
check(findRow("item", pending).middleText:GetText() == pending.name and findRow("item", pending).middleText.textColor[1] == 0.5,
  "Locked source uses a plain dimmed label; formatted tooltip remains independent")
pending.locked = false
ui:RenderTree()
check(findRow("item", pending).middleText.textColor[1] == 1 and findRow("item", pending).rightText.textColor[1] == 1,
  "Recycled available entries restore white labels and counts")
ui.scrollFrame:SetVerticalScroll(100)
ui:RenderTree()
check(ui.scrollFrame:GetVerticalScroll() == 100, "Refresh preserves scroll position")
ui.scrollFrame:SetHeight(280) -- explicit viewport, since this mock has no anchor solver
ui.scrollFrame.testRange = 10
ui.scrollFrame.scripts.OnScrollRangeChanged(ui.scrollFrame, 0, 10)
check(ui.scrollFrame:GetVerticalScroll() == 10 and ui.scrollFrame.nativeScrollRange == 10,
  "Shrinking list clamps scroll and preserves the native adapter's thumb update")
ui.scrollFrame.testRange = 400
ui.scrollFrame.scripts.OnScrollRangeChanged(ui.scrollFrame, 0, 400)
ui.scrollFrame.ScrollBar:SetScrollPercentage(0.5)
check(ui.scrollFrame:GetVerticalScroll() == 200 and ui.scrollFrame.ScrollBar:IsShown(), "Slim scrollbar thumb controls list position")
ui.scrollFrame.scripts.OnMouseWheel(ui.scrollFrame, -1)
check(ui.scrollFrame:GetVerticalScroll() == 242, "Mouse wheel uses the native scrollbar adapter")
ui.scrollFrame.testRange = 0
ui.scrollFrame.scripts.OnScrollRangeChanged(ui.scrollFrame, 0, 0)
check(ui.scrollFrame:GetVerticalScroll() == 0 and not ui.scrollFrame.ScrollBar:IsShown(), "Short list hides scrollbar and resets scroll")
ui.scrollFrame.testRange = nil
click(findRow("item", pending))
check(env.trackedItem == pending and ui.detailInset:GetHeight() == 120, "Tracking opens bounded details")
check(findRow("item", pending).glow:IsShown() and not findRow("item", pending).highlight:IsShown(),
  "Tracked source replaces the hover overlay rather than stacking both")
check(ui.detailContent:GetHeight() > ui.detailInset:GetHeight(), "Long details remain scrollable")
local oldHeight = ui:GetHeight()
ui:SetWidth(720)
check(ui.tree:GetWidth() == 666 and ui.detailText:GetWidth() == 666 and ui:GetHeight() == oldHeight,
  "Resize updates list and wrapped description without changing height")
click(findRow("item", pending), "RightButton")
check(env.trackedItem == pending and env.IsShowingRightClickMenu(), "Right click opens menu without changing track")
lastContextMenu:Hide()
pending.available = false
ui:RenderTree()
check(env.trackedItem == nil and not ui.detailInset:IsShown(), "Completed tracked source clears details")
currencyShown = true
ui:RenderTree()
check(findRow("currency").leftText:GetText():find("%+0$"), "Currency weekly remaining does not go negative")
currencyShown = false
a.expanded = false
ui:RenderTree()
for _, pooled in ipairs(pools[1].active) do
  check(pooled.currency == nil and not pooled.events.ITEM_DATA_LOAD_RESULT, "Recycled rows clear old data/events")
end
check(findRow("profession", a).headerLeft:IsShown() and not findRow("profession", a).glow:IsShown(),
  "Recycled source rows restore category decoration without stale selection")
check(findRow("profession", a).middleText.textColor[2] == 0.82 and ui:GetHeight() == 240,
  "Collapsing restores gold categories and removes unused window height")
local trainer = profession(3, "Enchanting", false)
professions = {trainer}
ui:RenderTree()
click(findRow("trainer", trainer))
check(env.trackedItem == trainer and ui.detailValue == "Trainer location", "Trainer tracking and details")
env.ToggleExpansion(10)
check(env.charDb.state.expansion == 10 and env.trackedItem == nil and ui.scrollFrame:GetVerticalScroll() == 0,
  "Expansion switch clears previous tracking and scroll")
combat = true
env.ToggleExpansion(9)
ui.expansionDropdown:GenerateMenu()
check(env.charDb.state.expansion == 10 and not ui.expansionDropdown.menu.entries[1].enabled, "Combat blocks profession scans")
combat = false
professions = {a, z}
a.filled, z.filled = true, true
env.charDb.config.professionsHideFilledTree = true
ui:RenderTree()
check(#pools[1].active == 0 and ui.detailValue:find("Professions are complete!", 1, true), "Completed professions state")
env.charDb.config.professionsHideFilledTree = false
ui.filterButton:GenerateMenu()
local filter = ui.filterButton.menu.entries[1]
filter.callback(filter.data)
check(env.db.config.hideUniqueTreasures and not filter.selected(filter.data), "Native filter updates saved setting")
env.SetLockUi(true)
ui.dragHandle.scripts.OnDragStart()
ui.resizeButton.scripts.OnMouseDown(nil, "LeftButton")
check(not ui.didMove and not ui.didSize and not ui.resizeButton:IsShown(), "Lock blocks drag and resize")
env.SetLockUi(false)
ui.dragHandle.scripts.OnDragStart()
ui.dragHandle.scripts.OnDragStop()
check(ui.didMove and env.db.position.x == 100, "Title drag saves position")
ui.resizeButton.scripts.OnMouseDown(nil, "LeftButton")
ui:SetSize(680, 500)
ui.resizeButton.scripts.OnMouseUp()
check(env.db.ui.windowSize.width == 680 and env.db.ui.windowSize.height == 500, "Resize persists dimensions")
ui:RenderTree()
check(not env.db.ui.autoHeight and ui:GetHeight() == 500, "Manual resize disables automatic height across refreshes")
env.FitUiHeight()
check(env.db.ui.autoHeight and ui:GetHeight() < 500, "Fit action restores automatic height")
env.SetUiScale("bad input")
check(env.db.ui.scale == 1, "Invalid scale is safe")
env.SetUiScale(2)
check(env.db.ui.scale == 1.5, "Scale clamped")
env.ToggleAutoHide()
env.RefreshAutoHide()
check(ui:GetAlpha() == 0, "Autohide fades away")
ui.filterButton.menuOpen = true
env.RefreshAutoHide()
check(ui:GetAlpha() == 1, "Autohide stays visible while menu is open")
ui.filterButton.menuOpen = false
ui.mouseOver = true
env.RefreshAutoHide()
check(ui:GetAlpha() == 1, "Autohide stays visible over window")
ui.mouseOver = false
env.RevealUi()
env.RefreshAutoHide()
check(ui:GetAlpha() == 1, "Minimap hover reveals window")
now = 2
env.RefreshAutoHide()
check(ui:GetAlpha() == 0, "Reveal timeout returns to autohide")
Settings.MKPT_Autohide.set(false)
Settings.MKPT_Autohide.set(false)
check(not env.db.ui.autohide and ui:GetAlpha() == 1, "Settings assignment is idempotent")
ui.scripts.OnHide(ui) -- parent hidden, as with Alt-Z, while own shown flag stays true
check(env.charDb.state.show, "Parent visibility does not change preference")
ui:Hide() -- Escape
check(not env.charDb.state.show, "Escape persists closed state")
SlashCmdList.MKPT("show")
check(ui:IsShown() and env.charDb.state.show, "Slash show restores window after Escape")
click(ui.closeButton)
check(not ui:IsShown() and not env.charDb.state.show, "Close button persists closed state")
env.ToggleUi()
env.db.ui.hideInCombat = true
combat = true
env.UpdateUiVisibility()
check(not ui:IsShown() and env.charDb.state.show, "Combat hide preserves open preference")
instance = true
combat = false
env.UpdateUiVisibility()
check(not ui:IsShown() and env.charDb.state.show, "Combat exit inside instance stays hidden")
instance = false
env.UpdateUiVisibility()
check(ui:IsShown(), "Leaving instance restores desired visibility")
delve = true
env.UpdateUiVisibility()
delve = false
env.UpdateUiVisibility()
check(ui:IsShown(), "Delve transition restores visibility")
combat = true
env.UpdateUiVisibility()
SlashCmdList.MKPT("hide")
combat = false
env.UpdateUiVisibility()
check(not ui:IsShown() and not env.charDb.state.show, "Explicit hide during combat remains closed afterward")
-- Reinitialization models loading the same character's saved state on login or
-- /reload. Saved visibility must not cause an unsolicited popup after upgrading.
minimapBroker.OnClick(nil, "LeftButton")
local savedUi, savedConfig, savedCharacterConfig = env.db.ui, env.db.config, env.charDb.config
local savedExpansion = env.charDb.state.expansion
check(ui:IsShown() and savedDatabase.char.state.show, "Existing character can leave an open state in saved data")
env.InitializeSavedVariables()
env.UpdateUiVisibility()
check(not ui:IsShown() and not env.charDb.state.show, "Login or reload clears an older saved open state")
check(env.db.ui == savedUi and env.db.config == savedConfig and env.charDb.config == savedCharacterConfig and
  env.charDb.state.expansion == savedExpansion, "Startup visibility reset preserves unrelated settings")
env.RevealUi()
env.RefreshAutoHide()
check(not ui:IsShown(), "Minimap hover does not open a closed window")
SlashCmdList.MKPT("show")
check(ui:IsShown(), "Explicit slash show still opens the window after startup reset")
SlashCmdList.MKPT("hide")
env.InitializeSavedVariables()
env.UpdateUiVisibility()
check(not ui:IsShown() and not env.charDb.state.show, "Existing closed state remains closed on login or reload")
print("PASS: "..checks.." UI behavior checks (headless Lua 5.1)")
