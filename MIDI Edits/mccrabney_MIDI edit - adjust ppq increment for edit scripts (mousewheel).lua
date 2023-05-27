--[[
 * ReaScript Name: adjust ppq increment for edit scripts
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
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

function main()
  reaper.PreventUIRefresh(1)

  local incr = 1

  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  if mouse_scroll > 0 then 
    incr = incr     
    elseif mouse_scroll < 0 then 
    incr = incr * -1                          -- how many ticks to move noteoff backwards, adjust as desired
  end
  
  reaper.SetExtState(extName, 6, incr, false)
  
  --reaper.DeleteExtState(extName, 6, false) 
    
end
 
main()


  

  
  
