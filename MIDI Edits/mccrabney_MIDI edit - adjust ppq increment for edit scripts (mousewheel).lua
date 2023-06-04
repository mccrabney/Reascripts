--[[
 * ReaScript Name: adjust ppq increment for edit scripts
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.12
--]]
 
--[[
 * Changelog:
 * v1.12 (2023-6-3)
   + extstate sync fix
 * v1.11 (2023-5-27)
   + added relative support
 * v1.1 (2023-5-27)
   + updated name of parent script extstate 
 * v1.0 (2023-05-24)
   + initial release
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'

---------------------------------------------------------------------
    --[[------------------------------[[--
          adjust incr
    --]]------------------------------]]--

local incr = {1, 10, 24, 48, 96, 240, 480, 960}

function main()
  reaper.PreventUIRefresh(1)

  if reaper.HasExtState(extName, 7) then   
  else
    reaper.SetExtState(extName, 7, 2, true)   -- set to 10 ticks (incrIndex pos2)
  end
  
  _,_,_,_,_,device,direction  = reaper.get_action_context() 
 
  incr = 1
  
  if device == 16383 and direction == 129      -- for relative 
  or device == 127 and direction >= 15 then    -- for mousewheel
    incr = incr
  end
 
  if device == 16383 and direction == 16383     -- for relative
  or device == 127 and direction <= -15 then    -- for mousewheel
    incr = incr * -1
  end  
  
  reaper.SetExtState(extName, 6, incr, true)
  
  --reaper.DeleteExtState(extName, 6, false) 
    
end
 
main()


  

  
  
