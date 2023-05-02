--[[
 * ReaScript Name: Mute notes under mouse cursor, closest first
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2022-05-02)
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
  local takes, noteMute
  if selectedItem ~= nil then 
    takes = reaper.CountTakes(selectedItem) 
  end
  
  local numberNotes = 0
  if takes ~= nil then 
    for t = 0, takes-1 do -- Loop through all takes within each selected item
      if reaper.TakeIsMIDI(take) then           -- make sure that take is MIDI
        local pitchUnderCursor = {}             -- pitches of notes under the cursor (for undo)
        local pitchSorted = {}                  -- ^ same, but to be sorted
        local notesUnderCursor = {}             -- item notecount numbers under the cursor
        local distanceFromMouse = {}            -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted

        notesCount, _, _ = reaper.MIDI_CountEvts(take)        -- count notes in current take
        for n = 0, notesCount do                              -- for each note, from first to last
          _, selected, mute, startppqposOut, endppqposOut, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position
          
          if startppqposOut <= position_ppq and endppqposOut >= position_ppq then -- is current note the note under the cursor?
            numberNotes = numberNotes+1                           -- add to count of how many notes are under mouse cursor
            
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch
            notesUnderCursor[numberNotes] = n                     -- add the notecount number to the array
            distanceFromMouse[numberNotes] = position_ppq - startppqposOut       -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppqposOut          -- put distance to cursor in index position of sorting table
          end                                                                    -- if current note is under the cursor
        end                                                                      -- for each note
        
        table.sort(distanceSorted)  -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)     -- sort the pitch table so the lowest pitch is at index position 1

        local closestNoteDistance = distanceSorted[1]                 -- find the distance from mouse cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local closestNote                                             -- initialize closestnote variable
        local sameDistance = 0                                        -- initialize the sameDistance variable
        local sameLowest
        
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            sameDistance = sameDistance+1
            for p = 1, #distanceFromMouse do                          -- for each entry in the distancefrommouse array
              if distanceFromMouse[p] == distanceSorted[1]  then      -- if distFromMouse index = closest note entry,
                sameLowest = p                                        -- get the index 

              end
            end 
          end
        end
        
        for i = 1, #distanceFromMouse do                        -- for each entry in the unsorted distance array
          if closestNoteDistance == distanceFromMouse[i] and sameDistance == 0 then   
                                    -- if the entry matchest the closest note distance from mouse cursor
            closestNote = i                                   -- get the index value of the closest note
            _, _, muteVal, _, _, _, _, _ = reaper.MIDI_GetNote(take, notesUnderCursor[closestNote])
            
            if muteVal then
              muteVal = false
            elseif not muteVal then
              muteVal = true
            end
            
            reaper.MIDI_SetNote( take, notesUnderCursor[closestNote], nil, muteVal, nil, nil, nil, nil, nil, nil) 
            reaper.Undo_OnStateChange2(proj, "muted note " .. pitchUnderCursor[closestNote] )
          end                                     
        end                                                         -- end for each entry in array
        
        --------------------------------------------------------------------
        
        if sameDistance > 0 then                          -- if there are notes that are the same distance from mouse
          for t = 1, #pitchUnderCursor do                 -- for each entry in the unsorted pitch array
            --if lowestPitch == pitchUnderCursor[t] then    -- if the entry matchest the closest note distance from mouse cursor
              _, _, muteVal, _, _, _, _, _ = reaper.MIDI_GetNote(take, notesUnderCursor[t])
              
              if muteVal then
                muteVal = 0
              elseif not muteVal then
                muteVal = 1
              end
              
              reaper.MIDI_SetNote( take, notesUnderCursor[t], nil, muteVal, nil, nil, nil, nil, nil, nil) 
              reaper.Undo_OnStateChange2(proj, "muted multiple equidistant notes" )
            --end
          end
        end
        reaper.SetExtState('mccrabney_MIDI edit - show notes, under mouse and last-received.lua', 'DoRefresh', '1', false)
        reaper.MIDI_Sort(take)
        end
      end
    end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

main()
