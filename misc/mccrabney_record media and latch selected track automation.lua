--[[
 * ReaScript Name: record media and latch selected track automation
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * v1.0 (2023-02-15)
   + Initial Release
--]]

local selTrack = reaper.GetSelectedTrack(0,0);
local automationMode = reaper.GetMediaTrackInfo_Value(selTrack, "I_AUTOMODE ")
local transportMode = reaper.GetPlayState()

function Main()
  if transportMode ~= 5 then                                      -- if transport is not recording
    if automationMode == 0 then                                   -- if track is Trim,
      reaper.SetMediaTrackInfo_Value(selTrack, "I_AUTOMODE", 4)   -- set selected track to Latch
      reaper.Main_OnCommand(1013, 0)                              -- record
    else 
      reaper.Main_OnCommand(1013, 0)                              -- record
    end
  else                                                            -- if REAPER is recording,
    reaper.Main_OnCommand(1016, 0)                                -- stop
    reaper.SetMediaTrackInfo_Value(selTrack, "I_AUTOMODE", 0)     -- set track back to Trim
  end    
end

reaper.defer(Main) 
