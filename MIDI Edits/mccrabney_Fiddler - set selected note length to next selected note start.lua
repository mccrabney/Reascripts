--[[
 * ReaScript Name: set selected note lengths to Fiddler increment
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.0

-- @provides
--   Modules/Sexan_Area_51_mouse_mccrabney_tweak.lua > mccrabney_Fiddler - nudge target notes (mousewheel)/Sexan_Area_51_mouse_mccrabney_tweak.lua
--   Modules/mccrabney_MIDI_Under_Mouse.lua          > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_MIDI_Under_Mouse.lua
--   Modules/mccrabney_Razor_Edit_functions.lua      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_Razor_Edit_functions.lua
--   Modules/mccrabney_misc.lua                      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_misc.lua

--]]
 
--[[
 * Changelog:
 * v1.0 (nnnn-06-11)
   + 
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1,2)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/mccrabney_MIDI_Under_Mouse")
require("Modules/mccrabney_misc")
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")   -- GET DIRECTORY FOR REQUIRE  -- AREA MOUSE INPUT HANDLING

-----------------------------------------------------------
    --[[------------------------------[[--
          check for razor edit 
    --]]------------------------------]]--
    
function RazorEditSelectionExists()
  for i = 0, reaper.CountTracks(0)-1 do
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then 
    return true end
  end--for  
  return false
end                              
  
function getNotesUnderMouseCursor()
  showNotes = {}
  numVars = tonumber(reaper.GetExtState(extName, 1 ))
  tableSize = tonumber(reaper.GetExtState(extName, 2 ))
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 4 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+numVars) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  return take, targetNoteNumber, targetNoteIndex
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          nudge notes whose ons are in RE if present, else nudge note under mouse, closest first
    --]]------------------------------]]--

selectedNotes = 0

function main()
  reaper.PreventUIRefresh(1)
  local incr = tonumber(reaper.GetExtState(extName, 7))
  if incr == nil then incr = 0 end
  selNotes = {}
  selCount = 0
  
  take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
  if take ~= nil then
    notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count Snotes in current take
    for n = 0, notesCount-1, 1 do          -- for all notes, last to first
      _, sel, mute, startppqposOut, endppqposOut, chan, pitch, vel, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
      if sel then
        selCount = selCount + 1
        selNotes[selCount] = {n, startppqposOut}
      end
    end
  
    if selCount ~= 0 then
      for i = 1, #selNotes, 1 do 
        if i+1 <= #selNotes then
          reaper.MIDI_SetNote(take, selNotes[i][1], nil, nil, nil, selNotes[i+1][2], nil, nil, nil, nil)
        end
      end
      reaper.MIDI_Sort(take)
    end
    
    reaper.MIDI_Sort(take)
    --reaper.SetExtState(extName, 'DoRefresh', '1', false)
    reaper.Undo_OnStateChange2(proj, "set duration of notes to Fiddler increment")
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
 
main()

