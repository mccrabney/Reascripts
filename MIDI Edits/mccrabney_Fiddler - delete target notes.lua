--[[
 * ReaScript Name: delete target notes
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.34
--]]
 
--[[
 * Changelog:
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

-----------------------------------------------------------
    --[[------------------------------[[--
          check for razor edit 
    --]]------------------------------]]--
    
function RazorEditSelectionExists()
 
  for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end              -- if present, return true 
    if x == nil then return false end            -- return that no RE exists
  end
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
 
  if RazorEditSelectionExists() then
    task = 1
    job = 1
    SetGlobalParam(job, task, _)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
    --reaper.ShowConsoleMsg(targetNoteNumber)
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil and targetNoteIndex ~= -1 then
      reaper.MIDI_DeleteNote(take, targetNoteIndex)
      reaper.MIDI_Sort(take)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "deleted note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end 
  end
  
  reaper.SetExtState(extName, 'DoRefresh', '1', false)
  
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  
end
 
main()

