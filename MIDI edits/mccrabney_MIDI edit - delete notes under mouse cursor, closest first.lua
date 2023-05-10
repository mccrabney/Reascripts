--[[
 * ReaScript Name: Delete notes under mouse cursor, closest first
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.31
--]]
 
--[[
 * Changelog:
 * v1.31 (2023-5-09)
    + if a razor edit exists, delete notes whose ons exist in REs. otherwise, delete under cusror.
 
 * v1.3 (2023-5-07)
    + major simplification using extstate from 'mccrabney_MIDI edit - show notes, under mouse and last-received.lua'
 
 * v1.2 (2023-1-05)
   + removed errant console message
 
 * v1.1 (2023-01-02)
   + fix for multiple notes
   + if multiple notes exist equidistant from mouse cursor, delete highest first
   
 * v1.0 (2023-01-01)
   + Initial Release
--]]

extName = "mccrabney_MIDI edit - show notes, under mouse and last-received.lua"  

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   


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
  tableSize = tonumber(reaper.GetExtState(extName, 1 ))
  guidString = reaper.GetExtState(extName, 2 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 3 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 4 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+4) then
        for i in string.gmatch(reaper.GetExtState(extName, t+4), "-?%d+,?") do
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
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil and targetNoteIndex ~= -1 then
      reaper.MIDI_DeleteNote(take, targetNoteIndex)
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "deleted note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end 
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  
end
 
main()

