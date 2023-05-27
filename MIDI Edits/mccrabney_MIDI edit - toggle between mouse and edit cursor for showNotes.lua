--[[
 * ReaScript Name: toggle between mouse/edit cursor for ShowNotes
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-05-24)
   + initial release
--]]

---------------------------------------------------------------------
extName = "mccrabney_MIDI edit - show notes, under mouse and last-received.lua"  

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   


---------------------------------------------------------------------
    --[[------------------------------[[--
          adjust incr
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)

  reaper.SetExtState(extName, 'toggleCursor', 1, false)
  
  --reaper.DeleteExtState(extName, 6, false) 
    
end
 
main()


  

  
  
