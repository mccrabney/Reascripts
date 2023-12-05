--[[
 * ReaScript Name: target instances of last hit note (or note under cursor) in razor edits
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1
  + if no razor edit exists, create one out of selected item
 * v1.0
  + 
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

---------------------------------------------------------------------
    --[[------------------------------[[--
          adjust incr
    --]]------------------------------]]--
reaper.ClearConsole()

function main()
  --reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  reI, _, _, track, _ = ultraschall.RazorEdit_GetFromPoint(reaper.GetMousePosition())
  num, RazorEditTable = ultraschall.RazorEdit_GetAllRazorEdits(true, false)
  
  if reI == -1 and num ~= 0 then 
    val = ultraschall.RazorEdit_Remove(RazorEditTable[1]["Track"])
    --track, _ = reaper.GetThingFromPoint(reaper.GetMousePosition())
  end
  
  reaper.Main_OnCommand(40528, 0) -- select item under mouse
  item = reaper.GetSelectedMediaItem(0, 0)
  take = reaper.GetActiveTake( item )
  reaper.MIDI_SelectAll( take, 0 )
  
  if track ~= nil then reaper.SetOnlyTrackSelected(track)end
  
  RazorEditSelectionExists(1, 1)
  reaper.SetExtState(extName, 'toggleNoteHold', 1, false)
  --reaper.DeleteExtState(extName, 6, false) 
end
 
main()

function RazorEditSelectionExists(make,itemType)    ---itemType: 0 for audio, 1 for MIDI
  reaper.Undo_BeginBlock2(0)          -- make them from selected items.
  local midiFlag = 0
  local itemUnderMouse
  local itemCount = reaper.CountSelectedMediaItems(0)  -- how many items are selected

  if itemCount == 0 then                               -- if none,
    _, _, itemUnderMouse, _ = getMouseInfo()           -- get item under mouse
    if itemUnderMouse ~= nil then 
      reaper.SetMediaItemSelected( itemUnderMouse, true )  -- set it selected
      itemCount = 1
    end                                        -- update item count
  end
  
  for i=0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end            -- if present, return true
  end                                          -- end for each track
    
  if x == nil and make == 1 and itemCount ~= 0 then  -- if no RE, but one is needed,
    --if itemUnderMouse ~= nil then
      tS = {}
    for i = 0, itemCount -1 do               -- for each selected item
      item = reaper.GetSelectedMediaItem(0, i)      -- get its dimensions
      take = reaper.GetActiveTake(item)
      if reaper.TakeIsMIDI(take) then midiFlag = 1 end
      left = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      right = left + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      track = reaper.GetMediaItemTrack(item)
      tS[track] = (tS[track] or "") .. string.format([[%.16f %.16f "" ]], left, right)
    end
  
    for track, str in pairs(tS) do
      if itemType == 1 and midiFlag == 1 then          -- if MIDI and MIDI is present
        reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str, true)
      end
      if itemType == 0 and midiFlag == 0 then          -- if audio and MIDI is not present
        reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str, true)
      end
      if itemType == 0 and midiFlag == 1 then return false end     -- if audio and MIDI is present
      if itemType == 1 and midiFlag == 0 then return false end     -- if MIDI and MIDI not present
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, "Enclose items in minimal razor areas", -1)
    return true                    -- return that yes, RE exists now
  
    else if x == nil and make == 0 then
      return false 
    end                  -- return that no RE exists
  end                               -- end if/else
end                                 -- end RazorEditSelectionExists()

