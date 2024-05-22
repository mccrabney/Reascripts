--[[
 * ReaScript Name: step through targeted notes under cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.1 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.0 (2023-06-10)
   + initial release
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'


---------------------------------------------------------------------
    --[[------------------------------[[--
          adjust incr
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)

  reaper.SetExtState(extName, 'stepIncr', 1, false)
  reaper.SetExtState(extName, 'DoRefresh', '1', false)
  
  
    
end
 
main()


  

  
  
