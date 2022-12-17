--[[
 * ReaScript Name: Razor Edit Control Functions
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.05
--]]

--[[
 * Changelog:
 
 * v1.05 (2022-12-17)
    + general cleanup, excessive comments in code
    + an attempt to use MIDI_Sort properly
    + RE movement: added undo points 
    + MIDI edits: added "select last hit notes in RE"
    + MIDI edits: if no REs exist, enclose selected items in RE then run edit
    + MIDI edits: nudge last-hit note in RE 
    
 * v1.04 (2022-12-16)
    + added "lastnote" reference function

 * v1.03 (2022-12-14)
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


-- README: 
--    these functions will perform various edits on REs. 
--    some MIDI actions look for a "last hit note" to use for the edits.
--        if not already present, a reference track will be created for this. 
--    for "running in background" message, select "new instance" and "remember my answer for this script" 
--    change the ppqIncr value for a different nudge amount

-- TODO: 
--    see if the MIDI editor flash that occurs during "Copy Notes in REs" can be suppressed
--    remove AI from RE areas - ultraschall
--    suppress UI updates for RE moving/resizing controls
--    resize REs to include new space when nudging?


dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

---------------------------------------------------------------------
 --[[------------------------------[[--
     Event trigger params from child scripts          
    --]]------------------------------]]--

function SetGlobalParam(job, param, clear, incr)   -- get job and details from child scripts
  
  reaper.ClearConsole()
  if clear == 1 then unselectAllMIDIinTrack() end     -- deselect MIDI in every item on selected track
  
  if param == 0 or param == 2 or param ==3 or param ==4 or param == 13 or param == 14
    then lastNoteHit = getLastNoteHit() end    -- sloppy. if commands require lastHit value, get it
      
  if job == 1 then MIDINotesInRE(param)  end            -- run specific RE-MIDI edit task
  
  if job == 2 then muteREcontents() end                 -- RE movement/size controls
  if job == 3 then moveREbyVisibleGrid(incr) end
  if job == 4 then moveREwithcursor(incr) end
  if job == 5 or                                        
     job == 6 then resizeREbyVisibleGrid(job, incr) end
  
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          do edits to notes in RE   -- mccrabney        
    --]]------------------------------]]--

function MIDINotesInRE(task)
  
  local ppqIncr = 100    -- how many ppq to nudge MIDI notes
  local mouseNote        -- note under mouse cursor
  
  --------------------------------------------------
  -- get the value of the note under the mouse cursor  -- should this be its own function?
  --------------------------------------------------
  
  if task == 9 or task == 10 then                       -- if task is mouse-related,
    window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
    local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
    if details == "item" or inline_editor then         -- hovering over item in arrange
      mouseTake = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
      if reaper.TakeIsMIDI(mouseTake) then -- is take MIDI?
        local item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
        local mouse_position_ppq = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, mouse_pos) -- convert to PPQ
        local notesCount, _, _ = reaper.MIDI_CountEvts(mouseTake) -- count notes in current take
        for n = notesCount-1, 0, -1 do
          _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(mouseTake, n) -- get note start/end position              
          if startppq <= mouse_position_ppq and endppq >= mouse_position_ppq then 
            mouseNote = pitch
          end
        end
      end 
    end                
  end                   -- mouseNote and mouseTake are referenced variables for edits
  
  ---------------------------------------------------
  --check each RE for MIDI takes and apply edits to them 
  --------------------------------------------------- 
  if RazorEditSelectionExists(1) then      -- if no razor edit, create one
  
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
                        
          for t = 0, reaper.CountTakes(item)-1 do      -- for each take,
            take = reaper.GetTake(item, t)
               
            if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
              itemStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, itemStart) 
              itemEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, itemEnd) 
              
              razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, start_pos) 
              razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, end_pos) 
              notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take                    
              for n = notesCount-1, 0, -1 do         --- for each note, starting with last in item
                _, _, _, startppqposOut, endppqposOut, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note info
                
           -----------------------------------------------------------------------                
           -- the MIDI task switch section, performs edits on MIDI in RE selection 
           -----------------------------------------------------------------------
              -- delete notes with razor edits:
              
                 -- EDIT: delete lasthit notes whose noteons exist within Razor Edit
                if task == 0 then
                  if lastNoteHit == pitch and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n ) 
                    if n == 0 then undoMessage = "delete lasthit notes in RE" end 
                  end
                
                  -- EDIT: delete all notes whose noteons exist within Razor Edit
                elseif task == 1 then   
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    if n == 0 then undoMessage = "delete notes in RE" end 
                  end
                
                -- EDIT: delete all notes greater/equal than lasthit whose noteons exist within Razor Edit
                elseif task == 2 then   
                  if pitch >= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    if n == 0 then undoMessage = "delete notes higher than lasthit in RE" end
                  end
                
                -- EDIT: delete all notes less/equal than lasthit whose noteons exist within Razor Edit
                elseif task == 3 then   
                  if pitch <= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    if n == 0 then undoMessage = "delete notes lower than lasthit in RE" end
                  end 
                
                -- EDIT: delete all but the lasthit notes whose noteons exist within Razor Edit
                elseif task == 4 then   
                  if pitch ~= lastNoteHit and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                   reaper.MIDI_DeleteNote( take, n )
                   if n == 0 then undoMessage = "delete all but lasthit in RE" end
                  end 

                -- EDIT: delete all notes whose noteons AND noteoffs exist within Razor Edit
                elseif task == 8 then   
                  if startppqposOut >= razorStart_ppq_pos and endppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_DeleteNote( take, n )
                    if n == 0 then undoMessage = "delete notes contained within RE" end
                  end
                    
                -- EDIT: delete all notes <= note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 9 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch >= mouseNote then 
                    reaper.MIDI_DeleteNote( take, n )
                    if n == 0 then undoMessage = "delete notes <= note under mouse cursor in RE" end
                  end     
                    
                -- EDIT: delete all notes >= note under mouse cursor whose noteons exist within Razor Edit
                elseif task == 10 then   
                  if mouseNote ~= nil and
                    startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos and pitch <= mouseNote then 
                    reaper.MIDI_DeleteNote( take, n ) 
                    if n == 0 then undoMessage = "delete notes >= note under mouse cursor in RE" end
                  end    
                  
           -----------------------------------------------------------------------
              -- select notes with razor edits:
                         
                -- EDIT: select all notes whose noteons exist within Razor Edit
                elseif task == 5 then
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    reaper.MIDI_SetNote( take, n, true, nil, nil, nil, nil, nil, nil, nil)
                    if n == 0 then undoMessage = "select all notes in RE" end
                  end
                  
                -- EDIT: select all last-hit notes whose noteons exist within Razor Edit
                elseif task == 12 then
                  if lastNoteHit == pitch and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then 
                    reaper.MIDI_SetNote( take, n, true, nil, nil, nil, nil, nil, nil, nil)
                    if n == 0 then undoMessage = "select all last-hit notes in RE" end
                  end  
                  
           -----------------------------------------------------------------------
              -- nudge notes with razor edits:
              
                -- EDIT: nudge notes whose noteons exist within Razor Edit forwards
               elseif task == 6 then
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+ppqIncr, endppqposOut+ppqIncr, nil, nil, nil, nil) 
                    if startppqposOut+ppqIncr > razorEnd_ppq_pos then                -- if the notes go out of RE bounds
                      resizeREbyVisibleGrid(5, .1)
                    end
                    if n == 0 then undoMessage = "nudge notes in RE forwards" end
                  end

                -- EDIT: nudge notes whose noteons exist within Razor Edit backwards
                elseif task == 7 then  
                  if startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut-ppqIncr, endppqposOut-ppqIncr, nil, nil, nil, nil)
                    if n == 0 then undoMessage = "nudge notes in RE backwards" end
                  end
                
                -- EDIT: nudge notes whose noteons exist within Razor Edit forwards
                elseif task == 13 then
                  if lastNoteHit == pitch and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut+ppqIncr, endppqposOut+ppqIncr, nil, nil, nil, nil) 
                    if n == 0 then undoMessage = "nudge last-hit notes in RE forwards" end
                  end
              
                -- EDIT: nudge notes whose noteons exist within Razor Edit backwards
                elseif task == 14 then  
                  if lastNoteHit == pitch and startppqposOut >= razorStart_ppq_pos and startppqposOut < razorEnd_ppq_pos then -- pitch ~= lastNoteHit and 
                    reaper.MIDI_SetNote( take, n, nil, nil, startppqposOut-ppqIncr, endppqposOut-ppqIncr, nil, nil, nil, nil)
                    if n == 0 then undoMessage = "nudge last-hit notes in RE backwards" end
                  end
                end     -- of MIDI task switch section
              end       -- for each note    

           -----------------------------------------------------------------------                
              reaper.MIDI_Sort( take )      -- run once after MIDI task switch section
                                            -- not sure i'm using this correctly
              reaper.UpdateArrange()        -- or this  ?
              
            end         -- if it's MIDI
          end           -- for each take
        end             -- for each item
      end               -- if not Envelope
    end                 -- for each area
  end                   -- if RE   
  
  -- EDIT: select and copy all MIDI in REs
  if task == 11 then copySelectedMIDIinRE()
    undoMessage = "select/copy all notes in RE"
  end -- select/copy notes in REs
  
  reaper.UpdateArrange()
  if undoMessage ~= nil then reaper.Undo_OnStateChange2(proj, undoMessage) end
end                     -- end function MIDINotesInRE()

  
---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track -- mccrabney        
    --]]------------------------------]]--

function getLastNoteHit()                       -- open the function
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  local lastNote = -1                           -- initialize lastNote
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastnote") then  -- if desired trackname
      isTrack = isTrack+1                       -- flag that the ref track is present
      lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  if isTrack == 0 then                          -- if reference track isn't present, 
    
    reaper.Undo_BeginBlock()                    -- why isn't this working?
    
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    refTrack = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastnote", true)
    
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    reaper.TrackFX_AddByName( refTrack, "MIDI Examiner", false, 1 )  -- add js
    reaper.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    reaper.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- arm it
    
    reaper.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    controller = reaper.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) )  -- turn rec mon on
    
    reaper.ShowConsoleMsg("reference track not present.")     -- communicate
    reaper.ShowConsoleMsg("\n")
    reaper.ShowConsoleMsg("folder 'lastnote' has been created at the end of project.")
    reaper.ShowConsoleMsg("\n")
    reaper.ShowConsoleMsg("it contains a track armed to All MIDI inputs.")
    reaper.ShowConsoleMsg("\n")    
    reaper.ShowConsoleMsg("resend the reference note and rerun the action.")
    reaper.ShowConsoleMsg("\n")
    reaper.ShowConsoleMsg("this folder can be hidden and/or ignored from now on.")
    reaper.ShowConsoleMsg("\n")    
    reaper.ShowConsoleMsg("note: for more granular control,")
    reaper.ShowConsoleMsg("\n")    
    reaper.ShowConsoleMsg("set the track input to the intended MIDI controller,")
    reaper.ShowConsoleMsg("\n")    
    reaper.ShowConsoleMsg("duplicate track, and repeat process for more devices.")
    reaper.ShowConsoleMsg("\n")    
    
    reaper.Undo_EndBlock( "lastnote reference tracks created", -1 )      -- why isn't this working?
  
  end
  return lastNote         -- lastNoteHit is a referenced variable for edits
  
end                                             -- end function

    
--------------------------------------------------------------------
    --[[------------------------------[[--
          unselect all MIDI notes -- mccrabney   
    --]]------------------------------]]--

function unselectAllMIDIinTrack()
  reaper.Main_OnCommand(41238, 0)         -- save item selection? isn't working
  selected_tracks_count = reaper.CountSelectedTracks(0)

  for i = 0, selected_tracks_count-1  do   --   for each track
    track_sel = reaper.GetSelectedTrack(0, i) -- get selected track i
    item_num = reaper.CountTrackMediaItems(track_sel) -- how many items

    for j = 0, item_num-1 do               -- for each item 
      item = reaper.GetTrackMediaItem(track_sel, j)  -- get item
      take = reaper.GetTake(item, 0)      -- get take
      if reaper.TakeIsMIDI(take) then     -- if it's MIDI,
        reaper.MIDI_SelectAll(take, 0)      -- deselect all MIDI notes: 1 editor per proj,
                                            -- other items editable so all notes in RE
                                            -- get properly selected
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
  reaper.PreventUIRefresh(1)
  MIDINotesInRE(5)                        -- select RE-enclosed notes
  if RazorEditSelectionExists(0) then      -- if RE exists -- unnecessary?
    local areas = GetRazorEdits()         -- get all areas 
    local areaData = areas[1]             -- look at the first area
    if not areaData.isEnvelope then       -- if not envelope
      local items = areaData.items        -- get area items
      local item = items[1]               -- get first item
      local take = reaper.GetTake(item, 0)   -- get first take
      if reaper.TakeIsMIDI(take) then     -- if it's MIDI,
        reaper.SetMediaItemSelected(item, 1) -- select the first item
        reaper.Main_OnCommand(40153, 0)   -- open MIDI editor for selected item
        --local windowHWND = reaper.JS_Window_GetFocus()
        --reaper.JS_Window_SetOpacity( windowHWND, alpha, 50 )
        local activeEditor = reaper.MIDIEditor_GetActive()
        reaper.MIDIEditor_OnCommand(activeEditor, 40010)   -- copy selected notes from inside ME
        --reaper.MIDIEditor_OnCommand(activeEditor, 40794 )   -- close the ME
        
            -- requires these MIDI editor settings:
                -- One MIDI editor per track/project
                -- Open all MIDI in the track/project
                -- media item selection is linked to visibility OFF
                -- selection is linked to editability OFF
                -- Make secondary items editable by default
                
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
    
function resizeREbyVisibleGrid(job, incr, val)    -- where param informs direction of movement
    reaper.PreventUIRefresh(1)
    local size
    gridval = GetVisibleGridDivision()
    
    if RazorEditSelectionExists(0) then      -- if a razor edit exists (else donothing)
        local areas = GetRazorEdits()

        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart
            local aEnd = area.areaEnd
            reaper.ShowConsoleMsg(aEnd) 
            if job == 5 then ---- if we are incrementing/decrementing RE end
                aEnd =  reaper.SnapToGrid(0, aEnd+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end
                end
            end    
            
            if job == 6 then ---- if we are incrementing/decrementing RE start
                aStart =  reaper.SnapToGrid(0, aStart+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end    
                end                                
            end --if job  = 
        end -- for
    else  -- RazorEditSelectionExists() -- create if not present maybe deprecated now that check function is improved
         
        for i = 0, reaper.CountSelectedTracks(0)-1 do
            track = reaper.GetSelectedTrack(0, i)
            reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
            reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
            local cursorpos = reaper.GetCursorPosition()
            
            if job == 6 then 
                if incr == 1 then SetTrackRazorEdit(track, cursorpos, cursorpos+gridval, true) end 
            else
                if incr == -1 then SetTrackRazorEdit(track, cursorpos-gridval, cursorpos, true) end 
            end    
            
            reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
            -- reaper.defer(function() end)
        end
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
    
    if RazorEditSelectionExists(0) then
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
    if RazorEditSelectionExists(0) then
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

---------------------------------------------------------------------
--------------- end of mccrabney functions --------------------------
---------------------------------------------------------------------
-- Below are useful RE functions contributed by talented REAPER users.
---------------------------------------------------------------------   

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
        toggle mute RE contents or selected items  -- thanks, BirdBird!
    --]]------------------------------]]--

function muteREcontents()
    local areas = GetRazorEdits()
    items = SplitRazorEdits(areas)
    for j = 1, #items do 
        reaper.SetMediaItemSelected(items[j], true)
    end
    reaper.Main_OnCommand(40183, 0)  -- toggle mute
    reaper.Undo_OnStateChange2(proj, "toggle mute RE contents or selected items")
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          RE exist? if not/if desired, create them  -- thanks, sonictim and julian sader!          
    --]]------------------------------]]--

function RazorEditSelectionExists(make)

  for i=0, reaper.CountTracks(0)-1 do    -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end       -- if present, return true
  end                                     -- end for each track
    
  if x == nil and make == 1 then        -- if no RE, but one is needed,
    reaper.Undo_BeginBlock2(0)          -- make them from selected items.
    tS = {}
    for i = 0, reaper.CountSelectedMediaItems(0)-1 do   
      item = reaper.GetSelectedMediaItem(0, i)
      left = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      right = left + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      track = reaper.GetMediaItemTrack(item)
      tS[track] = (tS[track] or "") .. string.format([[%.16f %.16f "" ]], left, right)
    end
    for track, str in pairs(tS) do
      reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str, true)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, "Enclose items in minimal razor areas", -1)
    return true                    -- return that yes, RE exists now
  else if x == nil and make == 0 then
      return false end                  -- return that no RE exists
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

