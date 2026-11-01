"""Run with Python and lupa installed: python tools/test_appearance_guide.py.

Exercises actual addon files in Lua 5.1 with mocked WoW APIs. This verifies
behavior and layout bounds, not Blizzard artwork or live-client rendering.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
assert '## SavedVariablesPerCharacter: AppearanceGuideEditCharDB' in (
    ROOT / 'addons/AppearanceGuide_Edit/AppearanceGuide_Edit.toc').read_text(encoding='utf-8')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns = {}; complete = {}; active = {}; ready = {}; sources = {}; items = {}
timers = {}; menus = {}; created = {}; SlashCmdList = {}; UISpecialFrames = {}
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:RegisterEvent() end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v end
function methods:IsShown() return self.shown ~= false end
function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints() end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 490 end
function methods:GetHeight() return self.height or 640 end
function methods:SetText(t) self.text = t; if self.fontString then self.fontString.text=t end end
function methods:GetFontString()
 if not self.fontString then self.fontString=make(self); self.fontString.text=self.text end
 return self.fontString
end
function methods:GetStringHeight() return 14 * math.max(1, math.ceil(#(self.text or '') * 7 / (self.width or 400))) end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0,self.child:GetHeight()-self:GetHeight()) end
function methods:UpdateScrollChildRect() end
function methods:SetScrollChild(v) self.child=v end
function methods:GetParent() return self.parent end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetTexture(v) self.texture=v end
for _, key in ipairs({'SetScale','SetClampedToScreen','SetFrameStrata','SetMovable','EnableMouse',
 'RegisterForDrag','StartMoving','StopMovingOrSizing','SetBackdrop','SetBackdropColor','SetTextColor','EnableMouseWheel',
 'SetJustifyH','SetWordWrap','SetFontObject','SetHighlightTexture','SetAutoFocus','HighlightText','ClearFocus',
 'SetNormalFontObject','SetHighlightFontObject'}) do
 methods[key] = function() end
end
function make(parent)
 local obj=setmetatable({parent=parent,scripts={},points={}}, {__index=methods})
 created[#created+1]=obj; return obj
end
function methods:CreateFontString() return make(self) end
function methods:CreateTexture() return make(self) end
function CreateFrame(kind,name,parent,template)
 local f=make(parent)
 f.template=template
 if name then _G[name]=f end
 if template and template:find('PortraitFrameTemplate') then
  f.TitleContainer={TitleText=make(f)}; f.CloseButton=make(f); f.PortraitContainer={portrait=make(f)}
 end
 return f
end
UIParent=make(); UIParent:SetSize(1920,1080)
GameTooltip=make(); function GameTooltip:AddLine() end
C_QuestLog = {
 IsQuestFlaggedCompleted=function(id) return complete[id] or false end,
 IsQuestFlaggedCompletedOnAccount=function() error('Must not substitute account progress') end,
 IsOnQuest=function(id) return active[id] or false end,
 IsComplete=function(id) return ready[id] or false end,
 GetTitleForQuestID=function() return nil end,
 RequestLoadQuestByID=function() end,
 GetNextWaypoint=function() if waypoint then return unpack(waypoint) end end,
 GetQuestObjectives=function() return objectives or {} end,
}
C_TransmogCollection = {
 GetItemInfo=function(id) return id end,
 GetAppearanceSources=function(id) return sources[id] end,
 GetSourceInfo=function(id) return items[id] end,
}
C_Item={GetItemNameByID=function() return nil end, GetItemIconByID=function() return nil end,
 RequestLoadItemDataByID=function() end}
C_Map={GetMapInfo=function() return {name='Test zone'} end, CanSetUserWaypointOnMap=function() return true end,
 SetUserWaypoint=function(p) userPin=p end}
UiMapPoint={CreateFromCoordinates=function(m,x,y) return {m,x,y} end}
C_SuperTrack={SetSuperTrackedUserWaypoint=function() end, SetSuperTrackedQuestID=function(id) tracked=id end}
function OpenWorldMap(id) openedMap=id or 'current' end
function QuestMapFrame_OpenToQuestDetails(id) details=id end
function InCombatLockdown() return combat or false end
function UnitName() return 'Test character' end
function IsModifiedClick() return modified or false end
function tinsert(t,v) table.insert(t,v) end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
ScrollUtil={InitScrollFrameWithScrollBar=function(scroll,bar) scroll.boundBar=bar end}
function hooksecurefunc(obj,key,fn)
 local old=obj[key]; obj[key]=function(...) old(...); fn(...) end
end
Menu={ModifyMenu=function(tag,fn) menus[tag]=fn end}
function rootMenu()
 local r={entries={}}
 function r:CreateDivider() end
 function r:CreateTitle() end
 function r:CreateButton(label,fn)
  local entry=rootMenu(); entry.label=label; entry.click=fn
  function entry:SetEnabled(v) self.enabled=v end
  self.entries[#self.entries+1]=entry; return entry
 end
 return r
end
MenuUtil={CreateContextMenu=function(owner,fn) lastMenu=rootMenu(); fn(owner,lastMenu) end}
''')
for name in ('Guides.lua', 'Core.lua', 'Window.lua', 'Launcher.lua', 'Wardrobe.lua'):
    source = (ROOT / 'addons/AppearanceGuide_Edit' / name).read_text(encoding='utf-8')
    lua.execute('assert(loadstring(...))("AppearanceGuide_Edit", ns)', source)

lua.execute(r'''
local g=ns.guides[208198]
assert(#g.steps==20 and g.steps[1].id==68794)
assert(ns.Progress(g).nextIndex==1)
complete[67074]=true
assert(ns.Progress(g).nextIndex==3 and ns.Progress(g).completedCount==1)
active[75633]=true
local p=ns.Progress(g)
assert(p.nextIndex==18 and p.states[3]=='Passed' and p.states[18]=='In progress')
assert(p.completedCount==1 and p.passedCount==16 and p.total==20)
ready[75633]=true
assert(ns.Progress(g).states[18]=='Ready to turn in')
complete[76171]=true
assert(ns.Progress(g).nextIndex==nil)
complete={}; active={}; ready={}
assert(ns.Progress(g).nextIndex==1) -- switching characters cannot retain previous flags

sources[10]={{sourceID=8},{itemID=208198},{itemID=208198},{itemID=999}}
items[8]={itemID=123}
local resolved=ns.ResolveSources(10)
assert(#resolved==3 and resolved[1].itemID==208198)
assert(#ns.ResolveSources(11)==0)
sources[208198]={{isCollected=true}}
assert(ns.IsCollected(208198))
assert(not ns.IsCollected(111))
sources[208198]={}

local step=g.steps[2]
local m,x,y=ns.Waypoint(step)
assert(m==2112 and x==step.x)
ns.Navigate(step); assert(openedMap==2112 and userPin[1]==2112)
active[step.id]=true; waypoint={2025,.2,.3}
ns.Navigate(step); assert(openedMap==2025 and userPin[2]==.2)
waypoint=nil; userPin=nil
ns.Navigate(step); assert(userPin==nil and tracked==step.id and details==step.id and openedMap=='current')
combat=true; openedMap=nil; ns.Navigate(step); assert(openedMap==nil); combat=false
active={}

-- Optional TomTom: use displayed coordinates and refocus repeated waypoints.
local target={step=step,map=2112,x=.5821,y=.3478,kind='Quest giver'}
ns.SetArrow(target); assert(openedMap==2112) -- no TomTom: native navigation
local pins, arrowCalls = {}, 0
TomTom={profile={arrow={arrival=20}}, AddWaypoint=function(self,m,x,y,opts)
 assert(x>=0 and x<=1 and y>=0 and y<=1)
 assert(opts.persistent==false and opts.crazy==false and opts.from=='AppearanceGuide_Edit')
 local key=opts.title
 pins[key]=pins[key] or {m,x,y,title=key}
 return pins[key]
end, SetCrazyArrow=function(self,uid,distance,title)
 arrowCalls=arrowCalls+1; arrowTarget=uid
 assert(distance==20 and title==uid.title)
end}
active[step.id]=true; waypoint={2025,.1,.2}
ns.SetArrow(target); ns.SetArrow(target)
assert(arrowCalls==2 and arrowTarget[1]==2112 and arrowTarget[2]==.5821)
local count=0; for _ in pairs(pins) do count=count+1 end; assert(count==1)
local add=TomTom.AddWaypoint
TomTom.AddWaypoint=function() return nil end
ns.SetArrow(target); assert(arrowCalls==2)
TomTom.AddWaypoint=add
ns.SetArrow(nil); assert(arrowCalls==2)
TomTom=nil; active={}; waypoint=nil

ns.OpenItem(208198)
assert(ns.window:IsShown() and ns.window.mapButton.enabled)
assert(ns.window.selectedStep.id==68794)
assert(ns.window.coordinateButton:IsShown() and ns.window.coordinateTarget.map==2112)
ns.window.coordinateButton.scripts.OnClick(); assert(openedMap==2112)
assert(ns.window.nextButton.text=='Current quest' and not ns.window.nextButton.enabled)
assert(ns.window.listInset.template=='InsetFrameTemplate' and ns.window.inset.template=='InsetFrameTemplate')
assert(ns.window.listInset.readingBackground.color[4]==1 and ns.window.inset.readingBackground.color[4]==1)
assert(ns.window.listScroll.boundBar and ns.window.scroll.boundBar)
assert(ns.window.listInset:IsShown() and not ns.window.reference:IsShown())
ns.window.helpButton.scripts.OnClick()
assert(ns.window.reference:IsShown())
local originalRow=ns.window.rows[1]
ns.window.rows[18].scripts.OnClick()
assert(ns.window.selectedStep.id==75633 and not ns.window.followNext)
assert(ns.window.nextButton.enabled)
assert(not ns.window.reference:IsShown())
ns.window.nextButton.scripts.OnClick()
assert(ns.window.selectedStep.id==68794 and ns.window.followNext)
assert(not ns.window.nextButton.enabled)
ns.window.rows[1].scripts.OnClick()
assert(ns.window.followNext) -- clicking the current row must keep automatic progress following
active[75633]=true; ns.Refresh()
assert(ns.window.selectedStep.id==75633)
assert(not ns.window.coordinateButton:IsShown() and ns.window.coordinateTarget==nil)
waypoint={2025,.4,.6}; ns.Refresh()
assert(ns.window.coordinateButton:IsShown() and ns.window.coordinateTarget.kind=='Quest objective')
assert(ns.window.coordinateTarget.x==.4 and ns.window.coordinateTarget.y==.6)
waypoint=nil
ns.window.listScroll:SetHeight(184)
complete[67074]=true; ns.window.focusList=true; ns.Refresh()
assert(ns.window.status.text:find('1 / 20 quests completed',1,true))
assert(ns.window.rows[2].state.text=='Completed')
assert(ns.window.rows[2].icon.texture=='Interface\\RaidFrame\\ReadyCheck-Ready')
assert(ns.window.rows[2].icon:IsShown())
assert(ns.window.rows[3].state.text=='Earlier step (inferred)' and not ns.window.rows[3].icon:IsShown())
assert(ns.window.rows[18].state.text=='Current quest')
assert(ns.window.listScroll.scroll>0)
assert(ns.window.rows[18].offset+ns.window.rows[18].height <= ns.window.listScroll.scroll+184)
complete[75633]=true; active[75633]=nil; ns.Refresh()
assert(ns.window.selectedStep.id==75634 and ns.window.rows[18].state.text=='Completed')
complete[76171]=true; ns.Refresh()
assert(not ns.window.nextButton.enabled and ns.window.currentIndex==nil)
complete={}; active={}; ns.OpenItem(208198)
assert(not ns.window.rows[1].icon:IsShown())
assert(ns.window.status.text:find('No progress found',1,true))
assert(ns.window.rows[1]==originalRow)
for i,row in ipairs(ns.window.rows) do
 assert(row.points[1][3] < 0 and row.height>=row.label:GetStringHeight()+25)
 if i>1 then
  local previous=ns.window.rows[i-1]
  assert(-row.points[1][3] >= -previous.points[1][3]+previous.height)
 end
end
ns.OpenItem(999)
assert(not ns.window.mapButton.enabled and ns.window.selectedStep==nil)
assert(not ns.window.coordinateButton:IsShown() and ns.window.coordinateTarget==nil)
assert(not ns.window.nextButton.enabled)
assert(not ns.window.listInset:IsShown() and not ns.window.helpButton:IsShown())
for _,row in ipairs(ns.window.rows) do assert(not row:IsShown()) end
ns.OpenItem(208198)
assert(ns.window.rows[1]:IsShown())

-- Deferred load and recycled wardrobe models: hook once, read live visualInfo.
assert(not ns.wardrobeInstalled)
local wardrobe=make()
function wardrobe:GetTransmogLocation() return {IsIllusion=function() return illusion or false end} end
function wardrobe:UpdateItems() end
local model=make(wardrobe)
function model:GetAppearanceInfo() return self.visualInfo end
function model:GetCollectionFrame() return self.parent end
model.visualInfo={visualID=10,isCollected=false}
wardrobe.Models={model}
WardrobeCollectionFrame={ItemsCollectionFrame=wardrobe}
ns.InstallWardrobe(); ns.InstallWardrobe(); wardrobe:UpdateItems()
assert(ns.wardrobeInstalled)
model.scripts.OnMouseUp(model,'RightButton')
local submenu=lastMenu.entries[1]
assert(submenu.label=='How to obtain' and #submenu.entries==3)
submenu.entries[1].click(); assert(ns.window.itemID==208198)
submenu.entries[2].click(); assert(ns.window.itemID==123)
model.visualInfo={visualID=12,isCollected=false}; sources[12]={{itemID=999}}
model.scripts.OnMouseUp(model,'RightButton')
lastMenu.entries[1].click(); assert(ns.window.itemID==999)
lastMenu=nil; model.scripts.OnMouseUp(model,'LeftButton'); assert(lastMenu==nil)
modified=true; model.scripts.OnMouseUp(model,'RightButton'); assert(lastMenu==nil); modified=false
illusion=true; model.scripts.OnMouseUp(model,'RightButton'); assert(lastMenu==nil); illusion=false
model.visualInfo.isCollected=true
model.scripts.OnMouseUp(model,'RightButton'); assert(lastMenu==nil)
local r=rootMenu(); menus.MENU_WARDROBE_ITEMS_MODEL_FILTER(model,r); assert(#r.entries==1)
local other=make(); function other:GetCollectionFrame() return {} end
r=rootMenu(); ns.AddGuideMenu(other,r); assert(#r.entries==0)

-- Event bursts schedule one refresh; hidden windows do not poll.
ns.refreshQueued=false; timers={}; ns.window:Show()
ns.events.scripts.OnEvent(ns.events,'QUEST_LOG_UPDATE')
ns.events.scripts.OnEvent(ns.events,'QUEST_LOG_UPDATE')
assert(#timers==1); timers[1](); assert(not ns.refreshQueued)
ns.window:Hide(); timers={}
ns.events.scripts.OnEvent(ns.events,'QUEST_LOG_UPDATE'); assert(#timers==0)
''')
lua.execute(r'''
-- Live prerequisite discovery: blockers, chapter expansion, parallel quests,
-- unavailable metadata, active objective navigation, and asynchronous row reuse.
complete={}; active={}; ready={}; waypoint=nil
local base=ns.guides[208198]
local offers, lineQuests, failures, chapterLists = {}, {[10]={100,101,102}, [20]={103,104}},
 {[7]={questID=103,mapID=2025,text='Finish the earlier story.'}}, {[7]={20},[8]={10}}
local mapRequests=0
C_QuestLine={
 RequestQuestLinesForMap=function() mapRequests=mapRequests+1 end,
 GetAvailableQuestLines=function(map) return offers[map] or {} end,
 GetQuestLineInfo=function(id)
  if id>=100 and id<=102 then return {questLineID=10} end
  if id==103 or id==104 then return {questLineID=20} end
 end,
 GetQuestLineQuests=function(id) return lineQuests[id] end,
}
C_CampaignInfo={
 GetCampaignID=function(id) if id==67074 or id==103 or id==104 then return 7 else return 8 end end,
 GetCampaignInfo=function(id) return {name='Campaign '..id} end,
 GetFailureReason=function(id) return failures[id] end,
 GetState=function() return 3 end,
 GetChapterIDs=function(id) return chapterLists[id] end,
 GetCampaignChapterInfo=function(id) return {name='Chapter '..id,rewardQuestID=id==10 and 102 or 104} end,
}
function UnitLevel() return 80 end
local function indexOf(route,id)
 for i,s in ipairs(route.steps) do if s.id==id then return i end end
 error('Missing quest '..id)
end
ns.OpenItem(208198)
assert(mapRequests==#base.scanMaps)
assert(ns.window.showPrerequisites and ns.window.selectedStep.id==103)
assert(ns.window.prerequisiteButton.text=='Back to reward chain')
assert(not ns.window.coordinateButton:IsShown())
local route=ns.PrerequisiteGuide(base)
assert(#route.steps==6 and route.blockerID==103)
assert(route.steps[indexOf(route,101)].live)
complete[100]=true; active[102]=true
local p=ns.Progress(route)
assert(p.states[indexOf(route,100)]=='Complete')
assert(p.states[indexOf(route,101)]=='Later') -- parallel tasks not falsely passed
assert(p.completedCount==1 and p.passedCount==0)
assert(route.steps[p.nextIndex].id==103) -- explicit blocker wins over other campaign work

-- Offers must match the quest, cannot be hidden, and use the query-map coordinates.
offers[2025]={{questID=103, x=.3, y=.4,startMapID=999}, {questID=101,x=.1,y=.2,isHidden=true}}
ns.Refresh()
assert(ns.window.coordinateTarget.map==2025 and ns.window.coordinateTarget.x==.3)
assert(ns.window.coordinateTarget.kind=='Quest start (live)')
assert(ns.AvailableQuest(101,base.scanMaps)==nil)
ns.window.coordinateButton.scripts.OnClick(); assert(userPin[1]==2025 and userPin[2]==.3)
active[103]=true; waypoint={2025,.6,.7}; ns.Refresh()
assert(ns.window.coordinateTarget.kind=='Quest objective' and ns.window.coordinateTarget.x==.6)
waypoint=nil; ns.Refresh(); assert(not ns.window.coordinateButton:IsShown())

-- Late chapter data must preserve the selected quest and scroll content bounds.
local idx=indexOf(route,101)
ns.window.rows[idx].scripts.OnClick()
assert(ns.window.selectedStep.id==101)
lineQuests[20]={99,103,104}
ns.Refresh()
assert(ns.window.selectedStep.id==101 and ns.window.selectedIndex~=idx)
complete[103]=true; active[103]=nil; ns.Refresh()
assert(ns.window.selectedStep.id==101) -- inspecting another step stays put
ns.window.nextButton.scripts.OnClick()
assert(ns.window.selectedStep.id==102) -- actual active campaign quest

-- A visible reward-chain quest or actual progress bypasses campaign redirection.
active={}; complete={}; offers[2112]={{questID=67074,x=.58,y=.34}}
ns.OpenItem(208198); assert(not ns.window.showPrerequisites)
offers={}; active[67074]=true
ns.OpenItem(208198); assert(not ns.window.showPrerequisites and ns.window.selectedStep.id==67074)
active={}; complete[67074]=true
ns.OpenItem(208198); assert(not ns.window.showPrerequisites)

-- Cyclic blocker metadata and absent chapter lists terminate without inventing completion.
complete={}; failures[8]={questID=100,mapID=2025,text='Earlier prerequisite'}
C_CampaignInfo.GetCampaignID=function(id) return (id==103 or id==100 or id==66221) and 8 or 7 end
route=ns.PrerequisiteGuide(base)
assert(route.blockerID==100 and route.steps[ns.Progress(route).nextIndex].id==100)
complete[100]=true
assert(ns.PrerequisiteGuide(base).blockerID==103) -- return up the prerequisite chain
complete={}; failures[8]={questID=104,mapID=2025,text='Other chapter'}
C_CampaignInfo.GetCampaignID=function(id) return (id==103 or id==66221) and 8 or 7 end
route=ns.PrerequisiteGuide(base)
assert(#route.steps==7)
chapterLists={}; lineQuests={}
route=ns.PrerequisiteGuide(base)
assert(route.incompleteData and #route.steps>=1)
for _,state in ipairs(ns.Progress(route).states) do assert(state~='Complete' and state~='Passed') end

-- Missing APIs still offer the real introduction; historical Renown is not a hard gate.
C_CampaignInfo=nil; C_QuestLine=nil; ns.offers=nil; ns.offerMaps=nil
route=ns.PrerequisiteGuide(base)
assert(route.incompleteData and #route.steps==1 and route.steps[1].id==68794)
function UnitLevel() return 20 end
assert(ns.Readiness(base,base.steps[1]):find('Requires level 36',1,true))
function UnitLevel() return 80 end
assert(ns.Readiness(base,base.steps[1]):find('not confirmed',1,true))
ns.OpenItem(208198)
ns.window.prerequisiteButton.scripts.OnClick()
assert(ns.window.showPrerequisites)
ns.window.prerequisiteButton.scripts.OnClick()
assert(not ns.window.showPrerequisites and ns.window.selectedStep.id==68794)
ns.OpenItem(999)
assert(not ns.window.prerequisiteButton:IsShown() and ns.window.coordinateTarget==nil)
''')
lua.execute(r'''
-- Explicit active item: browsing never silently changes the saved goal.
AppearanceGuideEditDB={activeItemID=208198,minimapAngle=135,keepThis='existing setting'}
AppearanceGuideEditCharDB=nil
SlashCmdList.APPEARANCEGUIDEEDIT('999')
assert(ns.window.itemID==999 and ns.ActiveItemID()==208198)
assert(ns.window.trackButton.enabled and ns.window.activeButton:IsShown())
assert(ns.window.inset.points[1][3]==-142) -- unknown-item content below tracking controls
ns.window.trackButton.scripts.OnClick()
assert(ns.ActiveItemID()==999 and ns.window.trackButton.text=='Active item')
assert(not ns.window.trackButton.enabled and not ns.window.activeButton:IsShown())
ns.OpenItem(208198)
assert(ns.ActiveItemID()==999)
ns.window.activeButton.scripts.OnClick()
assert(ns.window.itemID==999)
ns.window:Hide(); SlashCmdList.APPEARANCEGUIDEEDIT('  ')
assert(ns.window:IsShown() and ns.window.itemID==999)
SlashCmdList.APPEARANCEGUIDEEDIT('track 208198')
assert(ns.ActiveItemID()==208198 and ns.window.itemID==208198)
SlashCmdList.APPEARANCEGUIDEEDIT('|cffffffff|Hitem:123:0:0|h[Test item]|h|r')
assert(ns.window.itemID==123 and ns.ActiveItemID()==208198)
SlashCmdList.APPEARANCEGUIDEEDIT('track')
assert(ns.ActiveItemID()==123)
SlashCmdList.APPEARANCEGUIDEEDIT('track |Hitem:208198:0|h[Shield]|h')
assert(ns.ActiveItemID()==208198)
for _,id in ipairs({0,-1,1.5,math.huge,'invalid'}) do assert(not ns.SetActiveItem(id)) end
assert(ns.ActiveItemID()==208198)
assert(AppearanceGuideEditDB.keepThis=='existing setting')
assert(ns.window.trackButton.points[1][3]==-108 and ns.window.listInset.points[1][3]==-142)
function UnitLevel() return 81 end
assert(ns.PrerequisiteGuide(ns.guides[208198]).notices[1]:find("You're level 81.",1,true))

-- The minimap is a distinct launcher, created once after SavedVariables load.
local methods=getmetatable(UIParent).__index
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetFrameLevel(v) self.frameLevel=v end
function methods:SetToplevel() end
function methods:RegisterForClicks() end
function methods:LockHighlight() self.locked=true end
function methods:UnlockHighlight() self.locked=false end
function methods:GetCenter() return 100,200 end
function methods:GetEffectiveScale() return mapScale end
function methods:SetOwner(owner) self.owner=owner end
function methods:GetOwner() return self.owner end
Minimap=make(); Minimap:SetSize(300,240); mapScale=.75
local shape='ROUND'
function GetMinimapShape() return shape end
function GetCursorPosition() return 300*mapScale,400*mapScale end
ns.minimapButton=nil
ns.events.scripts.OnEvent(ns.events,'ADDON_LOADED','AnotherAddon')
assert(ns.minimapButton==nil)
ns.events.scripts.OnEvent(ns.events,'ADDON_LOADED','AppearanceGuide_Edit')
local b=ns.minimapButton
assert(b and b.parent==Minimap and b.width==31)
ns.events.scripts.OnEvent(ns.events,'PLAYER_LOGIN')
assert(ns.minimapButton==b)
local function near(a,b) assert(math.abs(a-b)<.0001) end
near(b.points[1][4],math.cos(math.rad(135))*153)
near(b.points[1][5],math.sin(math.rad(135))*123)
b.scripts.OnDragStart(b); b.scripts.OnUpdate(b,.016)
near(AppearanceGuideEditDB.minimapAngle,45)
near(b.points[1][4],math.cos(math.rad(45))*153)
mapScale=1.7; b.scripts.OnUpdate(b,.016)
near(AppearanceGuideEditDB.minimapAngle,45) -- scaled map uses the same cursor-space conversion
b.scripts.OnDragStop(b); assert(not b.dragging and not b.locked)
shape='SQUARE'; b.scripts.OnUpdate(b,1)
near(b.points[1][4],153); near(b.points[1][5],123)
Minimap:SetSize(400,200); Minimap.scripts.OnSizeChanged()
near(b.points[1][4],203); near(b.points[1][5],103)
shape='unrecognized'; ns.PositionLauncher()
near(b.points[1][4],math.cos(math.rad(45))*203)
ns.OpenItem(999); b.scripts.OnClick(b,'LeftButton')
assert(ns.window.itemID==208198 and ns.window:IsShown())
b.scripts.OnClick(b,'LeftButton'); assert(ns.window:IsShown()) -- opens rather than hiding it
ns.SetActiveItem(123); ns.OpenItem(208198)
b.scripts.OnClick(b,'LeftButton'); assert(ns.window.itemID==123)
local oldIcon=C_Item.GetItemIconByID
C_Item.GetItemIconByID=function(id) return id==123 and 987654 end
ns.events.scripts.OnEvent(ns.events,'GET_ITEM_INFO_RECEIVED')
assert(b.icon.texture==987654)
b.scripts.OnEnter(b); assert(GameTooltip:GetOwner()==b and GameTooltip:IsShown())
b.scripts.OnDragStart(b); b.scripts.OnHide(b)
assert(not b.dragging and not GameTooltip:IsShown())
C_Item.GetItemIconByID=oldIcon
AppearanceGuideEditDB.minimapAngle='broken'; ns.PositionLauncher()
assert(AppearanceGuideEditDB.minimapAngle==135)
AppearanceGuideEditCharDB.activeItemID='broken'; assert(ns.ActiveItemID()==208198)
ns.SetActiveItem(123); AppearanceGuideEditDB.minimapAngle=287
''')
# Reload the actual module with an already populated saved table. Existing data
# must survive module evaluation and the addon's load/login event sequence.
lua.execute('assert(loadstring(...))("AppearanceGuide_Edit", ns)',
            (ROOT / 'addons/AppearanceGuide_Edit/Core.lua').read_text(encoding='utf-8'))
lua.execute(r'''
ns.events.scripts.OnEvent(ns.events,'ADDON_LOADED','AppearanceGuide_Edit')
assert(ns.ActiveItemID()==123 and AppearanceGuideEditDB.minimapAngle==287)
assert(AppearanceGuideEditDB.keepThis=='existing setting')
SlashCmdList.APPEARANCEGUIDEEDIT(''); assert(ns.window.itemID==123)

-- The old shared target is imported once; alts keep independent saved tables.
AppearanceGuideEditDB={activeItemID=456,minimapAngle=287,keepThis='existing setting'}
AppearanceGuideEditCharDB=nil
ns.events.scripts.OnEvent(ns.events,'ADDON_LOADED','AppearanceGuide_Edit')
assert(ns.ActiveItemID()==456 and AppearanceGuideEditDB.activeItemID==nil)
local characterA=AppearanceGuideEditCharDB
ns.SetActiveItem(123)
AppearanceGuideEditCharDB=nil -- a different character's SavedVariables file
ns.events.scripts.OnEvent(ns.events,'PLAYER_LOGIN')
assert(ns.ActiveItemID()==208198) -- not copied from the first character
local characterB=AppearanceGuideEditCharDB
ns.SetActiveItem(789)
assert(characterA.activeItemID==123 and characterB.activeItemID==789)
AppearanceGuideEditCharDB=characterA
SlashCmdList.APPEARANCEGUIDEEDIT(''); assert(ns.window.itemID==123)
AppearanceGuideEditCharDB=characterB
ns.minimapButton.scripts.OnClick(ns.minimapButton,'LeftButton')
assert(ns.window.itemID==789)
assert(AppearanceGuideEditDB.minimapAngle==287 and AppearanceGuideEditDB.keepThis=='existing setting')
AppearanceGuideEditDB.activeItemID=456
ns.CharacterSettings()
assert(characterB.activeItemID==789 and AppearanceGuideEditDB.activeItemID==nil) -- existing target wins
''')
print('PASS: Lua 5.1, quest/prerequisite progress, saved active item, scaled minimap launcher, UI reuse, navigation, and events')
