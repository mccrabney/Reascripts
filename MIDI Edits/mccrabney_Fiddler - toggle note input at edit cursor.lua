--[[
 * ReaScript Name: toggle note input at edit cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog: 
 * v1.0 (2026-08-21)
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
          toggle note input at edit cursor
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)
  reaper.SetExtState(extName, 'input', 1, false)
end
 
main()
  
