--[[
 * ReaScript Name: Delete notes under mouse cursor, closest first
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

function main()
  reaper.PreventUIRefresh(1)
  local note, take, selectedItem, position_ppq = getMouseInfo()
  local takes
  if selectedItem ~= nil then 
    takes = reaper.CountTakes(selectedItem) 
  end
  local numberNotes = 0
  
  if takes ~= nil then 
    for t = 0, takes-1 do -- Loop through all takes within each selected item
      if reaper.TakeIsMIDI(take) then           -- make sure that take is MIDI
        local notesUnderCursor = {}
        local pitchUnderCursor = {}
        local notesUnderCursorClosest = {}
        local sortedNotes = {}
         
        notesCount, _, _ = reaper.MIDI_CountEvts(take)        -- count notes in current take
        for n = 0, notesCount do                              -- for each note, from first to last
          _, selected, _, startppqposOut, endppqposOut, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
          
          if startppqposOut <= position_ppq and endppqposOut >= position_ppq then -- is current note the note under the cursor?
            numberNotes = numberNotes+1                           -- add to count of how many notes are under mouse cursor
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            notesUnderCursor[numberNotes] = n                     -- add the note number to the array
            notesUnderCursorClosest[numberNotes] = position_ppq - startppqposOut -- put distance to cursor in index position reference table
            sortedNotes[numberNotes] = position_ppq - startppqposOut             -- put distance to cursor in index position of sorting table
          end                                                                    -- if current note is under the cursor
        end                                                                      -- for each note
        
        table.sort(sortedNotes)                                     -- sort the table so the closest noteon is at index position 1
        local closestNoteDistance = sortedNotes[1]                    -- find the distance from mouse cursor of the closest noteon
        local closestNote                                             -- initialize closestnote variable
        for i = 1, #notesUnderCursorClosest do                        -- for each entry in the unsorted array
          
          if closestNoteDistance == notesUnderCursorClosest[i] then    -- if the entry matchest the closest note distance from mouse cursor
            closestNote = i                                         -- get the index value of the closest note
            reaper.MIDI_DeleteNote( take, notesUnderCursor[closestNote] ) 
            reaper.Undo_OnStateChange2(proj, "deleted note " .. pitchUnderCursor[closestNote] )

          end                                     
        end                                                         -- end for each entry in array
        
        reaper.MIDI_Sort(take)
        end
      end
    end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

main()
