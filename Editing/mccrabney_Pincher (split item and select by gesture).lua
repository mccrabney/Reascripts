--[[
 * ReaScript Name: Pincher (split item and select by gesture)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Version: 1.01
--]]
 
--[[
 * Changelog:

 * v1.01 (05-27-2026)
   + do not enable snap if snap was off at init
   + 1 pixel padding for movement threshold
 * v1.00 (~mid 2026)
   + IR
--]]


reaper.set_action_options(1)

local loopCount = 0
local firstX = -1                           -- n/a first mouse x pos value
  
function Loop()
  loopCount = loopCount+1                  
  local x, y = reaper.GetMousePosition()    -- update mousepos
  if loopCount == 1 then firstX = x end     -- get mouse x pos at init
  
  if lastX and math.abs(x-firstX) > 1 then  -- if mouse has moved more than 1 pixel since init,
    reaper.Main_OnCommand(40528,0)          -- select item under mouse cursor,
    return                                  -- quit the script
  else   
    lastX = x                               -- update last mouse x position,
    reaper.defer(Loop)                      -- repeat and wait for movement threshold
  end
end

function Main()
  local snap = reaper.GetToggleCommandState(1157)   -- check snap toggle state
  local x, y = reaper.GetMousePosition()            -- get mousepos
  local _, info = reaper.GetThingFromPoint(x, y)    -- get mousedetails
  
  if info == "arrange" then                   -- if we're in Arrange,
    reaper.Main_OnCommand(40753,0)            -- disable snap,
    reaper.Main_OnCommand(42575,0)            -- split at mouse cursor w/out changing selection,
    if snap == 1 then                         -- if snap was on when the script started,
      reaper.Main_OnCommand(40754,0)          -- re-enable snap,
    end
    Loop()                                    -- check for movement
  end
end

Main()
