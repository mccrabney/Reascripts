-----------------------------------------------------------
    --[[------------------------------[[--
          get details of MIDI notes under cursor
    --]]------------------------------]]--
    
step = 0
function getCursorInfo()         -- this is a heavy action, run it as little as possible
  mouse = MouseInfo()            -- borrows Sexan's Area51 mouse module
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local showNotes = {}           -- table consisting of sub-tables grouping Pitch and Vel
  local trackHeight              
  local take, takes, channel
  local targetNoteIndex, targetPitch  -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take
  track, window = reaper.GetThingFromPoint( mouse.x, mouse.y)
  local hZoom = reaper.GetHZoomLevel()

  if window == "arrange" and hZoom > 2 then   -- if slightly zoomed into arrange,
    if track then                                                   -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")  -- get track height
      if cursorSource == 1 then                     -- if cursorSource is mouse cursor,
        cursorPos = mouse.p                         -- get mouse position
      else                                          -- if cursorSource is edit cursor,
        cursorPos = reaper.GetCursorPosition()      -- get pos at edit cursor
      end
      
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item,               
          item = reaper.GetTrackMediaItem(track,i)      
          local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
          local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
          if itemStart <= cursorPos and itemEnd > cursorPos then  -- if edit cursor is within item bounds,
            take = reaper.GetTake( item, 0 )       -- get the take
          end
        end
      end
    end           -- if there is a track

    local startMarkerPos = -1             -- initialize startMarkerPos to an inapplicable value
    local firstMarkerMeasure = 0          -- set up marker time math values
    local firstMarkerQN = 0               -- ^ ...
    local mrk_cnt = reaper.CountProjectMarkers(0)   -- how many markers in project
    if mrk_cnt ~= nil then                        -- if marker count not nil,
      markers = {}                                -- initialize marker array
      for i = 0, mrk_cnt - 1 do                   -- for each marker
        local _, isrgn, pos, _, markerName, index = reaper.EnumProjectMarkers( i ) -- get data from each marker
        if markerName == "start" then             -- is there a "Start" marker?
          local markerQN = reaper.TimeMap_timeToQN_abs( proj, pos )                -- get its qn position
          local markerMeasure, _ = reaper.TimeMap_QNToMeasures( proj, markerQN )   -- get its measure position
          startMarkerPos = pos                    -- set up firstmarker positioning for text readout
          firstMarkerMeasure = markerMeasure
          firstMarkerQN = markerQN 
        end
      end
    end

    if take and trackHeight > 10 then           -- if there is a take, and if track height isn't tiny
      if reaper.TakeIsMIDI(take) then           -- if take is midi
        local tr = reaper.GetMediaItemTake_Track( take )
        _, trName = reaper.GetTrackName( tr )
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromCursor = {}           -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert to PPQ
        local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
        
        for n = notesCount-1, 0, -1 do          -- for each note, from back to front
          _, selected, muted, startppq, endppq, ch, pitch, vel = reaper.MIDI_GetNote(take, n)  -- get note data           
          if startppq <= position_ppq and endppq >= position_ppq then  -- is current note the note under the cursor?
            notePos = reaper.MIDI_GetProjTimeFromPPQPos( take, startppq)  -- note pos of note under cursor
            if startMarkerPos ~= -1 and notePos >= startMarkerPos then   -- if after "start" marker
              ptidx = reaper.CountTempoTimeSigMarkers( proj )            
              if ptidx == 0 then 
                _, bpi = reaper.GetProjectTimeSignature2( proj )
              elseif ptidx ~= 0 then 
                lastTempoMarker = reaper.FindTempoTimeSigMarker( proj , notePos)
                _, _, _, _, _, bpi, _, _ = reaper.GetTempoTimeSigMarker( proj, lastTempoMarker)
                if bpi == -1 then bpi = 4 end                     -- bpi sanitizer
              end
              
              noteQN = reaper.TimeMap_timeToQN( notePos )         -- math preparing time display
              noteQN = noteQN - firstMarkerQN                     
              _, remainder = math.modf(noteQN)                    
              noteMeasure = (math.floor(noteQN / bpi )) + 1
              notePPQ = math.floor((remainder * 960) + .5)

              if notePPQ == 960 then                              -- math preparing time display
                noteMeasure = noteMeasure + 1 
                notePPQ = 0 
              end
              
              while noteQN > bpi do noteQN = noteQN - bpi end     -- math, text preparing time display
              noteQN = math.floor((noteQN + 1) +.000005 )
              if noteQN > bpi then noteQN = 1 end
              stringNotePPQ = tostring(notePPQ)
              while string.len(stringNotePPQ) < 3 do stringNotePPQ = "0" .. stringNotePPQ end 
              stringNoteMeasure = tostring(noteMeasure)
              posString = noteMeasure .. "." .. noteQN .. "." .. stringNotePPQ .. "  "
            else                                                  -- if not after "start" marker
              posString = ""                                      -- skip the time display in readout
            end
                                                
                    -- if RS5k, this section shows either a named MIDI note or the track name display readout 
            userNoteName = reaper.GetTrackMIDINoteNameEx( 0, track, pitch, ch )  -- set up named note/track readout text
            local displayName
                                                                  -- if no named MIDI note, get track name
            if userNoteName ~= nil 
              then displayName = userNoteName 
            elseif trName == "sequencer" then
              displayName = getInstanceTrackName(pitch) 
            end
            
            if displayName == nil then displayName = "" end       -- if no displayName, blank the readout value
            if displayName ~= "" then                             -- if displayname is not blank, 
              displayName = "'" .. displayName .. "'"             -- add quotes to displayname
            end
            
                    -- fill out arrays
            numberNotes = numberNotes+1                           -- add to count of how many notes are under cursor
            noteLength = math.floor(endppq - startppq)            -- establish the length of the note
            showNotes[numberNotes] = {pitch, vel, noteLength, ch+1, n, tostring(muted), posString, displayName}   -- get the pitch and corresponding velocity as table-in-table
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch                    
            distanceFromCursor[numberNotes] = position_ppq - startppq      -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppq          -- put distance to cursor in index position of sorting table
          end
        end
        
        if #showNotes then                                        -- if showNotes array is populated
          if reaper.HasExtState(extName, 'stepIncr') then         -- update display, called from child scripts
            step = step + 1                                       -- proceed to next/previous note
            if step >= #showNotes then step = 0 end               -- if step exceeds number of notes, don't step
            reaper.SetExtState(extName, 'step', step, false)      -- update step extstate
            reaper.DeleteExtState(extName, 'stepIncr', false)     -- delete stepIncr extstate
          end
          
          if reaper.HasExtState(extName, 'stepDown') then         -- update display, called from child scripts
            step = 0
            reaper.SetExtState(extName, 'step', step, false)
            reaper.DeleteExtState(extName, 'stepDown', false)
          end
        end
        
        table.sort(distanceSorted)                -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)                   -- sort the pitch table, so the lowest pitch is at index position 1
        local targetNoteDistance = distanceSorted[1]                  -- find the distance from cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local sameLowest
        
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            for p = 1, #distanceFromCursor do                         -- for each entry in the distanceFromCursor array
              if distanceFromCursor[p] == distanceSorted[1] then      -- if distFromMouse index = closest note entry,
                sameLowest = p                                        -- get the index 
              end
            end 
          end
        end
        
        --~~~~~~~ find closest note
        for i = #distanceFromCursor, 1, -1 do                       -- for each entry in the unsorted distance array
          if targetNoteDistance == distanceFromCursor[i] then       -- if targetnotedistance is found in the distance array
            if #showNotes == 1 then step = 0 end                    
            if #showNotes > i-1  + step then
              targetNoteIndex = showNotes[i + step][5]
              targetPitch = showNotes[i + step][1]                  -- get the pitch value of the closest note
            end                                        
          end
        end                                                
      end           -- if take is MIDI
    end             -- if take not nil

    table.sort(showNotes, function(a, b)                -- sort the shownotes table
      return a[1] < b[1]
    end)

    if targetNoteIndex then 
      _, _, _, targetPPQ, targetEndPPQ, _, _, _= reaper.MIDI_GetNote(take, targetNoteIndex) -- get note start/end position              
      targetNotePos = reaper.MIDI_GetProjTimeFromPPQPos( take, targetPPQ)     -- get target note project time
      targetEndPos = reaper.MIDI_GetProjTimeFromPPQPos( take, targetEndPPQ)   -- get target note end position
      track = reaper.GetMediaItemTake_Track( take )                           -- get track
      trPos = reaper.GetMediaTrackInfo_Value( track, 'I_TCPY' )               -- y pos of track TCP
      tcpHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH')            -- get tcp height
    end 
    
    -------------------------------------------- set up extstate to communicate with other scripts
    local numVars = 8                                             -- see below
    
    reaper.SetExtState(extName, 1, numVars, false)                -- how many variables are we sending via extstates
    reaper.SetExtState(extName, 2, #showNotes, false)             -- how many notes are under mouse
    guidString = reaper.BR_GetMediaItemTakeGUID( take )           -- get guidString from take
    reaper.SetExtState(extName, 3, tostring(guidString), false)   -- what take is under mouse
    
    if targetNoteIndex ~= nil and targetPitch ~= nil then    
      reaper.SetExtState(extName, 4, targetPitch, false)          -- what is the target pitch under mouse
      reaper.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    elseif targetNoteIndex == nil then 
      targetNoteIndex = -1
      step = 0
      reaper.DeleteExtState(extName, 4, false)                    -- what is the target pitch under mouse
      reaper.SetExtState(extName, 'step', step, false)            -- adjust step extstate
      reaper.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    end
    
    -- NOTE: extState 6 = +, - incrIndex. extState 7 = incr Value
    for i = 1, #showNotes do                             -- send off the table after all of the other variables
      reaper.SetExtState(extName, i + numVars, table.concat(showNotes[i],","), false)
    end

    return take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos
  end
end
