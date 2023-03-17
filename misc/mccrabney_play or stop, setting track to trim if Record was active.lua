--[[
 * ReaScript Name: play or stop, setting track to trim if Record was active
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * v1.1 (2023-03-17)
   + nil fix
 * v1.0 (2023-02-15)
   + Initial Release
--]]

local automationMode 
local selTrack = reaper.GetSelectedTrack(0,0);

if selTrack ~= nil then 
  automationMode = reaper.GetMediaTrackInfo_Value(selTrack, "I_AUTOMODE ")
end

local transportMode = reaper.GetPlayState()

function Main()
 
  if selTrack == nil then
    if transportMode == 5 then                                    -- if transport is recording
    --  reaper.Undo_BeginBlock() 
      reaper.Main_OnCommand(1016, 0)                              -- stop
    elseif transportMode == 1 then                                -- if REAPER is playing,
      --reaper.Main_OnCommand(1008, 0)                            -- pause
      reaper.Main_OnCommand(1016, 0)                              -- stop
    elseif transportMode == 0 then                                -- if REAPER is stopped,
      reaper.Main_OnCommand(1007, 0)                              -- play
    elseif transportMode == 2 then                                -- if REAPER is paused,
      reaper.Main_OnCommand(1007, 0)                              -- play
    end
  end
  if selTrack ~= nil then
    if transportMode == 5 then                                    -- if transport is recording
    --  reaper.Undo_BeginBlock() 
      reaper.SetMediaTrackInfo_Value(selTrack, "I_AUTOMODE", 0)   -- set selected track to Trim
      reaper.Main_OnCommand(1016, 0)                              -- stop
    elseif transportMode == 1 then                                -- if REAPER is playing,
      --reaper.Main_OnCommand(1008, 0)                            -- pause
      reaper.Main_OnCommand(1016, 0)                              -- stop
      reaper.SetMediaTrackInfo_Value(selTrack, "I_AUTOMODE", 0)   -- set selected track to Trim
    elseif transportMode == 0 then                                -- if REAPER is stopped,
      reaper.Main_OnCommand(1007, 0)                              -- play
    elseif transportMode == 2 then                                -- if REAPER is paused,
      reaper.Main_OnCommand(1007, 0)                              -- play
    end
  end
  
  reaper.UpdateArrange()
end

reaper.defer(Main)
