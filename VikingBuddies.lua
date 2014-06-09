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
    o.arFriends         = {}
    o.arAccountFriends  = {}
    o.arAccountInvites  = {}
    o.arInvites         = {}
    o.tUserSettings     = {}
    o.tExpandedOffsets  = {}
    o.tMinimumSize     = {
      width = 200,
      height = 120
    }
    o.tCollapsedSize   = {
      nOL = 0,
      nOT = 0,
      nOR = 64,
      nOB = 34
    }

    o.cColorOffline = ApolloColor.new("UI_BtnTextGrayNormal")

    o.tStatusColors = {
      [FriendshipLib.AccountPresenceState_Available] = ApolloColor.new("ChatCircle2"),
      [FriendshipLib.AccountPresenceState_Away]      = ApolloColor.new("yellow"),
      [FriendshipLib.AccountPresenceState_Busy]      = ApolloColor.new("red"),
      [FriendshipLib.AccountPresenceState_Invisible] = ApolloColor.new("gray")
    }
    o.tTextColors = {
      [FriendshipLib.AccountPresenceState_Available] = ApolloColor.new("UI_TextHoloBodyHighlight"),
      [FriendshipLib.AccountPresenceState_Away]      = ApolloColor.new("gray"),
      [FriendshipLib.AccountPresenceState_Busy]      = ApolloColor.new("gray"),
      [FriendshipLib.AccountPresenceState_Invisible] = ApolloColor.new("gray")

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
  if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return nil
  end

  local tCurrentOffsets = self:GetCurrentOffsets(self.wndMain)

  if self.bShowList then
    self.tExpandedOffsets = tCurrentOffsets
  end

  local tSavedData = {
    tCurrentOffsets = tCurrentOffsets,
    tExpandedOffsets = self.tExpandedOffsets,
    bShowList = self.bShowList
  }

  return tSavedData
end

function VikingBuddies:OnRestore(eType, tSavedData)

  if tSavedData ~= nil then
    -- self.tUserSettings = tSavedData
    for idx, item in pairs(tSavedData) do
      self.tUserSettings[idx] = item
    end

  end

end


-----------------------------------------------------------------------------------------------
-- VikingBuddies OnDocLoaded
-----------------------------------------------------------------------------------------------
function VikingBuddies:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
      self.wndOptions       = Apollo.LoadForm(self.xmlDoc, "VikingBuddiesForm", nil, self)
      self.wndMain          = Apollo.LoadForm(self.xmlDoc, "BuddyList", nil, self)

      self.wndListWindow    = self.wndMain:FindChild("ListWindow")
      self.wndListContainer = self.wndMain:FindChild("ListContainer")

    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end

    self.wndMain:Show(true, true)
    self.wndOptions:Show(false, true)

    -- Event_FireGenericEvent("SendVarToRover", "wndMain", self.wndMain)
    Apollo.RegisterSlashCommand("vb", "OnVikingBuddiesOn", self)

    -- I need to handle this better
    self.bShowList = self.tUserSettings.bShowList
    self.wndListWindow:Show(self.bShowList, true)
    self.wndMain:SetSizingMinimum(self.tMinimumSize.width, self.tMinimumSize.height)


    -- Restore the checkbutton state
    self.wndMain:FindChild("Button"):SetCheck(self.bShowList)

    -- self:PositionWindow()
    -- Event_FireGenericEvent("SendVarToRover", "self.tUserSettings", self.tUserSettings)
    self:ResizeFriendsList(self.bShowList, true)

    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil

    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

    self.timer = ApolloTimer.Create(0.100, true, "OnRenderLoop", self)

    -- Do additional Addon initialization here
  end
end

function VikingBuddies:OnVikingBuddiesOn()
  self.wndMain:SetAnchorOffsets(200, 200, 600, 600)
end

-----------------------------------------------------------------------------------------------
-- VikingBuddies Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on timer
function VikingBuddies:OnRenderLoop()

  -- Don't bother rendering the list if it's not being displayed
  if self.bShowList then
    self:UpdateBuddyList()
  end

  -- Get Number of online buddies
  self:UpdateBuddiesOnline()

end

-- LOCAL STUFF

function VikingBuddies:GetLineByFriendId(nId)
  for key, wndPlayerEntry in pairs(self.wndListContainer:GetChildren()) do
    if wndPlayerEntry:GetData().nId == nId then
      return wndPlayerEntry
    end
  end

  return nil
end

function VikingBuddies:UpdateBuddyLine(tFriend)
  local wndParent = self.wndListContainer
  local wndNew = self:GetLineByFriendId(tFriend.nId)

  -- Check for friend
  if not wndNew then
    wndNew = Apollo.LoadForm(self.xmlDoc, "BuddyLine", self.wndListContainer, self)
    wndNew:SetData(tFriend)
  end

  wndParent:SetData(oData)
  self:UpdateFriendData(wndNew, tFriend)

  return wndNew
end

function VikingBuddies:UpdateFriendData(wndBuddyLine, tFriend)
  -- Event_FireGenericEvent("SendVarToRover", "wndBuddyLine: " .. tFriend.nId, tFriend)

  local colorText = self.tTextColors.offline
  local colorStatus = self.tStatusColors.offline

  if tFriend.fLastOnline == 0 then
    colorText = self.tTextColors[tFriend.nPresenceState]
    colorStatus = self.tStatusColors[tFriend.nPresenceState]
  else
    colorText = self.cColorOffline
    colorStatus = self.cColorOffline
  end



  -- Update data
  local wndName = wndBuddyLine:FindChild("Name")
  local wndStatus = wndBuddyLine:FindChild("StatusIcon")

  wndName:SetText(tFriend.strCharacterName)
  wndName:SetTextColor(colorText)
  wndStatus:SetBGColor(colorStatus)

  -- Write the data
  -- tFriend.wnd = wndBuddyLine
  -- self.arFriends[tFriend.nId] = tFriend
  -- Event_FireGenericEvent("SendVarToRover", "::UpdateFriendData: " .. tFriend.nId, tFriend)

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
    -- Event_FireGenericEvent("SendVarToRover", "tFriend.nId: " .. tFriend.nId, self.arFriends[tFriend.nId])
    -- arFriends[tFriend.nId].wnd = self.arFriends[tFriend.nId].wnd
  end

  self.arIgnored = arIgnored
  self.arFriends = arFriends

  return arFriends

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
  local arFriends = self:GetFriends()
  -- self.wndListContainer:DestroyChildren()
  self.wndListContainer:SetData(arFriends)

  for key, tFriend in pairs(self.arFriends) do
    self:UpdateBuddyLine(tFriend)
    -- Event_FireGenericEvent("SendVarToRover", "tFriend: " .. tostring(tFriend.strCharacterName), tFriend)
  end


  -- Sort the buddy list by "online"
  self.wndListContainer:ArrangeChildrenVert(0, function(wndLeft, wndRight)

    local friendLeft = wndLeft:GetData()
    local friendRight = wndRight:GetData()

    local state = friendLeft.nPresenceState or -1

    return state >= 0

  end)
end

function VikingBuddies:UpdateBuddiesOnline()
  -- tFriend.nPresenceState
  -- for i = 0, #self.arFriends do
  local nOnline = 0
  for key, tFriend in pairs(FriendshipLib.GetList()) do
    if tFriend.fLastOnline == 0 then
      nOnline = nOnline + 1
    end
  end

  -- local btnButton = wndBuddiesOnline:FindChild("Button")
  local txtBuddiesOnline = self.wndMain:FindChild("BuddiesOnline")
  txtBuddiesOnline:SetText(nOnline)

end

function VikingBuddies:ResizeFriendsList(bExpand, bSetup)
  -- Print("VikingBuddies:ResizeFriendsList()")

  -- local bSetup = b or false

  -- Print("bSetup: " .. tostring(bSetup))

  local tCurrentOffsets = {}
  local tNewOffsets = {}

  if bSetup then
    tCurrentOffsets = self.tUserSettings.tCurrentOffsets
    self.tExpandedOffsets = self.tUserSettings.tExpandedOffsets
    -- Event_FireGenericEvent("SendVarToRover", "self.tUserSettings", self.tUserSettings)
  else
    tCurrentOffsets.nOL, tCurrentOffsets.nOT, tCurrentOffsets.nOR, tCurrentOffsets.nOB = self.wndMain:GetAnchorOffsets()
  end

  -- Print(" - # tCurrentOffsets")
  -- Print(" - nOL: " .. tCurrentOffsets.nOL )
  -- Print(" - nOT: " .. tCurrentOffsets.nOT )
  -- Print(" - nOR: " .. tCurrentOffsets.nOR .." (" .. tCurrentOffsets.nOR - tCurrentOffsets.nOL .. ")")
  -- Print(" - nOB: " .. tCurrentOffsets.nOB .." (" .. tCurrentOffsets.nOB - tCurrentOffsets.nOT .. ")")

  if bExpand then
    -- Print(" - Expand")

    if self.tExpandedOffsets.nOL then
      -- Print(" - existing expanded data")
      self.tExpandedOffsets = {
        nOL = tCurrentOffsets.nOL,
        nOT = tCurrentOffsets.nOT,
        nOR = self.tExpandedOffsets.nOR + (tCurrentOffsets.nOL - self.tExpandedOffsets.nOL),
        nOB = self.tExpandedOffsets.nOB + (tCurrentOffsets.nOT - self.tExpandedOffsets.nOT)
      }
      -- Print(" - nOL: " .. self.tExpandedOffsets.nOL )
      -- Print(" - nOT: " .. self.tExpandedOffsets.nOT )
      -- Print(" - nOR: " .. self.tExpandedOffsets.nOR .." (" .. self.tExpandedOffsets.nOR - self.tExpandedOffsets.nOL .. ")")
      -- Print(" - nOB: " .. self.tExpandedOffsets.nOB .." (" .. self.tExpandedOffsets.nOB - self.tExpandedOffsets.nOT .. ")")
    else
      -- Print(" - creating new expanded data")
      self.tExpandedOffsets = {
        nOL = tCurrentOffsets.nOL,
        nOT = tCurrentOffsets.nOT,
        nOR = tCurrentOffsets.nOR + self.tMinimumSize.width,
        nOB = tCurrentOffsets.nOB + self.tMinimumSize.height
      }
    end

    tNewOffsets = self.tExpandedOffsets


  else
    -- Print(" - Collapse")
    -- Print(" - # tCurrentOffsets")
    -- Print(" - nOL: " .. tCurrentOffsets.nOL )
    -- Print(" - nOT: " .. tCurrentOffsets.nOT )
    -- Print(" - nOR: " .. tCurrentOffsets.nOR .." (" .. tCurrentOffsets.nOR - tCurrentOffsets.nOL .. ")")
    -- Print(" - nOB: " .. tCurrentOffsets.nOB .." (" .. tCurrentOffsets.nOB - tCurrentOffsets.nOT .. ")")
    if not bSetup then
      self.tExpandedOffsets = tCurrentOffsets
    end

    tNewOffsets =  {
      nOL = tCurrentOffsets.nOL,
      nOT = tCurrentOffsets.nOT,
      nOR = tCurrentOffsets.nOL + self.tCollapsedSize.nOR,
      nOB = tCurrentOffsets.nOT + self.tCollapsedSize.nOB
    }
    -- Print(" - # tNewOffsets")
    -- Print(" - nOL: " .. tNewOffsets.nOL )
    -- Print(" - nOT: " .. tNewOffsets.nOT )
    -- Print(" - nOR: " .. tNewOffsets.nOR .." (" .. tNewOffsets.nOR - tNewOffsets.nOL .. ")")
    -- Print(" - nOB: " .. tNewOffsets.nOB .." (" .. tNewOffsets.nOB - tNewOffsets.nOT .. ")")

  end

  self.wndMain:SetStyle("Sizable", bExpand)
  self.wndMain:SetAnchorOffsets(tNewOffsets.nOL, tNewOffsets.nOT, tNewOffsets.nOR, tNewOffsets.nOB)

end

function VikingBuddies:ShowFriendsList(bShow)
  self.wndListWindow:Show(bShow, true)
  self:ResizeFriendsList(bShow)

  -- store the display state
  self.bShowList = bShow
end

function VikingBuddies:OnListCheck( wndHandler, wndControl, eMouseButton )
  self:ShowFriendsList(true)
end

function VikingBuddies:OnListUncheck( wndHandler, wndControl, eMouseButton )
  self:ShowFriendsList(false)
end

function VikingBuddies:GetCurrentOffsets(wnd)
  local tCurrentOffsets = {}
  tCurrentOffsets.nOL, tCurrentOffsets.nOT, tCurrentOffsets.nOR, tCurrentOffsets.nOB = wnd:GetAnchorOffsets()
  return tCurrentOffsets
end
---------------------------------------------------------------------------------------------------
-- BuddyLine Functions
---------------------------------------------------------------------------------------------------

function VikingBuddies:OnGroupButtonClick( wndHandler, wndControl, eMouseButton )
  local data = wndControl:GetParent():GetData()
  GroupLib.Invite(data.strCharacterName)

  -- Event_FireGenericEvent("SendVarToRover", "button click", data)
end

-----------------------------------------------------------------------------------------------
-- VikingBuddies Instance
-----------------------------------------------------------------------------------------------
local VikingBuddiesInst = VikingBuddies:new()
VikingBuddiesInst:Init()
