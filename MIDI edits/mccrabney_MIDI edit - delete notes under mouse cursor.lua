--[[
 * ReaScript Name: Delete notes under mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2021-04-02)
   + Initial Release
--]]

--  adapted from Stephan Römer

---------------------------------------------------------------------
    --[[------------------------------[[--
          get note and item under mouse   -- mccrabney      
    --]]------------------------------]]--
    
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
          --reaper.SetMediaItemSelected( mouseItem, true )
        end
      end
    end 
  end     
  return note, take, item, position_ppq
end

reaper.Undo_BeginBlock()

local note, take, selectedItem, position_ppq = getMouseInfo()

--editCursorPos = reaper.GetCursorPosition() -- get edit cursor position

for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
    --take = reaper.GetTake(selectedItem, t)
    if reaper.TakeIsMIDI(take) then           -- make sure that take is MIDI
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, selected, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
        if startppqposOut <= position_ppq and endppqposOut >= position_ppq then -- is current note the note under the cursor?
          reaper.MIDI_DeleteNote( take, n )
        end
      end
    end
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock('Delete notes under mouse cursor', -1)

