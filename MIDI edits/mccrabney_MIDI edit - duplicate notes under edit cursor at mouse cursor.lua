--[[
 * ReaScript Name: duplicate notes under edit cursor at mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2022-01-08)
   + nil messages
   
 * v1.0 (2022-01-01)
   + Initial Release
--]]



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

        end
      end
    end 
  end     
  return note, take, item, position_ppq
end

local cursorPos = reaper.GetCursorPosition()
local note, take, selectedItem, position_ppq = getMouseInfo()

if selectedItem ~= nil then
  for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
    if reaper.TakeIsMIDI(take) then           -- make sure that take is MIDI
      local cursorPosppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos)
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, selected, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note start/end position
        if startppqposOut <= cursorPosppq and endppqposOut >= cursorPosppq then -- is current note the note under the edit cursor?
          reaper.MIDI_InsertNote( take, selected, muted, position_ppq, position_ppq + (endppqposOut-startppqposOut), chan, pitch, vel, noSortIn )
        end
      end
    end
  end
end  
  reaper.Undo_OnStateChange( 'duplicate notes under mouse cursor at edit cursor' )
  reaper.UpdateArrange()
