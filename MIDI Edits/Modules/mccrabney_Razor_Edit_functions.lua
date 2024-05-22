--[[
 * @noindex
--]] 

---------------------------------------------------------------------
    --[[------------------------------[[--
        Event trigger params from child scripts          
    --]]------------------------------]]--

function SetGlobalParam(job, task, clear, val, incr)   -- get job and details from child scripts
  --reaper.ClearConsole()
  reaper.ShowConsoleMsg("SetGlobalParam" .. "\n")
  if clear == 1 then unselectAllMIDIinTrack() end     -- deselect MIDI in every item on selected track
  if job == 1 then MIDINotesInRE(task) end
  if job == 2 then muteREcontents() end                   -- RE movement/size controls
  if job == 3 then moveREbyVisibleGrid(incr) end
  if job == 4 then moveREwithcursor(val) end
  if job == 5 or                                        
     job == 6 then resizeREbyVisibleGrid(job, val) end
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          do edits to notes in RE   -- mccrabney        
    --]]------------------------------]]--    

noteHoldNumber = -1
function MIDINotesInRE(task)
  reaper.ShowConsoleMsg("MIDINotesInRE" .. "\n")
  local mouseNote                 -- note under mouse cursor
  local mouseTake                 -- take under mouse
  local mouseItem                 -- item under mouse
  local mouse_position_ppq        -- ppq pos of mouse at function call
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
  noteHoldNumber = tonumber(reaper.GetExtState(extName, 'noteHold' ))
  --reaper.ShowConsoleMsg(noteHoldNumber.. "\n")
  local count = 0
  local targetedNotes = 0
  reaper.PreventUIRefresh(1)
  
  if task == 9 or 10 then                -- if task is mouse-related,
    mouseNote, mouseTake, mouseItem, mouse_position_ppq = getMouseInfo()
  end
                  -- if it's not MIDI, or of there's no item under cursor, quit everything
  --if mouseTake ~= nil and reaper.TakeIsMIDI(mouseTake) == 0 then return end      
  
  if RazorEditSelectionExistsPlus(1, 1) then      -- if no razor edit, create one out of selected item                                         -- if no item is selected, select item under mouse 
    local areas = GetRazorEdits()          -- get all areas 
    for i = 1, #areas do                   -- for each razor edit, get each item
      local areaData = areas[i]
      if not areaData.isEnvelope then
        local items = areaData.items        
        local start_pos = areaData.areaStart  
        local end_pos = areaData.areaEnd
        
        for j = 1, #items do                           -- for each item, 
          local item = items[j]
          local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local itemEnd = itemStart+ reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                        
          for t = 0, reaper.CountTakes(item)-1 do       -- for each take,
            take = reaper.GetTake(item, t)              -- get take
            if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
              itemStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, itemStart) 
              itemEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, itemEnd) 
              razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, start_pos) 
              razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, end_pos) 
              notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take                    
              doOnce = 0 
 
              -----------------------------------------------------------------------                
              -- the MIDI task switch section: performs edits on MIDI in RE selection 
              ----------------------------------------------------------------------- 
              
              -- EDIT: nudge notes whose noteons exist within Razor Edit backwards 
              if task == 6 and incr < 0 then
                for n = 0, notesCount do         --- for each note, starting with first in item
                  _, _, muted, startppqposOut, endppqposOut, _, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note info
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then
                    if noteHoldNumber == -1 then
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+incr, endppqposOut+incr, nil, nil, nil, nil) 
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+incr, endppqposOut+incr, nil, nil, nil, nil) 
                    end
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "nudge notes in REs"
                  end
                end
              end
              
              for n = notesCount-1, 0, -1 do         --- for each note, starting with last in item
                _, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note info
                
              -- delete notes with razor edits:
                
                  -- EDIT: delete all notes whose noteons exist within Razor Edit
                if task == 1 then   
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    if noteHoldNumber == -1 then
                      reaper.MIDI_DeleteNote( take, n )
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_DeleteNote( take, n )
                    end
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes in RE"
                  end
                
                -- EDIT: delete all notes greater/equal than last-hit whose noteons exist within Razor Edit
                elseif task == 2 then   
                  if pitch >= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes higher than lasthit in RE" 
                  end
                
                -- EDIT: delete all notes less/equal than last-hit whose noteons exist within Razor Edit
                elseif task == 3 then   
                  if pitch <= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes lower than lasthit in RE" 
                  end 

                -- EDIT: delete all notes whose noteons AND noteoffs exist within Razor Edit
                elseif task == 8 then   
                  if startppqposOut >= razorStart_ppq_pos and endppqposOut < razorEnd_ppq_pos then 
                    if noteHoldNumber == -1 then
                      reaper.MIDI_DeleteNote( take, n )
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_DeleteNote( take, n )
                    end                    
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes contained within RE" 
                  end
                    
                -- EDIT: delete all notes < note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 9 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch > mouseNote then 
                    reaper.MIDI_DeleteNote( take, n )
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes <= note under mouse cursor in RE" 
                  end     
                    
                -- EDIT: delete all notes > note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 10 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch < mouseNote then 
                    reaper.MIDI_DeleteNote( take, n ) 
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "delete notes >= note under mouse cursor in RE" 
                  end
                  
                -- EDIT: delete all notes <= note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 15 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch >= mouseNote then 
                    reaper.MIDI_DeleteNote( take, n )
                    undoMessage = "delete notes <= note under mouse cursor in RE" 
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      

                  end     
                    
                -- EDIT: delete all notes >= note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 16 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch <= mouseNote then 
                    reaper.MIDI_DeleteNote( take, n ) 
                    undoMessage = "delete notes >= note under mouse cursor in RE" 
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    
                  end
                                    
           -----------------------------------------------------------------------
              -- select notes with razor edits:
                         
                -- EDIT: select all notes whose noteons exist within Razor Edit
                elseif task == 5 then
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    if noteHoldNumber == -1 then
                      reaper.MIDI_SetNote( take, n, true, nil, nil, nil, nil, nil, nil, nil)
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_SetNote( take, n, true, nil, nil, nil, nil, nil, nil, nil)
                    end
                  end
                  undoMessage = "select all notes in RE"
                  
           -----------------------------------------------------------------------
              -- nudge notes with razor edits:
              
                -- EDIT: nudge notes whose noteons exist within Razor Edit forwards 
               elseif task == 6 and incr > 0 then
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    if noteHoldNumber == -1 then                    
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+incr, endppqposOut+incr, nil, nil, nil, nil) 
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+incr, endppqposOut+incr, nil, nil, nil, nil) 
                    end
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    if n == 0 then undoMessage = "nudge notes in REs" end
                  end

                -- EDIT: nudge noteoffs whose noteons exist within Razor Edit forwards and backwards
                elseif task == 18 then  
                  --reaper.ShowConsoleMsg(incr .. "\n")
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    if noteHoldNumber == -1 then                    
                      reaper.MIDI_SetNote( take, n, nil, nil, nil, endppqposOut+incr, nil, nil, nil, nil)
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_SetNote( take, n, nil, nil, nil, endppqposOut+incr, nil, nil, nil, nil)
                    end
                    undoMessage = "adjust length of notes in RE" 
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                  end
                  
              -- toggle mute notes with razor edits:
                elseif task == 17 then  
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    if noteHoldNumber == -1 then                    
                      if muted == false then reaper.MIDI_SetNote( take, n, nil, true, nil, nil, nil, nil, nil, nil)
                      else reaper.MIDI_SetNote( take, n, nil, false, nil, nil, nil, nil, nil, nil)
                      end
                    elseif noteHoldNumber == pitch then
                      if muted == false then reaper.MIDI_SetNote( take, n, nil, true, nil, nil, nil, nil, nil, nil)
                      else reaper.MIDI_SetNote( take, n, nil, false, nil, nil, nil, nil, nil, nil)
                      end
                    end
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "mute notes in RE" 
                  end
                  
                -- EDIT: change velocity of notes whose noteons exist within Razer Edits
                elseif task == 20 then  
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    vel = vel+incr
                    if vel > 127 then vel = 127 end
                    if vel < 1 then vel = 1 end
                    if noteHoldNumber == -1 then                    
                      reaper.MIDI_SetNote( take, n, nil, nil, nil, nil, nil, nil, vel)
                    elseif noteHoldNumber == pitch then
                      reaper.MIDI_SetNote( take, n, nil, nil, nil, nil, nil, nil, vel)
                    end
                    reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                    undoMessage = "changed velocity of notes in REs"
                  end       

                -- EDIT: transpose notes whose noteons exist within Razer Edits
                elseif task == 21 then
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and noteHoldNumber ~= -1 and sel == true
                  or startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and noteHoldNumber == -1 then 
                    local ogPitch = pitch
                    pitch = pitch + incr
                    if pitch > 127 then pitch = 127 end
                    if pitch < 0 then pitch = 0 end
                    reaper.MIDI_SetNote( take, n, nil, nil, nil, nil, nil, pitch, nil)
                    undoMessage = "transposed notes in REs"
                    if noteHoldNumber == ogPitch then
                      reaper.SetExtState(extName, "noteHold", pitch, false)
                      reaper.SetExtState(extName, "noteHoldUpdate", incr, false)
                      reaper.SetExtState(extName, 'DoRefresh2', '1', false)      
                    end
                  end
                    
                -- split notes whose noteons exist within Razor Edit at mouse cursor
                elseif task == 7 then   
                  if cursorSource == 1 then
                    cursorPos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
                  else
                    cursorPos = reaper.GetCursorPosition()   -- get pos at edit cursor
                  end
                  editCursor_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert project time to PPQ
                  if startppqposOut < editCursor_ppq_pos and editCursor_ppq_pos < endppqposOut then
                    reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut, editCursor_ppq_pos-96, nil, nil, nil, nil)
                    reaper.MIDI_InsertNote( take, sel, 0, editCursor_ppq_pos, endppqposOut, chan, pitch, vel, nil)
                    reaper.MIDI_Sort(take)
                  end  
                  reaper.SetExtState(extName, 'DoRefresh', '1', false)      
                  undoMessage = "split notes" 
                end     -- of MIDI task switch section
              end       -- for each note   
              
           -----------------------------------------------------------------------                
              reaper.MIDI_Sort( take )      -- run once after MIDI task switch section
                                            -- not sure i'm using this correctly
              reaper.UpdateArrange()        
              
            end         -- if it's MIDI
          end           -- for each take
        end             -- for each item
      end               -- if not Envelope
    end                 -- for each area
  end                   -- if RE   

  
  -- EDIT: select and copy all MIDI in REs -- occurs here after note-by-note edit switch above
  if task == 11 then copySelectedMIDIinRE()
    undoMessage = "select/copy all notes in RE"
  end                                       -- select/copy notes in REs
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  if undoMessage ~= nil then reaper.Undo_OnStateChange2(proj, undoMessage) end
end                                         -- end function MIDINotesInRE()

---------------------------------------------------------------------
    --[[------------------------------[[--
          get note, take, item, and ppq position under mouse   -- mccrabney      
    --]]------------------------------]]--
    
function getMouseInfo()
  reaper.ShowConsoleMsg("getMouseInfo" .. "\n")
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


--------------------------------------------------------------------
    --[[------------------------------[[--
          unselect all MIDI notes -- mccrabney   
    --]]------------------------------]]--

function unselectAllMIDIinTrack()
  --reaper.ShowConsoleMsg("unselectAllMIDIinTrack")
  reaper.Main_OnCommand(41238, 0)         -- save item selection? isn't working
  selected_tracks_count = reaper.CountSelectedTracks(0)

  for i = 0, selected_tracks_count-1  do   --   for each track
    track_sel = reaper.GetSelectedTrack(0, i) -- get selected track i
    item_num = reaper.CountTrackMediaItems(track_sel) -- how many items

    for j = 0, item_num-1 do              -- for each item 
      item = reaper.GetTrackMediaItem(track_sel, j)  -- get item
      take = reaper.GetTake(item, 0)      -- get take
      if reaper.TakeIsMIDI(take) then     -- if it's MIDI,
        reaper.MIDI_SelectAll(take, 0)    -- read MIDI editor settings requirements below
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
  --reaper.ShowConsoleMsg("")
  reaper.PreventUIRefresh(1)
  MIDINotesInRE(5)                            -- select RE-enclosed notes
  if RazorEditSelectionExistsPlus(0,1) then       -- if RE exists (don't make if not) -- unnecessary?
    local areas = GetRazorEdits()             -- get all areas 
    local areaData = areas[1]                 -- look at the first area
    local aStart
    local aEnd
    
    for i=1, #areas do                      -- for each area
      local area = areas[i];
      aStart = area.areaStart
      aEnd = area.areaEnd
    end
    
    razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, aStart) 
    razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, aEnd)     
    if not areaData.isEnvelope then           -- if not envelope
      local items = areaData.items            -- get area items
      local item = items[1]                   -- get first item
      local take = reaper.GetTake(item, 0)    -- get first take
      if reaper.TakeIsMIDI(take) then         -- if it's MIDI,
        --reaper.MIDI_InsertCC( take, 1, 0, razorStart_ppq_pos, 191, 16, 119, 1 )
        reaper.SetMediaItemSelected(item, 1)  -- select the first item
        reaper.Main_OnCommand(40153, 0)       -- open MIDI editor for selected item
        --local windowHWND = reaper.JS_Window_GetFocus()
        --reaper.JS_Window_SetOpacity( windowHWND, alpha, 50 )
        --reaper.MIDI_InsertNote( take, 1, 0, razorStart_ppq_pos, razorStart_ppq_pos+100, 16, 0, 1, nil)
        reaper.MIDI_InsertCC( take, 1, 0, razorStart_ppq_pos, 191, 15, 119, 1 )
        reaper.MIDI_InsertCC( take, 1, 0, razorEnd_ppq_pos, 191, 15, 119, 1 )
        
        reaper.MIDI_Sort(take)
        local activeEditor = reaper.MIDIEditor_GetActive()
        reaper.MIDIEditor_OnCommand(activeEditor, 40010)   -- copy selected notes from inside ME
        reaper.MIDIEditor_OnCommand(activeEditor, 40794 )   -- close the ME
        
            -- note copying is done this way because ME must be open in order for action to be run.
            -- in order to set MIDI clipboard to include MIDI from multiple editable items
            -- this results in an undesirable flicker as the MIDI editor opens and closes.
      end                                 -- if it's MIDI
    end                                   -- if not Envelope
  end                                     -- if RE  
  reaper.PreventUIRefresh(-1)
end                                       -- function


---------------------------------------------------------------------
    --[[------------------------------[[--
     Incr/Decrement Razor Edit Start/End by Visible Grid     - mccrabney      
    --]]------------------------------]]--
    
function resizeREbyVisibleGrid(job, incr)    -- where param informs direction of movement
  reaper.PreventUIRefresh(1)
  gridval = GetVisibleGridDivision()
  if RazorEditSelectionExistsPlus(0) then      -- if a razor edit exists (else donothing)
    local areas = GetRazorEdits()
    for i=1, #areas do                      -- for each area
      local area = areas[i];
      local aStart = area.areaStart
      local aEnd = area.areaEnd

      if job == 5 then                  -- if we are incrementing/decrementing RE end
        aEnd = reaper.SnapToGrid(0, aEnd+gridval*incr) --increment/decrement by grid
        if aEnd > aStart then
          if area.isEnvelope then
            SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
          else                      -- if not envelope
            SetTrackRazorEdit(area.track, aStart, aEnd, true) 
          end   -- is envelope or track RE   
        end     -- if aEnd > aStart
      end       -- if job 5
    
      if job == 6 then               -- if we are incrementing/decrementing RE start
        aStart =  reaper.SnapToGrid(0, aStart+gridval*incr) --increment/decrement by grid
        if aEnd > aStart then
          if area.isEnvelope then
            SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
          else
            SetTrackRazorEdit(area.track, aStart, aEnd, true) 
          end   -- is envelope or track RE   
        end     -- if aEnd > aStart                                
      end       -- if job == 6
    end         -- for all RE areas
      
  else           -- if no RE, create a grid-sized RE 
    local track
    local cursorpos = reaper.GetCursorPosition()
    reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
    reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
          
    for i = 0, reaper.CountSelectedTracks(0)-1 do
      track = reaper.GetSelectedTrack(0, i)
    end           -- for each track
    
    if job == 5 then               -- moving RE end
      if incr == 1 then 
        SetTrackRazorEdit(track, cursorpos, cursorpos+gridval, true)
      else
        if incr == -1 then SetTrackRazorEdit(track, cursorpos-gridval, cursorpos, true) end
      end         
    elseif job == 6 then         -- moving RE start
      if incr == 1 then 
        SetTrackRazorEdit(track, cursorpos, cursorpos+gridval, true)
      else
        if incr == -1 then SetTrackRazorEdit(track, cursorpos-gridval, cursorpos, true) end
      end             
    end           -- if job   
    
    reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
  end  -- RazorEditSelectionExists()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange() 
  reaper.Undo_OnStateChange2(proj, "change RE start/end by visible grid")
  
end


---------------------------------------------------------------------
    --[[------------------------------[[--
        Move Razor Edit (and/or edit cursor) End by Visible Grid   - mccrabney            
    --]]------------------------------]]--

function moveREbyVisibleGrid(incr)
  --reaper.PreventUIRefresh(1)
  --reaper.PreventUIRefresh(-1)
  local direction = incr
  gridval = GetVisibleGridDivision()
    
  if RazorEditSelectionExistsPlus(0) then
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
      end           -- if area.isEnvelope
    end             -- for all areas
    
    else -- RazorEditSelectionExists( NO ):
      local cursorpos = reaper.GetCursorPosition()
      local grid = reaper.SnapToGrid(0, cursorpos+gridval*incr)
      reaper.SetEditCurPos(grid,1,1)
    end  
    reaper.UpdateArrange()
    reaper.Undo_OnStateChange2(proj, "move RE/edit cursor by visible grid")
end


---------------------------------------------------------------------   
    --[[------------------------------[[--
        move RE and edit cursor forwards without contents 
    --]]------------------------------]]--

function moveREwithcursor(incr)
    --reaper.PreventUIRefresh(1)
    --reaper.PreventUIRefresh(-1)
    local direction = incr
    if RazorEditSelectionExistsPlus(0) then
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
    reaper.Undo_OnStateChange2(proj, "move RE with cursor without contents")
    
end




---------------------------------------------------------------------
-- Below are useful RE functions contributed by talented REAPER users.
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
    reaper.UpdateArrange()
    reaper.Undo_OnStateChange2(proj, "toggle mute RE contents or selected items")
end


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
  reaper.ShowConsoleMsg("GetItemsInRange" .. "\n")  
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

-----------------------------------------------------------
    --[[------------------------------[[--
         razor edit functions - thanks, BirdBird
    --]]------------------------------]]--
    

function RazorEditSelectionExists()
  reaper.ShowConsoleMsg("RazorEditSelectionExists" .. "\n") 
  for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end              -- if present, return true 
    if x == nil then return false end            -- return that no RE exists
  end
  
end    

------------------------------------

function GetRazorEdits()
  reaper.ShowConsoleMsg("GetRazorEdits" .. "\n")
  local trackCount = reaper.CountTracks(0)
  local areaMap = {}
  for i = 0, trackCount - 1 do
    local track = reaper.GetTrack(0, i)
    local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    if area ~= '' then            --PARSE STRING
      local str = {}
      for j in string.gmatch(area, "%S+") do table.insert(str, j) end
      local j = 1
      while j <= #str do                --area data
        local areaStart = tonumber(str[j])
        local areaEnd = tonumber(str[j+1])
        local GUID = str[j+2]
        local isEnvelope = GUID ~= '""'
        local items = {}            --get item/envelope data
        local envelopeName, envelope
        local envelopePoint
        if not isEnvelope then
          items = GetItemsInRange(track, areaStart, areaEnd)
        else
          --envelope = reaper.GetTrackEnvelopeByChunkName(track, GUID:sub(2, -2))
          --local ret, envName = reaper.GetEnvelopeName(envelope)
          --envelopeName = envName
          --envelopePoints = GetEnvelopePointsInRange(envelope, areaStart, areaEnd)
        end

        local areaData = {
          areaStart = areaStart,  areaEnd = areaEnd,
          track = track,  items = items,
          isEnvelope = isEnvelope,    --envelope data
          envelope = envelope,  envelopeName = envelopeName,
          envelopePoints = envelopePoints,  GUID = GUID:sub(2, -2)
        }

        table.insert(areaMap, areaData)
        j = j + 3
      end
    end
  end

  return areaMap
end

extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'  
extNameB = 'mccrabney: target notes'  



---------------------------------------------------------------------
    --[[------------------------------[[--
          Set Track Razor Edit -- thanks, BirdBird!          
    --]]------------------------------]]--

function SetTrackRazorEdit(track, areaStart, areaEnd, clearSelection)
  reaper.ShowConsoleMsg("SetTrackRazorEdit" .. "\n")    
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
          RE exist? if not/if desired, create them  -- thanks, sonictim and julian sader!          
    --]]------------------------------]]--

function RazorEditSelectionExistsPlus(make,itemType)    ---itemType: 0 for audio, 1 for MIDI
  reaper.ShowConsoleMsg("RazorEditSelectionExistsPlus" .. "\n")  
  reaper.Undo_BeginBlock2(0)          -- make them from selected items.
  local midiFlag = 0
  local itemUnderMouse
  local itemCount = reaper.CountSelectedMediaItems(0)  -- how many items are selected

  if itemCount == 0 then                               -- if none,
    _, _, itemUnderMouse, _ = getMouseInfo()           -- get item under mouse
    if itemUnderMouse ~= nil then 
      reaper.SetMediaItemSelected( itemUnderMouse, true )  -- set it selected
      itemCount = 1
    end                                        -- update item count
  end
  
  for i=0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end            -- if present, return true
  end                                          -- end for each track
    
  if x == nil and make == 1 and itemCount ~= 0 then  -- if no RE, but one is needed,
    --if itemUnderMouse ~= nil then
      tS = {}
      for i = 0, itemCount -1 do               -- for each selected item
        item = reaper.GetSelectedMediaItem(0, i)      -- get its dimensions
        take = reaper.GetActiveTake(item)
        if reaper.TakeIsMIDI(take) then midiFlag = 1 end
        left = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        right = left + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        track = reaper.GetMediaItemTrack(item)
        tS[track] = (tS[track] or "") .. string.format([[%.16f %.16f "" ]], left, right)
      end
    
      for track, str in pairs(tS) do
        if itemType == 1 and midiFlag == 1 then          -- if MIDI and MIDI is present
          reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str, true)
        end
        if itemType == 0 and midiFlag == 0 then          -- if audio and MIDI is not present
          reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str, true)
        end
        if itemType == 0 and midiFlag == 1 then return false end     -- if audio and MIDI is present
        if itemType == 1 and midiFlag == 0 then return false end     -- if MIDI and MIDI not present

      end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, "Enclose items in minimal razor areas", -1)
    return true                    -- return that yes, RE exists now
  
    else if x == nil and make == 0 then
      return false 
    end                  -- return that no RE exists
  end                               -- end if/else
end                                 -- end RazorEditSelectionExists()


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
   
  --position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos) -- convert to PPQ
  
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
    --local val = 60/tempo
    --reaper.ShowConsoleMsg(val)
    grid_duration = 60/tempo * division
  end
    
  local grid = cursorpos
    
  while (grid <= cursorpos) do
    cursorpos = cursorpos + grid_duration
    grid = reaper.SnapToGrid(0, cursorpos)
  end
    
  grid = grid-firstcursorpos
  reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
  return grid   -- grid is in seconds. 

end -- GetVisibleGridDivision()





