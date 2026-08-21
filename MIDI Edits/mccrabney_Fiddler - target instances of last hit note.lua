--[[
 * ReaScript Name: target instances of last hit note
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
 * Changelog:
 * v1.00 (2025-10-1)
   + branched from previous script
   
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
reaper.set_action_options(1)
ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then
  dofile( ultraschall_path )
end

extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

---------------------------------------------------------------------
    --[[------------------------------[[--
          noteHold
    --]]------------------------------]]--
reaper.ClearConsole()

function main()
  --reaper.Undo_BeginBlock()
  reaper.SetExtState(extName, 'inputNote', 1, false)
  
end
 
main()




