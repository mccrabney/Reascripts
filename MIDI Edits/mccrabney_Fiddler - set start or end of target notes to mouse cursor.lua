--[[
 * ReaScript Name: set start or end of target note to mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
 * Changelog:
 * v1.00 (2024-11-4)
--]]

--[[
  howto: this script changes the target cursor to EDIT (blue) and adjusts the length to mousepos
  if mouse is after target notestart, running this script will adjust note endpoint.
  if mouse is before target notestart, the note startpoint will move to mouse point.
  if your target cursor is currently on EDIT but no note is found, this script will swap cursor to MOUSE
  and you can run it again to change the length of the note under mouse cursor.
--]]


---------------------------------------------------------------------
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
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+4) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  
  return take, targetNoteNumber, targetNoteIndex
end

function getMouseInfo()    
  local item, position_ppq, take, note
  window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
  
  if details == "item" or inline_editor then         -- hovering over item in arrange
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
  
    if reaper.TakeIsMIDI(take) then -- is take MIDI?
      item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
      position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos) -- convert to PPQ
      local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      
      for n = notesCount-1, 0, -1 do
        _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position              
      
        if startppq <= position_ppq and endppq >= position_ppq then 
          note = pitch
        end
      end
    end 
  end     
  return note, take, item, position_ppq
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          set start or end of target note to mouse cursor
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)
  
  if RazorEditSelectionExists() then
  else
    local note, take, selectedItem, position_ppq = getMouseInfo()
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
    
    if cursorSource == 0 and targetNoteNumber == nil then 
      reaper.SetExtState(extName, 'toggleCursor', 1, true)
      reaper.SetExtState(extName, 'DoRefresh', 1, true)
    end
    
    if cursorSource ~= 0 then 
      reaper.SetExtState(extName, 'toggleCursor', 1, true)
      reaper.SetExtState(extName, 'DoRefresh', 1, true)
    end
    
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      _, _, _, startppqposNext, _, _, pitchNext, _ = reaper.MIDI_GetNote( take, targetNoteIndex+1 )
      
      if position_ppq ~= nil then 
        if position_ppq > startppqpos then
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, position_ppq, nil, nil, nil, nil)
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to 1st noteon
        else
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, position_ppq)
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, position_ppq, nil, nil, nil, nil, nil)
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to 1st noteon
        end
      end
      
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "changed length of note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
 
main()

  

  
  
