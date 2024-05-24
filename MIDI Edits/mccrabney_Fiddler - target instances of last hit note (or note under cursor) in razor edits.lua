--[[
 * ReaScript Name: target instances of last hit note (or note under cursor) in razor edits
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.51
--]]
 
--[[
 * Changelog:
 * v1.51 (2024-5-21)
   + fix use of local Razor Edit Function module, removed local duplicate function
 * v1.5 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.4
  + deselect other notes and only select target notes
 * v1.3
  + fixed nil comparisons
 * v1.2
  + added more user friendly ultraschall api checker
 * v1.1
  + if no razor edit exists, create one out of selected item
 * v1.0
  + 
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   

ultraschall_path = reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua"
if reaper.file_exists( ultraschall_path ) then
  dofile( ultraschall_path )
end

if not ultraschall or not ultraschall.GetApiVersion then -- If ultraschall loading failed of if it doesn't have the functions you want to use
  reaper.MB("Please install Ultraschall API, available via Reapack. Check online doc of the script for more infos.\nhttps://github.com/Ultraschall/ultraschall-lua-api-for-reaper", "Error", 0)
  return
end


extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

---------------------------------------------------------------------
    --[[------------------------------[[--
          adjust incr
    --]]------------------------------]]--
reaper.ClearConsole()

function main()
  --reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  reI, _, _, track, _ = ultraschall.RazorEdit_GetFromPoint(reaper.GetMousePosition())
  num, RazorEditTable = ultraschall.RazorEdit_GetAllRazorEdits(true, false)
  
  if reI == -1 and num ~= 0 then 
    val = ultraschall.RazorEdit_Remove(RazorEditTable[1]["Track"])
  end
  
  reaper.Main_OnCommand(40528, 0) -- select item under mouse
  item = reaper.GetSelectedMediaItem(0, 0)
  if item ~= nil then  take = reaper.GetActiveTake( item ) end
  if take ~= nil then 
    reaper.MIDI_SelectAll( take, 0 ) 
  end
  if track ~= nil then reaper.SetOnlyTrackSelected(track)end
  RazorEditSelectionExistsPlus(1, 1)
  reaper.SetExtState(extName, 'toggleNoteHold', 1, false)
end
 
main()




