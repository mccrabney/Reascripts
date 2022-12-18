--[[
 * ReaScript Name: Delete notes under edit cursor
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
        _, selected, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
        if startppqposOut <= editCursor_ppq_pos and endppqposOut >= editCursor_ppq_pos then -- is current note the note under the cursor?
          reaper.MIDI_DeleteNote( take, n )
        end
      end
    end
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock('Delete notes under edit cursor', -1)
end
