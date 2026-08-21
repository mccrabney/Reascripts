--[[
 * ReaScript Name: delete target notes
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.38
--]]
 
--[[
 * Changelog:
 * v1.38 (2026-08-21)
   + better RazorEditSelectionExists function
 * v1.37 (2025-5-23)
   + if no item under mouse and script is triggered, delete all selected items
 * v1.36 (2025-1-3)
   + reaper.set_action_options(1) 
 * v1.35 (2024-12-20)
   + delete item under mouse cursor if not MIDI
 * v1.34 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.33 (2023-10-20)
  + fighting with reapack to make sure it updates
 * v1.32 (2023-6-19)
  + removed erroneous console message
 * v1.311 (2023-5-27)
  + updated name of parent script extstate
 * v1.31 (2023-5-09)
    + if a razor edit exists, delete notes whose ons exist in REs. otherwise, delete under cursor.
 * v1.3 (2023-5-07)
    + major simplification using extstate from 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'
 * v1.2 (2023-1-05)
   + removed errant console message
 * v1.1 (2023-01-02)
   + fix for multiple notes
   + if multiple notes exist equidistant from cursor, delete highest first
 * v1.0 (2023-01-01)
   + Initial Release
--]]

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1)
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
  

---------------------------------------------------------------------
    --[[------------------------------[[--
          refer to extstates to get MIDI under mouse
    --]]------------------------------]]--

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
          delete notes whose ons are in RE if present, else delete note under mouse, closest first
    --]]------------------------------]]--
    
function main()
  reaper.PreventUIRefresh(1)
  take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
  
  --reaper.ShowConsoleMsg(tostring(RazorEditSelectionExists()) .. "\n")
  
  if RazorEditSelectionExists() == true and targetNoteNumber then
    task = 1
    job = 1
    SetGlobalParam(job, task, _)
    return 
  end
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil then
      if reaper.TakeIsMIDI(take) and targetNoteIndex ~= -1 then   -- if engaging fiddler
        reaper.SetExtState(extName, 'Delete', '1', false)
        --reaper.MIDI_DeleteNote(take, targetNoteIndex)
        --reaper.MIDI_Sort(take)
        --octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
        --cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
        --reaper.Undo_OnStateChange2(proj, "deleted note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
      end
    
      if reaper.TakeIsMIDI(take) and targetNoteIndex == -1 then  -- if MIDI but not engaging fiddler
        if RazorEditSelectionExists() == false then 
          reaper.Main_OnCommand(40289, 0) -- deselect all items
          reaper.Main_OnCommand(40528, 0) -- sel item un mouse cursor
        end
        reaper.Main_OnCommand(40697, 0) -- remove anything selected
      end
    else  -- if no MIDI take
      --reaper.Main_OnCommand(40006, 0) -- remove
      if reaper.CountSelectedMediaItems(track) > 1 then
        reaper.Main_OnCommand(40697, 0) -- remove
      elseif reaper.CountSelectedMediaItems(track) == 0 then
        reaper.Main_OnCommand(40528, 0) -- sel item un mouse cursor
        reaper.Main_OnCommand(40697, 0) -- remove
      elseif reaper.CountSelectedMediaItems(track) == 1 then
        if take then 
          reaper.Main_OnCommand(40528, 0) -- sel item un mouse cursor
          reaper.Main_OnCommand(40697, 0) -- remove          
        else
          reaper.Main_OnCommand(40697, 0) -- remove
        end
        
      end
    end
  end
  
  --reaper.SetExtState(extName, 'DoRefresh', '1', false)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  
  --]]
  
   
main()
