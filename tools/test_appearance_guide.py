"""Run with Python and lupa installed: python tools/test_appearance_guide.py.

Exercises actual addon files in Lua 5.1 with mocked WoW APIs. This verifies
behavior and layout bounds, not Blizzard artwork or live-client rendering.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
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
for name in ('Guides.lua', 'Core.lua', 'Window.lua', 'Wardrobe.lua'):
    source = (ROOT / 'addons/AppearanceGuide_Edit' / name).read_text(encoding='utf-8')
    lua.execute('assert(loadstring(...))("AppearanceGuide_Edit", ns)', source)

lua.execute(r'''
local g=ns.guides[208198]
assert(#g.steps==19)
assert(ns.Progress(g).nextIndex==1)
complete[67074]=true
assert(ns.Progress(g).nextIndex==2 and ns.Progress(g).completedCount==1)
active[75633]=true
local p=ns.Progress(g)
assert(p.nextIndex==17 and p.states[2]=='Passed' and p.states[17]=='In progress')
assert(p.completedCount==1 and p.passedCount==15 and p.total==19)
ready[75633]=true
assert(ns.Progress(g).states[17]=='Ready to turn in')
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

local step=g.steps[1]
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
assert(ns.window.selectedStep.id==67074)
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
ns.window.rows[17].scripts.OnClick()
assert(ns.window.selectedStep.id==75633 and not ns.window.followNext)
assert(ns.window.nextButton.enabled)
assert(not ns.window.reference:IsShown())
ns.window.nextButton.scripts.OnClick()
assert(ns.window.selectedStep.id==67074 and ns.window.followNext)
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
assert(ns.window.status.text:find('1 / 19 quests completed',1,true))
assert(ns.window.rows[1].state.text=='Completed')
assert(ns.window.rows[1].icon.texture=='Interface\\RaidFrame\\ReadyCheck-Ready')
assert(ns.window.rows[1].icon:IsShown())
assert(ns.window.rows[2].state.text=='Earlier step (inferred)' and not ns.window.rows[2].icon:IsShown())
assert(ns.window.rows[17].state.text=='Current quest')
assert(ns.window.listScroll.scroll>0)
assert(ns.window.rows[17].offset+ns.window.rows[17].height <= ns.window.listScroll.scroll+184)
complete[75633]=true; active[75633]=nil; ns.Refresh()
assert(ns.window.selectedStep.id==75634 and ns.window.rows[17].state.text=='Completed')
complete[76171]=true; ns.Refresh()
assert(not ns.window.nextButton.enabled and ns.window.currentIndex==nil)
complete={}; active={}; ns.OpenItem(208198)
assert(not ns.window.rows[1].icon.texture:find('ReadyCheck%-Ready'))
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
print('PASS: Lua 5.1 load, quest progress, skips, sources, navigation, window reuse, wardrobe menus, and event refresh')
