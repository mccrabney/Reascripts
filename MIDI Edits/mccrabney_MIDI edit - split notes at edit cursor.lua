--[[
 * ReaScript Name: split notes at edit cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-05-21)
   + Initial Release
--]]

--  adapted from Stephan Römer

reaper.Undo_BeginBlock()

editCursorPos = reaper.GetCursorPosition() -- get edit cursor position
selectedItem = reaper.GetSelectedMediaItem(0, 0)
if selectedItem == nil then
  --reaper.ShowMessageBox("Please select an item", "Error", 0)
else
  for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
    take = reaper.GetTake(selectedItem, t)
    if reaper.TakeIsMIDI(take) then -- make sure, that take is MIDI
      editCursor_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, editCursorPos) -- convert project time to PPQ
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, sel, mute, startppqposOut, endppqposOut, chan, pitch, vel, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
        if startppqposOut < editCursor_ppq_pos and editCursor_ppq_pos < endppqposOut then
          reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut, editCursor_ppq_pos-1, nil, nil, nil, nil)
          reaper.MIDI_InsertNote( take, sel, mute, editCursor_ppq_pos, endppqposOut, chan, pitch, vel, nil)
          reaper.MIDI_Sort(take)
        end
        
      end
    end
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock('Delete notes that start at edit cursor', -1)
end
