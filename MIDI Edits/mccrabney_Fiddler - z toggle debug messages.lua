--[[
 * ReaScript Name: toggle debug messages
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.5
--]]
 
--[[
 * Changelog: 
 * v1.5 (2025-1-3)
   + reaper.set_action_options(1)
 * v1.4 (2024-5-21)
   + switch to using local Razor Edit Function module
 * v1.3 (2023-11-26)
   + send refresh extstate to change indicator block in realtime
 * v1.2 (2023-5-29)
   + set extstate to persist
 * v1.1 (2023-5-27)
   + updated name of parent script extstate 
 * v1.0 (2023-05-24)
   + initial release
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1)
---------------------------------------------------------------------
    --[[------------------------------[[--
          toggle debug messages
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)
  reaper.SetExtState(extName, 'debug', 1, false)
end
 
main()
  
