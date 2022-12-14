--[[
 * ReaScript Name: Razor Edit Control Functions
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.03
--]]

-- README: select "new instance" for repetitive triggering of child actions.
 
--[[
 * Changelog:
  
 * v1.1 (2022-12-xx)
    + edit MIDI with REs
    
 * v1.02 (2021-04-03)
   + more cleanup and attribution
   + fixed "toggle mute RE contents or selected items"
 
 * v1.01 (2021-04-02)
   + cleanup, slight nod toward documentation
   + added "toggle mute RE contents or selected items"
   
 * v1.0 (2021-03-22)
   + Initial Release
--]]

---------------------------------------------------------------------
 --[[------------------------------[[--
     Event trigger params from child scripts          
    --]]------------------------------]]--

function SetGlobalParam(job, param, clear, incr)   -- still deciding exactly how best to pass params/commands.
  reaper.ClearConsole()
  if clear == 1 then unselectAllMIDIinTrack() end     -- deselect MIDI in every item on selected track
  
  if job == 1 then MIDINotesInRE(param) end            -- run RE-MIDI edit task
  if job == 2 then muteREcontents() end
  if job == 3 then moveREbyVisibleGrid(incr) end
  if job == 4 then moveREwithcursor(incr) end
  if job == 5 or job == 6 then resizeREbyVisibleGrid(job, incr) end
  
  --if param == 3 then resizeREvertically(incr) end decommissioned


end

  
---------------------------------------------------------------------
    --[[------------------------------[[--
          do stuff to notes in RE   -- mccrabney        
    --]]------------------------------]]--

function MIDINotesInRE(task)

  local ppqIncr = 100    -- how many ppq to nudge MIDI notes
  local mouseNote        -- note under mouse cursor
  local doWhat = task    -- which edit is being performed
  
  --------------------------------------------------  
  -- get last touched note from MIDI examine JS on indicator track
  --------------------------------------------------

  for i = 1, reaper.CountTracks(0) do   -- find track "inq", check "JS: MIDI examine"
    findinq = reaper.GetTrack(0,i-1)
    _, inq = reaper.GetSetMediaTrackInfo_String( findinq, 'P_NAME', '', 0 )
    if inq:lower():find("inq") then
      lastNoteHit = reaper.TrackFX_GetParam(findinq, 1, 2)  -- what note was last hit
    end
  end                 -- lastNoteHit is a referenced variable for edits
  
  --------------------------------------------------
  -- get the value of the note under the mouse cursor
  --------------------------------------------------

  window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
  if details == "item" or inline_editor then -- hovering item in arrange
    mouseTake = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
    if reaper.TakeIsMIDI(mouseTake) then -- is take MIDI?
      local item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
      local mouse_position_ppq = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, mouse_pos) -- convert to PPQ
      notesCount, _, _ = reaper.MIDI_CountEvts(mouseTake) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(mouseTake, n) -- get note start/end position              
        if startppq <= mouse_position_ppq and endppq >= mouse_position_ppq then 
          mouseNote = pitch
        end
      end
    end 
  end                -- mouseNote and mouseTake are referenced variables for edits

  ---------------------------------------------------
  --check each RE for MIDI takes and apply edits to them 
  --------------------------------------------------- 
  
  if RazorEditSelectionExists() then      -- only apply edit to REs. maybe include "enclose item in RE" if no REs yet?  
    local areas = GetRazorEdits()         -- get all areas 
    
    for i = 1, #areas do                   -- for each razer edit, get each item
      local areaData = areas[i]
      if not areaData.isEnvelope then
        local items = areaData.items        
        local start_pos = areaData.areaStart  
        local end_pos = areaData.areaEnd
        
        for j = 1, #items do                -- for each item, 
          local item = items[j]
            --for t = reaper.CountTakes(item)-1, 0, -1 do     
            for t = 0, reaper.CountTakes(item)-1 do             -- for each take,
              take = reaper.GetTake(item, t)
               
              if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
                razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, start_pos) 
                razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, end_pos) 
                notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take                    
                for n = notesCount-1, 0, -1 do         --- for each note, starting with last in item
                  _, _, _, startppqposOut, endppqposOut, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note info
                  
  ----------------------------------------------------------                
  -- the RE MIDI edits  ------------------------------------
                   
                   -- EDIT: delete lasthit notes whose noteons exist within Razor Edit
                  if doWhat == 0 then        
                    if lastNoteHit == pitch and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end
                
                  -- EDIT: delete all notes whose noteons exist within Razor Edit
                  elseif doWhat == 1 then   
                    if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end
                
                  -- EDIT: delete all notes greater/equal than lasthit whose noteons exist within Razor Edit
                  elseif doWhat == 2 then   
                    if pitch >= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end
                
                  -- EDIT: delete all notes less/equal than lasthit whose noteons exist within Razor Edit
                  elseif doWhat == 3 then   
                    if pitch <= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end 
                
                  -- EDIT: delete all but the lasthit notes whose noteons exist within Razor Edit
                  elseif doWhat == 4 then   
                    if pitch ~= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end                    
                
                  -- EDIT: select all notes whose noteons exist within Razor Edit
                  elseif doWhat == 5 then
                    if pitch ~= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_SetNote( take, n, true, nil, nil, nil, nil, nil, nil, nil) 
                    end
                
                  -- EDIT: nudge notes whose noteons exist within Razor Edit forwards
                  elseif doWhat == 6 then
                    if pitch ~= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+ppqIncr, endppqposOut+ppqIncr, nil, nil, nil, nil) 
                    end

                  -- EDIT: nudge notes whose noteons exist within Razor Edit backwards
                  elseif doWhat == 7 then  
                    if pitch ~= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut-ppqIncr, endppqposOut-ppqIncr, nil, nil, nil, nil) 
                    end
                
                  -- EDIT: delete all notes whose noteons AND noteoffs exist within Razor Edit
                  elseif doWhat == 8 then   
                    if startppqposOut >= razorStart_ppq_pos and endppqposOut < razorEnd_ppq_pos then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end
                    
                  -- EDIT: delete all notes below/equal than note under mouse cursor whose noteons exist within Razor Edit
                  elseif doWhat == 9 then   
                    if mouseNote ~= nil and
                      startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch > mouseNote then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end     
                    
                  -- EDIT: delete all notes above/equal than note under mouse cursor whose noteons exist within Razor Edit
                  elseif doWhat == 10 then   
                    if mouseNote ~= nil and
                      startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch < mouseNote then 
                      reaper.MIDI_DeleteNote( take, n ) 
                    end    
                   
                  end   -- of doWhat switch section
              end       -- for each note
            end         -- if it's MIDI
          end           -- for each take
        end             -- for each item
      end               -- if not Envelope
    end                 -- for each area
  end                   -- if RE   
  
  -- EDIT: select and copy all MIDI in REs
  if doWhat == 11 then copySelectedMIDIinRE() end -- select/copy notes in REs
  --reaper.UpdateArrange()
end                     -- end function MIDINotesInRE()
  
    
--------------------------------------------------------------------
    --[[------------------------------[[--
          unselect all MIDI notes -- mccrabney   
    --]]------------------------------]]--

function unselectAllMIDIinTrack()
  reaper.Main_OnCommand(41238, 0)    -- save item selection? isn't working
  selected_tracks_count = reaper.CountSelectedTracks(0)

  for i = 0, selected_tracks_count-1  do    --   for each track
    track_sel = reaper.GetSelectedTrack(0, i) -- get selected track i
    item_num = reaper.CountTrackMediaItems(track_sel) -- how many items

    for j = 0, item_num-1 do               -- for each item 
      item = reaper.GetTrackMediaItem(track_sel, j)  -- get item
      take = reaper.GetTake(item, 0)      -- get take
      if reaper.TakeIsMIDI(take) then     -- if it's MIDI,
        reaper.MIDI_SelectAll(take, 0)    -- deselect all MIDI notes
        
      end                                 -- if take is MIDI
    end                                   -- for each item
  end                                     -- for each selected track
  reaper.Main_OnCommand(41248, 0)         -- restore item selection?
end        -- function 

  
--------------------------------------------------------------------
    --[[------------------------------[[--
          copy MIDI in RE -- mccrabney   
    --]]------------------------------]]--

function copySelectedMIDIinRE()
  MIDINotesInRE(5)                        -- select RE-enclosed notes
  if RazorEditSelectionExists() then      -- if RE exists
    local areas = GetRazorEdits()         -- get all areas 
    local areaData = areas[1]             -- look at the first area
    if not areaData.isEnvelope then       -- if not envelope
      local items = areaData.items        -- get area items
      local item = items[1]               -- get first item
      local take = reaper.GetTake(item, 0)   -- get first take
      if reaper.TakeIsMIDI(take) then     -- if it's MIDI,
        reaper.SetMediaItemSelected(item, 1) -- select the first item
        reaper.Main_OnCommand(40153, 0)    -- open MIDI editor for selected item
        local activeEditor = reaper.MIDIEditor_GetActive()
        reaper.MIDIEditor_OnCommand(activeEditor, 40010)   -- copy selected notes from inside ME
        reaper.MIDIEditor_OnCommand(activeEditor, 40794 )   -- close the ME
        
      end                                 -- if it's MIDI
    end                                   -- if not Envelope
  end                                     -- if RE  
end                                       -- function

--------------------------------------------------------------------
    --[[------------------------------[[--
          Get Razor Edit info --thanks, BirdBird!   
    --]]------------------------------]]--

function literalize(str)
  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

function GetGUIDFromEnvelope(envelope)
  local ret2, envelopeChunk = reaper.GetEnvelopeStateChunk(envelope, "")
  local GUID = "{" ..  string.match(envelopeChunk, "GUID {(%S+)}") .. "}"
    return GUID
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          Get Items, envelope points in Range -- thanks, BirdBird and amagalma!          
    --]]------------------------------]]--

local function leq( a, b ) -- a less than or equal to b
  return a < b + 0.00001
end

local function geq( a, b ) -- a greater than or equal to b
  return a + 0.00001 > b 
end

local function GetItemsInRange(track, areaStart, areaEnd)
  local items, it = {}, 0
  for k = 0, reaper.CountTrackMediaItems(track) - 1 do 
    local item = reaper.GetTrackMediaItem(track, k)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemEndPos = pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        --check if item is in area bounds
    if geq(pos, areaEnd) or leq(itemEndPos, areaStart) then
      -- outside, do nothing
    else -- inside
      it = it + 1
      items[it] = item
    end
  end
  return items
end

function GetEnvelopePointsInRange(envelopeTrack, areaStart, areaEnd)
  local envelopePoints = {}
  for i = 1, reaper.CountEnvelopePoints(envelopeTrack) do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelopeTrack, i - 1)

    if time >= areaStart and time <= areaEnd then --point is in range
      envelopePoints[#envelopePoints + 1] = {
      id = i-1 ,
      time = time,
      value = value,
      shape = shape,
      tension = tension,
      selected = selected }
    end
  end
  return envelopePoints
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          Set Track Razor Edit -- thanks, BirdBird!          
    --]]------------------------------]]--

function SetTrackRazorEdit(track, areaStart, areaEnd, clearSelection)
    if clearSelection == nil then clearSelection = false end
    
    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string, all this string stuff could probably be written better
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the track
        local j = 1
        while j <= #str do
            local GUID = str[j+2]
            if GUID == '""' then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit 
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ""'
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. '  ""'
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          Set Envelope Razor Edit  -- thanks, BirdBird!          
    --]]------------------------------]]--


function SetEnvelopeRazorEdit(envelope, areaStart, areaEnd, clearSelection, GUID)
    local GUID = GUID == nil and GetGUIDFromEnvelope(envelope) or GUID
    local track = reaper.Envelope_GetParentTrack(envelope)

    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the envelope
        local j = 1
        while j <= #str do
            local envGUID = str[j+2]
            if GUID ~= '""' and envGUID:sub(2,-2) == GUID then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ' .. GUID
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)

        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ' .. GUID
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          Get Razor Edits -- thanks, BirdBird!          
    --]]------------------------------]]--

function GetRazorEdits()
    local trackCount = reaper.CountTracks(0)
    local areaMap = {}
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        if area ~= '' then
            --PARSE STRING
            local str = {}
            for j in string.gmatch(area, "%S+") do
                table.insert(str, j)  
            end
        
            --FILL AREA DATA
            local j = 1
            while j <= #str do
                --area data
                local areaStart = tonumber(str[j])
                local areaEnd = tonumber(str[j+1])
                local GUID = str[j+2]
                local isEnvelope = GUID ~= '""'

                --get item/envelope data
                local items = {}
                local envelopeName, envelope
                local envelopePoints
                
                if not isEnvelope then
                    items = GetItemsInRange(track, areaStart, areaEnd)
                else
                    envelope = reaper.GetTrackEnvelopeByChunkName(track, GUID:sub(2, -2))
                    local ret, envName = reaper.GetEnvelopeName(envelope)

                    envelopeName = envName
                    envelopePoints = GetEnvelopePointsInRange(envelope, areaStart, areaEnd)
                end

                local areaData = {
                    areaStart = areaStart,
                    areaEnd = areaEnd,
                    
                    track = track,
                    items = items,
                    
                    --envelope data
                    isEnvelope = isEnvelope,
                    envelope = envelope,
                    envelopeName = envelopeName,
                    envelopePoints = envelopePoints,
                    GUID = GUID:sub(2, -2)
                }

                table.insert(areaMap, areaData)

                j = j + 3
            end
        end
    end

    return areaMap
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          split razor edits -- thanks, BirdBird!          
    --]]------------------------------]]--

function SplitRazorEdits(razorEdits)
    local areaItems = {}
    local tracks = {}
    reaper.PreventUIRefresh(1)
    for i = 1, #razorEdits do
        local areaData = razorEdits[i]
        if not areaData.isEnvelope then
            local items = areaData.items
            
            --recalculate item data for tracks with previous splits
            if tracks[areaData.track] ~= nil then 
                items = GetItemsInRange(areaData.track, areaData.areaStart, areaData.areaEnd)
            end
            
            for j = 1, #items do 
                local item = items[j]
                --split items 
                local newItem = reaper.SplitMediaItem(item, areaData.areaStart)
                if newItem == nil then
                    reaper.SplitMediaItem(item, areaData.areaEnd)
                    table.insert(areaItems, item)
                else
                    reaper.SplitMediaItem(newItem, areaData.areaEnd)
                    table.insert(areaItems, newItem)
                end
            end

            tracks[areaData.track] = 1
        end
    end
    reaper.PreventUIRefresh(-1)
    
    return areaItems
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          Does a Razor Edit exist? thanks, sonictim!          
    --]]------------------------------]]--

function RazorEditSelectionExists()

    for i=0, reaper.CountTracks(0)-1 do

        local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)

        if x ~= "" then return true end

    end--for
    
    return false

end--RazorEditSelectionExists()


---------------------------------------------------------------------
    --[[------------------------------[[--
         Get Visible Grid Division - thanks, amagalma!          
    --]]------------------------------]]--

function GetVisibleGridDivision()  ---- 
    reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
    reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
    local cursorpos = reaper.GetCursorPosition()
    local firstcursorpos = cursorpos
    local grid_duration
    
    if reaper.GetToggleCommandState( 41885 ) == 1 then -- Toggle framerate grid
        grid_duration = 0.4/reaper.TimeMap_curFrameRate( 0 )
    else
        local _, division = reaper.GetSetProjectGrid( 0, 0, 0, 0, 0 )
        local tmsgn_cnt = reaper.CountTempoTimeSigMarkers( 0 )
        local _, tempo
      
        if tmsgn_cnt == 0 then
            tempo = reaper.Master_GetTempo()
        else
            local active_tmsgn = reaper.FindTempoTimeSigMarker( 0, cursorpos )
            _, _, _, _, tempo = reaper.GetTempoTimeSigMarker( 0, active_tmsgn )
        end
        grid_duration = 60/tempo * division
    end
    
    local grid = cursorpos
    
    while (grid <= cursorpos) do
        cursorpos = cursorpos + grid_duration
        grid = reaper.SnapToGrid(0, cursorpos)
    end
    
    grid = grid-firstcursorpos
    reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
    --  reaper.defer(function() end)
    return grid

end -- GetVisibleGridDivision()


---------------------------------------------------------------------
    --[[------------------------------[[--
     In/Decrement Razor Edit Start/End by Visible Grid        
    --]]------------------------------]]--
    
function resizeREbyVisibleGrid(param, incr)    -- where param informs direction of movement
    gridval = GetVisibleGridDivision()
    
    if RazorEditSelectionExists() then
        local areas = GetRazorEdits()

        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart
            local aEnd = area.areaEnd

            if param == 0 then ---- if we are incrementing/decrementing RE end
                aEnd =  reaper.SnapToGrid(0, aEnd+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end
                end
            end    
            
            if param == 1 then ---- if we are incrementing/decrementing RE start
                aStart =  reaper.SnapToGrid(0, aStart+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end    
                end                                
            end --if param = 0
        end -- for
    else  -- RazorEditSelectionExists() -- create if not present  
         
        for i = 0, reaper.CountSelectedTracks(0)-1 do
            track = reaper.GetSelectedTrack(0, i)
            reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
            reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
            local cursorpos = reaper.GetCursorPosition()
            
            if param == 0 then 
                if incr == 1 then SetTrackRazorEdit(track, cursorpos, cursorpos+gridval, true) end 
            else
                if incr == -1 then SetTrackRazorEdit(track, cursorpos-gridval, cursorpos, true) end 
            end    
            
            reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
            -- reaper.defer(function() end)
        end
    end  -- RazorEditSelectionExists()
    --reaper.UpdateArrange() 
   -- reaper.defer(resizeREbyVisibleGrid)
end


---------------------------------------------------------------------
    --[[------------------------------[[--
        Move Razor Edit (and/or edit cursor) End by Visible Grid               
    --]]------------------------------]]--

function moveREbyVisibleGrid(incr)

    local direction = incr
    
    gridval = GetVisibleGridDivision()
    
    if RazorEditSelectionExists() then
        local test, position = GetRazorEdits()
        local areas = GetRazorEdits()
        
        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart 
            local aEnd = area.areaEnd
            local aLength = aEnd - aStart
            local cursorpos = reaper.GetCursorPosition()
            local grid=cursorpos
            aStart = reaper.SnapToGrid(0, aStart+gridval*incr)
            aEnd =  reaper.SnapToGrid(0, aEnd+gridval*incr)
            
            if area.isEnvelope then
                SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
            else
                SetTrackRazorEdit(area.track, aStart, aEnd, true)
                reaper.SetEditCurPos( aStart, true, false)
            end -- if area.isEnvelope
        end -- for
    else -- RazorEditSelectionExists( NO ):
        local cursorpos = reaper.GetCursorPosition()
        local grid = reaper.SnapToGrid(0, cursorpos+gridval*incr)
        reaper.SetEditCurPos(grid,1,1)
    end  
    reaper.UpdateArrange()
    
end


---------------------------------------------------------------------   
    --[[------------------------------[[--
        move RE and edit cursor forwards without contents 
    --]]------------------------------]]--

function moveREwithcursor(incr)

    local direction = incr
    if RazorEditSelectionExists() then
        if incr == 1 then reaper.Main_OnCommand(42399, 0) end -- move RE forwards without content
        if incr == -1 then reaper.Main_OnCommand(42400, 0) end -- backwards
         
        local test, position = GetRazorEdits()
        local areas = GetRazorEdits()
        
        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart 
            reaper.SetEditCurPos(aStart,1,1)
        end -- for
        
    else -- RazorEditSelectionExists( NO ):
        --local cursorpos = reaper.GetCursorPosition()
        --local grid = reaper.SnapToGrid(0, cursorpos+gridval*incr)
        
    end  
    reaper.UpdateArrange()
    
end


---------------------------------------------------------------------   
    --[[------------------------------[[--
        toggle mute RE contents or selected items  -- thanks, BirdBird!
    --]]------------------------------]]--

function muteREcontents()
    local areas = GetRazorEdits()
    items = SplitRazorEdits(areas)
    for j = 1, #items do 
        reaper.SetMediaItemSelected(items[j], true)
    end
    reaper.Main_OnCommand(40183, 0)  -- toggle mute
end


---------------------------------------------------------------------   
    --[[------------------------------[[--
                MAIN
    --]]------------------------------]]--
    
function Main()
end


---------------------------------------------------------------------
    --[[------------------------------[[--
                loop
    --]]------------------------------]]--
    
Main()
