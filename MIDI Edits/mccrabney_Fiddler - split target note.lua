--[[
 * ReaScript Name: split target note
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 (2024-5-26)
   + fix missing BR mouse call when using mouse cursor as split target point 
 * v1.1 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.0 (2023-06-12)
   + Initial Release
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")   -- GET DIRECTORY FOR REQUIRE  -- AREA MOUSE INPUT HANDLING

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
    
function getNotesUnderCursor()
  
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
          split notes under mouse
    --]]------------------------------]]--
function main()
  reaper.PreventUIRefresh(1)
  
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
  
  if RazorEditSelectionExists() then
    --task = 1
    --job = 1
    --SetGlobalParam(job, task, _)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderCursor()
    
    if cursorSource == 1 then
      window, segment, details = reaper.BR_GetMouseCursorContext()
      cursorPos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
    else
      cursorPos = reaper.GetCursorPosition()   -- get pos at edit cursor
    end
    
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"} 
    
    if take ~= nil and targetNoteIndex ~= -1 then
      if cursorSource == 0 then 
        cursorPos = reaper.GetCursorPosition() 
      end
      -- get edit cursor position
      editCursor_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert project time to PPQ
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, sel, mute, startppqposOut, endppqposOut, chan, pitch, vel, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
        if startppqposOut < editCursor_ppq_pos and editCursor_ppq_pos < endppqposOut and n == targetNoteIndex then
          reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut, editCursor_ppq_pos, nil, nil, nil, nil)
          reaper.MIDI_InsertNote( take, sel, mute, editCursor_ppq_pos, endppqposOut, chan, pitch, vel, nil)
          reaper.MIDI_Sort(take)
        end
        
      end
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "split note" .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end
    
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  
end
 
main()

