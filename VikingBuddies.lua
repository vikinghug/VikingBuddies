-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingBuddies
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"
require "FriendshipLib"
require "math"
require "string"

-----------------------------------------------------------------------------------------------
-- VikingBuddies Module Definition
-----------------------------------------------------------------------------------------------
local VikingBuddies = {}


-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function VikingBuddies:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- indexing to call against the radio buttons
    o.arFriends        = {}
    o.arAccountFriends = {}
    o.arAccountInvites = {}
    o.arInvites        = {}
    o.tUserSettings    = {}
    o.tColors = {
      online  = ApolloColor.new("UI_TextHoloBodyHighlight"),
      offline = ApolloColor.new("UI_BtnTextGrayNormal")
    }

    o.arListTypes =
    {
      o.arFriends
    }


    return o
end

function VikingBuddies:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = {
    -- "UnitOrPackageName",
  }
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- VikingBuddies OnLoad
-----------------------------------------------------------------------------------------------
function VikingBuddies:OnLoad()
    -- load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("VikingBuddies.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function VikingBuddies:OnSave(eType)
  Print("VikingBuddies:OnSave")

  local tSavedData = self.tUserSettings
  tSavedData.nOL, tSavedData.nOT, tSavedData.nOR, tSavedData.nOB = self.wndMain:GetAnchorOffsets()
  tSavedData.bShowList = self.bShowList

  return tSavedData
end

function VikingBuddies:OnRestore(eType, tSavedData)

  if tSavedData ~= nil then
    --self.tUserSettings = tSavedData
    for idx, item in pairs(tSavedData) do
      self.tUserSettings[idx] = item
    end

  end

end

function VikingBuddies:PositionWindow()
  Print("VikingBuddies:PositionWindow")

  if self.tUserSettings.nOL then
    self.wndMain:SetAnchorOffsets(self.tUserSettings.nOL, self.tUserSettings.nOT, self.tUserSettings.nOR, self.tUserSettings.nOB)
  end

end

-----------------------------------------------------------------------------------------------
-- VikingBuddies OnDocLoaded
-----------------------------------------------------------------------------------------------
function VikingBuddies:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
      self.wndOptions       = Apollo.LoadForm(self.xmlDoc, "VikingBuddiesForm", nil, self)
      self.wndMain          = Apollo.LoadForm(self.xmlDoc, "BuddyList", nil, self)

      self.wndListContainer = self.wndMain:FindChild("ListContainer")

    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end


    Print(self.bShowList)
    self.wndMain:Show(true, true)
    self.wndOptions:Show(false, true)

    -- I need to handle this better
    self.bShowList = self.tUserSettings.bShowList
    self.wndListContainer:Show(self.bShowList, true)

    self:PositionWindow()

    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil

    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

    self.timer = ApolloTimer.Create(0.100, true, "OnTimer", self)

    -- Do additional Addon initialization here
  end
end


-----------------------------------------------------------------------------------------------
-- VikingBuddies Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on timer
function VikingBuddies:OnTimer()
  -- Do your timer-related stuff here.
  self:UpdateBuddyList()
end

-- LOCAL STUFF


function VikingBuddies:UpdateBuddyLine(tFriend)

  local wndNew = self.wndListContainer:FindChildByUserData(tFriend)
  Event_FireGenericEvent("SendVarToRover", "tFriend.nId: " .. tFriend.nId, self.wndListContainer)

  -- Check for friend
  if not wndNew then
    wndNew = Apollo.LoadForm(self.xmlDoc, "BuddyLine", self.wndListContainer, self)
  end

  self:UpdateFriendData(wndNew, tFriend)

  return wndNew
end

function VikingBuddies:UpdateFriendData(wndBuddyLine, tFriend)
  Event_FireGenericEvent("SendVarToRover", "wndBuddyLine: " .. tFriend.nId, tFriend)

  local color = self.tColors.offline

  if tFriend.nPresenceState == 0 then
    color = self.tColors.online
  end


  -- Update data
  local wndName = wndBuddyLine:FindChild("Name")
  local wndStatus = wndBuddyLine:FindChild("StatusIcon")

  wndName:SetText(tFriend.strCharacterName)
  wndName:SetTextColor(color)
  wndStatus:SetBGColor(color)

  -- Write the data
  tFriend.wnd = wndNew
  wndBuddyLine:SetData(tFriend)
end

function VikingBuddies:GetFriends()
  local arIgnored = {}
  local arFriends = {}

  for key, tFriend in pairs(FriendshipLib.GetList()) do
    if tFriend.bIgnore == true then
      arIgnored[tFriend.nId] = tFriend
    else
      if tFriend.bFriend == true then
        arFriends[tFriend.nId] = tFriend
      end
    end

  end

  for key, tFriend in pairs(FriendshipLib.GetAccountList()) do
    arFriends[tFriend.nId] = tFriend
  end

  self.arIgnored = arIgnored
  self.arFriends = arFriends

end


-----------------------------------------------------------------------------------------------
-- VikingBuddiesForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function VikingBuddies:OnOK()
  self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function VikingBuddies:OnCancel()
  self.wndMain:Close() -- hide the window
end


---------------------------------------------------------------------------------------------------
-- BuddyList Functions
---------------------------------------------------------------------------------------------------


function VikingBuddies:UpdateBuddyList()

  self.wndListContainer:DestroyChildren()
  self:GetFriends()

  for key, tFriend in pairs(self.arFriends) do
    self:UpdateBuddyLine(tFriend)
    Event_FireGenericEvent("SendVarToRover", "tFriend: " .. tostring(tFriend.strCharacterName), tFriend)
  end


  self.wndListContainer:SetData(self.arFriends)
  self.wndListContainer:ArrangeChildrenVert()

end


function VikingBuddies:ToggleFriendsList( wndHandler, wndControl, eMouseButton )
  self.bShowList = not self.bShowList
  self.wndListContainer:Show(self.bShowList, true)
end

---------------------------------------------------------------------------------------------------
-- BuddyLine Functions
---------------------------------------------------------------------------------------------------

function VikingBuddies:OnGroupButtonClick( wndHandler, wndControl, eMouseButton )
  local data = wndControl:GetParent():GetData()
  GroupLib.Invite(data.strCharacterName)

  Event_FireGenericEvent("SendVarToRover", "button click", data)
end

-----------------------------------------------------------------------------------------------
-- VikingBuddies Instance
-----------------------------------------------------------------------------------------------
local VikingBuddiesInst = VikingBuddies:new()
VikingBuddiesInst:Init()
