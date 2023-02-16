--[[
 * ReaScript Name: move edit cursor to next or prev visible grid (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-02-15)
   + Initial Release
--]]

-- adapted from amagalma

local int = 0
_, _, _, _, mode, resolution, val = reaper.get_action_context()

if mode == 0 and val == 129 then val = 1 
elseif mode == 0 and val == 16383 then val = -1 end   -- adjust midi-generated values

reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
local cursorpos = reaper.GetCursorPosition()
local grid_duration
if reaper.GetToggleCommandState( 41885 ) == 1 then -- Toggle framerate grid
  grid_duration = 0.4/reaper.TimeMap_curFrameRate( 0 )
else

local _, division = reaper.GetSetProjectGrid( 0, 0, 0, 0, 0 )
local tmsgn_cnt = reaper.CountTempoTimeSigMarkers( 0 )
local _, tempo
if tmsgn_cnt == 0 then
  tempo = reaper.Master_GetTempo()
else
  local active_tmsgn = reaper.FindTempoTimeSigMarker( 0, cursorpos )
  _, _, _, _, tempo = reaper.GetTempoTimeSigMarker( 0, active_tmsgn )
end
  grid_duration = 60/tempo * division
end
   
local grid = cursorpos

if val > 0 then 
  while (grid <= cursorpos) do
    cursorpos = cursorpos + grid_duration
    grid = reaper.SnapToGrid(0, cursorpos)
  end
elseif val < 0 then
  while (grid >= cursorpos) do
    cursorpos = cursorpos - grid_duration
    grid = reaper.SnapToGrid(0, cursorpos)
  end
end

reaper.SetEditCurPos(grid,1,1)
reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
reaper.defer(function() end)

