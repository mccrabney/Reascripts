--[[
 * @noindex
--]] 

-- feb ~ 2026
-- dec 3 2025    
-- dec 8 2023
  
step = 0

function getCursorInfo()         -- heavy action, run as infrequently as possible
  mouse = MouseInfo()            -- borrows Sexan's Area51 mouse module
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local showNotes = {}           -- table consisting of sub-tables grouping Pitch and Vel
  local targetNoteIndex, targetPitch, targetMute  -- initialize target variable
  --local numberNotes = 0
  local take, mouseTake, mouseTrPos
  local track, window = reaper.GetThingFromPoint(mouse.x, mouse.y)
  local hZoom = reaper.GetHZoomLevel()
  local trackHeight
  local mouseItems = {}
  local itemsUnderMouse = 0
  local spread = -1
  
  if window == "arrange" and hZoom > 2 then         -- if slightly zoomed into arrange,
    if track then                                   -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")  -- get track height
      cursorPos = mouse.p                           -- get mouse positi
      local CountTrItem = reaper.CountTrackMediaItems(track)
      local curItemCount = 0
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item, first to last              
          local item = reaper.GetTrackMediaItem(track,i)      
          local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
          local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
          if itemStart <= cursorPos and itemEnd > cursorPos then  -- if mouse cursor is within item bounds,
            itemsUnderMouse = itemsUnderMouse + 1      -- increment
            mouseItems[itemsUnderMouse] = item         -- table of items under mouse
            --take = reaper.GetActiveTake(item)        -- get the take
          end
        end
      end
      if itemsUnderMouse ~= lastItemsUnderMouse then   -- if count of items under mouse has changed
        lastItemsUnderMouse = itemsUnderMouse          -- do once
        if reaper.GetToggleCommandState(40507) == 1 and itemsUnderMouse == 1 then
          --reaper.Main_OnCommand(40507, 0)  -- toggle offset overlapping vertical items
        elseif reaper.GetToggleCommandState(40507) == 0 and itemsUnderMouse == 2 then
          --reaper.Main_OnCommand(40507, 0)  -- toggle offset overlapping vertical items
        end
      end
      if itemsUnderMouse == 1 and reaper.CountTakes(mouseItems[1]) == 1 then                      -- if there's one item
        local take = reaper.GetActiveTake(mouseItems[1])    -- it's the take we want
        local mute = reaper.GetMediaItemInfo_Value(mouseItems[1], "B_MUTE")
        if reaper.TakeIsMIDI(take) and mute ~= 1 then mouseTake = take end
      elseif itemsUnderMouse == 2 then                  -- if 2
        for i = 1, #mouseItems, 1 do                    -- check each item for slelection
          local item = mouseItems[i]
          local mute = reaper.GetMediaItemInfo_Value(mouseItems[i], "B_MUTE")
          local take = reaper.GetActiveTake(item)
          if reaper.IsMediaItemSelected(item) and mute ~= 1 and reaper.TakeIsMIDI(take) then 
            mouseTake = take
          end
        end
      end
    end -- if there is a track

    startMarkerPos = -1             -- initialize startMarkerPos to an inapplicable value
    firstMarkerMeasure = 0          -- set up marker time math values
    firstMarkerQN = 0               --  ^ ...
    local mrk_cnt = reaper.CountProjectMarkers(0) -- how many markers in project
    if mrk_cnt ~= nil then                        -- if marker count not nil,
      for i = 0, mrk_cnt-1 do                     -- for each marker
        local _, isrgn, pos, _, markerName, index = reaper.EnumProjectMarkers(i) -- get data from each marker
        if markerName == "start" then             -- is there a "Start" marker?
          local markerQN = reaper.TimeMap_timeToQN_abs(proj, pos)                -- get its qn position
          local markerMeasure, _ = reaper.TimeMap_QNToMeasures(proj, markerQN)   -- get its measure position
          startMarkerPos = pos                    -- set up firstmarker positioning for text readout
          firstMarkerMeasure = markerMeasure
          firstMarkerQN = markerQN 
        end
      end
    end
  
    local nm, cursorPosPpq
    local high, low
    local notesCount
    local pitchHigh, pitchLow
    
    if mouseTake and trackHeight > 10 then           -- if there is a mouseTake, and if track height isn't tiny
      getNoteCallCount = 0
      _, nm = reaper.GetTrackName(track)
      
      if reaper.TakeIsMIDI(mouseTake) then           -- if take is midi
        local tr = reaper.GetMediaItemTake_Track(mouseTake)
        _, trName = reaper.GetTrackName(tr)
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromCursor = {}           -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        cursorPosPpq = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, cursorPos) -- convert to PPQ
        _, notesCount, _ = reaper.MIDI_CountEvts(mouseTake) -- count notes in current take

        for i = 1, #mouseItems, 1 do              -- for each item under mouse
          local item = mouseItems[i]
          local take = reaper.GetActiveTake(item)
          local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local itemEndPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

          local low = 0                           -- for loop low limit
          local high = notesCount-1               -- for loop high limit
          local midCount = math.floor((notesCount)/2)   -- idx of median note
          local _, _, _, midStartppq, midEndppq = reaper.MIDI_GetNote(mouseTake, midCount)  -- get note data           
          
          if cursorPosPpq > midEndppq and notesCount > 10 then        -- if cursor is after median note endpoint, check only second half
            low = midCount                        -- stop checking after note after median note
          elseif cursorPosPpq < midStartppq and notesCount > 10 then  -- if cursor is before median note startpoint, check only first half
            high = midCount                       -- start checking at median note
          end
          
          local numberNotes = 0
          for n = high, low, -1 do                -- for notes, from back to front
            local _, selected, muted, startppq, endppq, ch, pitch, vel = reaper.MIDI_GetNote(mouseTake, n)  -- get note data           
            
            if reaper.GetPlayState() ~= 5 then         --- OUT OF BOUNDS NOTE EXCLUSION AND ON/OFF REPOSITIONING
              if reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, startppq+1) > itemEndPos      -- if note start is past item end
              or reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, endppq)   < itemPos then      -- if note end is past item start
                if #mouseItems == 1 then reaper.MIDI_DeleteNote(mouseTake, n) end           -- delete note
              end
              
              if  reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, startppq) < itemPos          -- if note start is before item start
              and reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, endppq)   > itemPos then     -- if note end is past item end 
                if #mouseItems == 1 then 
                  reaper.MIDI_SetNote(mouseTake, n, selected, muted, reaper.MIDI_GetPPQPosFromProjTime(mouseTake, itemPos))
                end
              end                                                                      -- set note start to item start
              
              if  reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, startppq) < itemEndPos       -- if note start is before item end
              and reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, endppq)   > itemEndPos then  -- if note end is past item end
                if #mouseItems == 1 then 
                  reaper.MIDI_SetNote(mouseTake, n, selected, muted, startppq, reaper.MIDI_GetPPQPosFromProjTime(mouseTake, itemEndPos))
                end
              end                                                                      -- set note end to item end
            end
            --]]--------
            
            --reaper.ShowConsoleMsg(n .. " sppq: " .. startppq .. " curposppq: " .. cursorPosPpq .. " " ..  "\n")
            if endppq >= cursorPosPpq and startppq <= cursorPosPpq then                -- is current note the note under the cursor?
              local notePos = reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, startppq)   -- note pos of note under cursor
              local bpi
              local posString
              
              if startMarkerPos ~= -1 then                          -- if there is a start marker
                ptidx = reaper.CountTempoTimeSigMarkers(proj)            
                if ptidx == 0 then 
                  _, bpi = reaper.GetProjectTimeSignature2(proj)
                elseif ptidx ~= 0 then 
                  lastTempoMarker = reaper.FindTempoTimeSigMarker(proj , notePos)
                  _, _, _, _, _, bpi, _, _ = reaper.GetTempoTimeSigMarker(proj, lastTempoMarker)
                  if bpi == -1 then bpi = 4 end                     -- bpi sanitizer
                end
                
                local noteQN = reaper.TimeMap_timeToQN(notePos)   -- math preparing time display
                noteQN = noteQN - firstMarkerQN                     
                if noteQN < 0 then noteQN = 0 end
                _, remainder = math.modf(noteQN)                    
                local noteMeasure = (math.floor(noteQN / bpi)) + 1 
                local notePPQ = math.floor((remainder * 960) + .5)
                if notePPQ == 960 then                              -- math preparing time display
                  noteMeasure = noteMeasure + 1 
                  notePPQ = 0 
                end
         
                while noteQN > bpi do noteQN = noteQN - bpi end     -- math, text preparing time display
                noteQN = math.floor((noteQN + 1) +.000005 )
                if noteQN > bpi then noteQN = 1 end
                local neg = false
                if noteMeasure < 0 or noteQN < 0 or notePPQ < 0 then neg = true end
  
                local stringNotePPQ = tostring(math.abs(notePPQ))
                while string.len(stringNotePPQ) < 3 do stringNotePPQ = "0" .. stringNotePPQ end
                if neg == false then
                  posString = math.abs(noteMeasure) .. "." .. math.abs(noteQN) .. "." .. stringNotePPQ .. "  "
                else posString = "" end
              else                                                  -- if no "start" marker
                posString = ""                                      -- skip the time display in readout
              end
                      -- if RS5k, this section shows either a named MIDI note or the track name display readout 
              local userNoteName = reaper.GetTrackMIDINoteNameEx(0, track, pitch, ch)  -- set up named note/track readout text
              local displayName
              if userNoteName ~= nil then displayName = userNoteName end  -- if named in MIDI editor
              if displayName == nil then displayName = "" end       -- if no displayName, blank the readout value
              if displayName ~= "" then                             -- if displayname is not blank, 
                displayName = "'" .. displayName .. "'"             -- add quotes to displayname
              end
                      -- fill out arrays
              numberNotes = numberNotes+1          -- add to count of how many notes are under cursor
              
              local noteLength = math.floor(endppq - startppq)            -- establish the length of the note
              showNotes[numberNotes] = {pitch, vel, noteLength, ch+1, n, tostring(muted), posString, displayName, selected}   -- get the pitch and corresponding velocity as table-in-table
              pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
              pitchSorted[numberNotes] = pitch                    
              distanceFromCursor[numberNotes] = cursorPosPpq - startppq      -- put distance to cursor in index position reference table
              distanceSorted[numberNotes] = cursorPosPpq - startppq          -- put distance to cursor in index position of sorting table
            end -- is note under cursor?
          end -- for notes, from back to front
        end -- for each item under mouse
        
        if #showNotes then                                        -- if showNotes array is populated
          if reaper.HasExtState(extName, 'stepIncr') then         -- update display, called from child scripts
            step = step + 1                                       -- proceed to next/previous note
            if step >= #showNotes then
              step = 0 
            end               -- if step exceeds number of notes, don't step
            reaper.DeleteExtState(extName, 'stepIncr', false)     -- delete stepIncr extstate
          end
          
          if reaper.HasExtState(extName, 'stepDown') then         -- update display, called from child scripts
            debug("STEP RESET", 1)
            step = 0
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
            if #showNotes == 1 then
              step = 0 
            end                 
            if #showNotes > i-1 + step then
              targetNoteIndex = showNotes[i + step][5]
              targetPitch = showNotes[i + step][1]                  -- get the pitch value of the closest note
            end                                        
          end
        end                                                
      end           -- if take is MIDI
    end
    
    table.sort(showNotes, function(a, b)                -- sort the shownotes table
      return a[1] < b[1]
    end)

    for i = #showNotes, 1, -1 do                        -- insert track names into ShowNotes
      if nm ~= "sequencer" then
        if showNotes[i][1] == targetPitch then
          if showNotes[i][8] == "" then
            showNotes[i][8] = getInstanceTrackName(showNotes[i][1])
          end
        end
      else
        if showNotes[i][8] == "" then
          showNotes[i][8] = getInstanceTrackName(showNotes[i][1])
        end
      end
    end
    
    mouseTrPos = reaper.GetMediaTrackInfo_Value(track, 'I_TCPY') 
    
    if targetNoteIndex then 
      local _, _, targetMute, targetPPQ, targetEndPPQ, _, _, _= reaper.MIDI_GetNote(mouseTake, targetNoteIndex) -- get note start/end position              
      targetNotePos = reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, targetPPQ)     -- get target note project time
      targetEndPos = reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, targetEndPPQ)   -- get target note end position
      track = reaper.GetMediaItemTake_Track(mouseTake)                            -- get track
      trPos = reaper.GetMediaTrackInfo_Value(track, 'I_TCPY')                -- y pos of track TCP
      tcpHeight = reaper.GetMediaTrackInfo_Value(track, 'I_TCPH')            -- get tcp height
    end 
    
    -------------------------------------------- set up extstate to communicate with other scripts
    local numVars = 9                                             -- see below
    reaper.SetExtState(extName, 0, step, false)                   -- how many variables are we sending via extstates
    reaper.SetExtState(extName, 1, numVars, false)                -- how many variables are we sending via extstates
    reaper.SetExtState(extName, 2, #showNotes, false)             -- how many notes are under mouse
    local guidString = reaper.BR_GetMediaItemTakeGUID(mouseTake)  -- get guidString from take
    reaper.SetExtState(extName, 3, tostring(guidString), false)   -- what take is under mouse
    
    if targetNoteIndex ~= nil and targetPitch ~= nil then         -- if there is a note undermouse?
      reaper.SetExtState(extName, 4, targetPitch, false)          -- what is the target pitch under mouse
      reaper.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    elseif targetNoteIndex == nil then                            -- if no note undermouse
      targetNoteIndex = -1                                        -- set to inapplicable value
      step = 0                                                    -- reset step interval
      reaper.DeleteExtState(extName, 4, false)                    -- what is the target pitch under mouse
      reaper.SetExtState(extName, 'step', step, false)            -- adjust step extstate
      reaper.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    end

    -- NOTE: extState 6 = +, - incrIndex. extState 7 = incr Value
    for i = 1, #showNotes do                             -- send off the table after all of the other variables
      showNotes[i][9] = tostring(showNotes[i][9])
      reaper.SetExtState(extName, i + numVars, table.concat(showNotes[i],","), false)
    end
    return mouseTake, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos, targetMute, mouseTake, mouseTrPos, spread
  end
  
end

