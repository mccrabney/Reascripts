--[[
 * ReaScript Name: show notes, under cursor and last-received.lua
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.70
--]]
 
-- HOW TO USE -- 
-- run this defer script, then use my other scripts to edit MIDI from the arrange screen.
-- for example, "mccrabney_MIDI edit - delete notes under cursor, or notes in RE.lua"
-- to change nudge increment, use "mccrabney_MIDI edit - adjust ppq increment for edit scripts (mousewheel).lua"
-- to switch between mouse/edit cursor, use "mccrabney_MIDI edit - toggle between mouse and edit cursor for 'show notes'.lua"
-- to set the target note, use "mccrabney_MIDI edit - step through notes under cursor in 'show notes'.lua"

---------------------------------------------------------------------
-- Requires js_ReaScriptAPI extension: https://forum.cockos.com/showthread.php?t=212174

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')
extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'
if reaper.HasExtState(extName, 8) then            -- get the cursorsource, if previously set
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
end

toggleNoteHold = 0

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW

local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
local ctx = reaper.ImGui_CreateContext('shownotes')

-----------------------------------------------------------
    --[[------------------------------[[--
          check for razor edit 
    --]]------------------------------]]--
    
function RazorEditSelectionExists()
 
  for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end              -- if present, return true 
    if x == nil then return false end            -- return that no RE exists
  end
end    

---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track        
    --]]------------------------------]]--

noteHoldNumber = -1
function getLastNoteHit()                       
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastNote = math.floor(lastNote)
        lastVel = reaper.TrackFX_GetParam(findTrack, 0, 3)  -- find last hit velocity
        lastVel = math.floor(lastVel)  
        if toggleNoteHold == 1 then 
          noteHoldNumber = lastNote 
        else 
          noteHoldNumber = -1 
        end
        reaper.SetExtState(extName, 'noteHold', noteHoldNumber, false)         -- write the note hold number
      else                                      -- if noteoff, display no-note value
        lastNote = -1                           -- no note value
      end
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  if isTrack == 0 then                          -- if reference track isn't present, 
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    refTrack = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastmidi", true)
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    reaper.TrackFX_AddByName( refTrack, "midi_examine", false, 1 )  -- add js
    reaper.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    reaper.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- set folder
    reaper.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    controller = reaper.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
                                        -- turn rec mon on, set to all MIDI inputs
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) ) 
    reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\n", "No MIDI reference", 0)  
  end
  return lastNote, lastVel         

end

-----------------------------------------------------------
    --[[------------------------------[[--
          get details of MIDI notes under cursor
    --]]------------------------------]]--
step = 0
function getCursorInfo()
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local showNotes = {}    -- table consisting of sub-tables grouping Pitch and Vel
  local trackHeight
  local take, takes, channel
  local targetNoteIndex, targetPitch  -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take
  window, _, _ = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local track = reaper.BR_GetMouseCursorContext_Track()
  local hZoom = reaper.GetHZoomLevel()

  if window ~= "midi editor" and hZoom > 2 then   -- ifn't ME, and if slightly zoomed in
    if track then                      -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")
      
      if cursorSource == 1 then
        take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse 
        cursorPos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
      else
        cursorPos = reaper.GetCursorPosition()   -- get pos at edit cursor
        local CountTrItem = reaper.CountTrackMediaItems(track)
        if CountTrItem then 
          for i = 0, CountTrItem-1 do         -- for each item,               
            local item = reaper.GetTrackMediaItem(track,i)      
            local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
            local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
            if itemStart <= cursorPos and itemEnd > cursorPos then
               take = reaper.GetTake( item, 0 )
            end
          end
        end
      end
    end

    local startMarkerPos = -1
    local firstMarkerMeasure = 0
    local firstMarkerQN = 0     
    local mrk_cnt = reaper.CountProjectMarkers(0)
    if mrk_cnt ~= nil then
      markers = {}
      for i = 0, mrk_cnt - 1 do                   -- get pos of each marker
        local _, isrgn, pos, _, markerName, index = reaper.EnumProjectMarkers( i )
        if markerName == "start" then
          local markerQN = reaper.TimeMap_timeToQN_abs( proj, pos )
          local markerMeasure, _ = reaper.TimeMap_QNToMeasures( proj, markerQN )
          startMarkerPos = pos
          firstMarkerMeasure = markerMeasure
          firstMarkerQN = markerQN 
        end
      end
    end
    
    if take and trackHeight > 25 then -- and cursorSource == 0 then      -- if track height isn't tiny
      if reaper.TakeIsMIDI(take) then 
        IDtable = {}                            -- get the note IDs under cursor
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromCursor = {}           -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
        position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert to PPQ
        local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
        
        for n = notesCount-1, 0, -1 do
          _, selected, muted, startppq, endppq, ch, pitch, vel = reaper.MIDI_GetNote(take, n)           
          if startppq <= position_ppq and endppq >= position_ppq then  -- is current note the note under the cursor?
            notePos = reaper.MIDI_GetProjTimeFromPPQPos( take, startppq)
            
            if startMarkerPos ~= -1 and notePos >= startMarkerPos then   -- if after "start" marker
              ptidx = reaper.CountTempoTimeSigMarkers( proj )
              if ptidx == 0 then 
                _, bpi = reaper.GetProjectTimeSignature2( proj )
              elseif ptidx ~= 0 then 
                lastTempoMarker = reaper.FindTempoTimeSigMarker( proj , notePos)
                _, _, _, _, _, bpi, _, _ = reaper.GetTempoTimeSigMarker( proj, lastTempoMarker)
                if bpi == -1 then bpi = 4 end         
              end
              
              noteQN = reaper.TimeMap_timeToQN( notePos )         -- prepare time display
              noteQN = noteQN - firstMarkerQN                     
              _, remainder = math.modf(noteQN)
              noteMeasure = (math.floor(noteQN / bpi )) + 1
              notePPQ = math.floor((remainder * 960) + .5)
              if notePPQ == 960 then 
                noteMeasure = noteMeasure + 1 
                notePPQ = 0 
              end
              
              while noteQN > bpi do noteQN = noteQN - bpi end
              noteQN = math.floor((noteQN + 1) +.000005 )
              if noteQN > bpi then noteQN = 1 end
              stringNotePPQ = tostring(notePPQ)
              while string.len(stringNotePPQ) < 3 do stringNotePPQ = "0" .. stringNotePPQ end 
              stringNoteMeasure = tostring(noteMeasure)
              posString = noteMeasure .. "." .. noteQN .. "." .. stringNotePPQ .. "  "
            else
              posString = ""
            end
            
            numberNotes = numberNotes+1                           -- add to count of how many notes are under cursor
            IDtable[numberNotes] = {pitch, n}                     -- get noteidx for each note under cursor
            noteLength = math.floor(endppq - startppq)            -- establish the length of the note
            showNotes[numberNotes] = {pitch, vel, noteLength, ch+1, n, tostring(muted), posString}   -- get the pitch and corresponding velocity as table-in-table
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch                    
            distanceFromCursor[numberNotes] = position_ppq - startppq       -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppq          -- put distance to cursor in index position of sorting table
          end
        end
        
        if #showNotes then
          if reaper.HasExtState(extName, 'stepIncr') then         -- update display, called from child scripts
            step = step + 1
            if step >= #showNotes then step = 0 end
            reaper.SetExtState(extName, 'step', step, false)
            reaper.DeleteExtState(extName, 'stepIncr', false)
          end
          
          if reaper.HasExtState(extName, 'stepDown') then         -- update display, called from child scripts
            step = 0  
            reaper.SetExtState(extName, 'step', step, false)
            reaper.DeleteExtState(extName, 'stepDown', false)
          end
        end
        
        table.sort(distanceSorted)  -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)     -- sort the pitch table so the lowest pitch is at index position 1
        local targetNoteDistance = distanceSorted[1]                  -- find the distance from cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local sameLowest
        
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            for p = 1, #distanceFromCursor do                          -- for each entry in the distanceFromCursor array
              if distanceFromCursor[p] == distanceSorted[1] then       -- if distFromMouse index = closest note entry,
                sameLowest = p                                         -- get the index 
              end
            end 
          end
        end
        
        --~~~~~~~ find closest note
        for i = #distanceFromCursor, 1, -1 do                        -- for each entry in the unsorted distance array
        --for i = 1, #distanceFromCursor do                        -- for each entry in the unsorted distance array
          if targetNoteDistance == distanceFromCursor[i] then   
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
      targetNotePos = reaper.MIDI_GetProjTimeFromPPQPos( take, targetPPQ)
      targetEndPos = reaper.MIDI_GetProjTimeFromPPQPos( take, targetEndPPQ)
      track = reaper.GetMediaItemTake_Track( take )
      trPos = reaper.GetMediaTrackInfo_Value( track, 'I_TCPY' )
      tcpHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH')
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
      reaper.SetExtState(extName, 'step', step, false)
      reaper.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    end
    
    -- NOTE: extState 6 = +, - incrIndex. extState 7 = incr Value
    for i = 1, #showNotes do                             -- send off the table after all of the other variables
      reaper.SetExtState(extName, i + numVars, table.concat(showNotes[i],","), false)
    end
  
    return take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight
  end
end

-------------------------------------------------------------------------------------------
        -- vars/setup for loop
incrIndex = 2
loopCount = 0
lastX = 0
pop = 0 
editCurPosLast = -1
local incr = {1, 10, 24, 48, 96, 240, 480, 960}
noteOnLine        = reaper.JS_LICE_CreateBitmap(true, 1, 1)
noteOnLineShadow  = reaper.JS_LICE_CreateBitmap(true, 1, 1)
noteOffLine       = reaper.JS_LICE_CreateBitmap(true, 1, 1)
noteOffLineShadow = reaper.JS_LICE_CreateBitmap(true, 1, 1)
    
    --[[------------------------------[[--
          loop and show tooltips, cursor as necessary  
    --]]------------------------------]]--

function loop()
  loopCount = loopCount+1                                       -- advance loopcount
  editCurPos = reaper.GetCursorPosition()
  local lastMIDI = {}                                           -- 
  reaper.ImGui_GetFrameCount(ctx)                               -- "a fast & inoffensive function"
   
  if reaper.HasExtState(extName, 'DoRefresh') then              -- update display, called from child scripts
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight = getCursorInfo()
    reaper.DeleteExtState(extName, 'DoRefresh', false)
    lastX = -1                                                  -- n/a x val fools the optimizer into resetting
    reset = 1                                                   -- allow nudge
  end        
  
  if reaper.HasExtState(extName, 6) then                        -- set increment of nudge,
    q = tostring(reaper.GetExtState( extName, 6 ))              -- based on input from child script
    if incrIndex + q > 0 and incrIndex + q < 9 then 
      incrIndex = incrIndex + q 
    end
    reaper.SetExtState(extName, 7, incr[incrIndex], true)
    reaper.DeleteExtState(extName, 6, false)
  end   
    
  if reaper.HasExtState(extName, 'toggleCursor') then           -- toggle whether focus is edit or mouse cursor                                        -- fools the optimizer into resetting
    if cursorSource == 0 then 
      cursorSource = 1 
    elseif cursorSource == 1 then 
      cursorSource = 0  
    end 
    reaper.SetExtState(extName, 8, cursorSource, true)
    reaper.DeleteExtState(extName, 'toggleCursor', false)
    --lastX = -1
  end       
  
  
          ----------------------------------------------------- optimizer to reduce calls to getCursorInfo
  if loopCount >= 3 and info == "arrange" and lastX ~= x and pop == 0  
  or editCurPos ~= editCurPosLast then 
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight = getCursorInfo() 
    
    if take ~= nil and reaper.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      lastX = x                                                 -- set lastX mouse position
    end
    
    if reset == 1 then reset = 0 end                            -- set reset
  end                                                           
  
  ------------------------------------------------------------- toggle whether focus is edit or mouse cursor                                        
  if reaper.HasExtState(extName, 'toggleNoteHold') then         
    if toggleNoteHold == 0 then
      toggleNoteHold = 1
      if targetPitch then noteHoldNumber = targetPitch end
      reaper.SetExtState(extName, "noteHold", noteHoldNumber, false)         -- write the note hold number
    elseif toggleNoteHold == 1 then
      toggleNoteHold = 0
      reaper.SetExtState(extName, "noteHold", -1, false)         -- write the note hold number
    end
    reaper.DeleteExtState(extName, 'toggleNoteHold', false)
  end       
  
  ---------------------------------------------------  get last note hit and feed it into table 
  
  if loopCount < 500 then lastNote, lastVel = getLastNoteHit() end                                                           
  x, y = reaper.GetMousePosition()                              -- mousepos
  _, info = reaper.GetThingFromPoint( x, y )                    -- mousedetails
  local skip = 0                                                -- insert last-received MIDI into table
  
  if lastNote == -1 then pop = 0 end                            -- reset pop value (pop = incoming MIDI)
  if lastNote ~= -1 and lastNote ~= nil and take ~= nil and pop == 0 then
    pop = 1                                                     -- MIDI is being received
    local currentVel                                            -- package the pitch/vel info
  
    for i = 1, #showNotes do                                    -- check each note to see if it is already present
      if lastNote == showNotes[i][1] then 
        currentVel = showNotes[i][2]
        skip = 1                                                -- if yes, skip it
      end  
    end    
    
    if skip ~= 1 and toggleNoteHold == 0 then                                           -- if incoming note is not present in table,
      lastMIDI[1] = {lastNote, lastVel, 0, 0} 
      table.insert(showNotes, 1, lastMIDI[1])                   -- insert it
      showNotes[1][7] = ""                               
    end    
  
    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1) 
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  -------------------------------------------------------------------------------------------------
  ------------------------------GUI ---------------------------------------------------------------
  mouseState = reaper.JS_Mouse_GetState(0xFF)
  --if mouseState ~= 1 and mouseState ~= 64 then    -- acknowledging 64 (middlemouse) prevents single click from working.                             -- if not left click 
  if mouseState ~= 1 then                                       -- if not left click 
            ----------------------------------------------------- draw guideline at target note 
    if targetPitch ~= nil and info == "arrange" and take ~= nil then 
      
      local sysTime = math.floor( reaper.time_precise  ())        -- blink cursor
      if cursorSource == 1 then curColor = 0xFFFF0000 else curColor = 0xFF0033FF end
      
      reaper.JS_LICE_Clear(noteOnLine, curColor )
      reaper.JS_LICE_Clear(noteOnLineShadow,  0x85000000 )
      reaper.JS_LICE_Clear(noteOffLine, curColor )
      reaper.JS_LICE_Clear(noteOffLineShadow, 0x85000000 )
      
      if targetNotePos then 
        local zoom_lvl = reaper.GetHZoomLevel()
        local Arr_start_time = reaper.GetSet_ArrangeView2(0, false, 0, 0)
        targetNotePixel   = math.floor((targetNotePos - Arr_start_time) * zoom_lvl)
        targetNotePixelEnd = math.floor((targetEndPos - Arr_start_time) * zoom_lvl)
        if targetNotePixel    < 0 then targetNotePixel    = 0 end
        if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end
      end
      
      local pad = 15
      reaper.JS_Composite(track_window, targetNotePixel,      trPos + pad, 1, tcpHeight - pad - 3, noteOnLine, 0, 0, 1, 1, true) -- DRAW
      reaper.JS_Composite(track_window, targetNotePixel+1,    trPos + pad, 1, tcpHeight - pad - 3, noteOnLineShadow, 0, 0, 1, 1, true) -- DRAW
      reaper.JS_Composite(track_window, targetNotePixelEnd+1, trPos + pad, 1, tcpHeight - pad - 3, noteOffLine, 0, 0, 1, 1, true) -- DRAW
      reaper.JS_Composite(track_window, targetNotePixelEnd,   trPos + pad, 1, tcpHeight - pad - 3, noteOffLineShadow, 0, 0, 1, 1, true) -- DRAW
      
    else                                                    -- if no note under cursor
      reaper.JS_Composite_Unlink(track_window, noteOnLine, true)     -- CLEAR
      reaper.JS_Composite_Unlink(track_window, noteOnLineShadow, true)     -- CLEAR
      reaper.JS_Composite_Unlink(track_window, noteOffLine, true)    -- CLEAR
      reaper.JS_Composite_Unlink(track_window, noteOffLineShadow, true)    -- c'mon it's clear
    end
    
                       ----------------------------------------- draw the text readout 
    if targetPitch ~= nil and info == "arrange" and take ~= nil  then
      reaper.ImGui_SetNextWindowPos(ctx, x - 11, y + 55)
      local rounding                          -- round window for mouse cursor, square for edit
      if cursorSource == 1 then rounding = 12 else rounding = 0 end
  
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x00000000 | 0xFF)
      reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), rounding)
  
      if reaper.ImGui_Begin(ctx, 'Tooltip', false,
      reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
      reaper.ImGui_WindowFlags_NoDecoration() |
      reaper.ImGui_WindowFlags_TopMost() |
      reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      
        local octaveNote                                  -- variables for readout
        local noteSymbol                                  
        local color = 0xFFFFFFFF                          -- offwhite for non-target note readouts
        local spacingO = " "
        local spacingN = ""
        local spacingV = ""
        local spacingD = ""
        local spacingCH = " "
        local postNote = "  "
        local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
        
        posStringSize, noteStringSize = {}
        for i = 1, #showNotes do
          posStringSize[i] = string.len(showNotes[i][7])
        end
        table.sort(posStringSize)
        
        for i = #showNotes, 1, -1 do                   -- for each top-level entry in the showNotes table,
          if showNotes[1] and targetPitch then
            if showNotes[i][7] == "" then 
              for j = 1, posStringSize[#posStringSize] do 
                showNotes[i][7] = " " .. showNotes[i][7]
              end
            end
            
            octave = math.floor(showNotes[i][1]/12)-1                    -- establish the octave for readout
            cursorNoteSymbol = pitchList[(showNotes[i][1] - 12*(octave+1)+1)]       -- establish the note symbol for readout
      
            if     showNotes[i][1] > -1  and showNotes[i][1] <  10 then spacingN = "  "     -- spacingN for the note readout
            elseif showNotes[i][1] > 9   and showNotes[i][1] < 100 then spacingN = " " 
            elseif showNotes[i][1] > 99                            then spacingN = "" 
            end
            
            if octave < 0 then spacingO = "" postNote = postNote:gsub(' ', '') end  -- spacing for octave readout 
            
            if showNotes[i][4] ~= "in" then                                         -- spacingCH for channel readout
              if showNotes[i][4] < 10 then spacingCH = "  " else spacingCH = " " end
            else spacingCH = " " end
              
            if     showNotes[i][2] > 0  and showNotes[i][2] <  10 then spacingV = "  "         -- spacingV for the velocity readout
            elseif showNotes[i][2] > 9  and showNotes[i][2] < 100 then spacingV = " " 
            elseif showNotes[i][2] > 99                           then spacingV = "" 
            end
  
            if type(showNotes[i][3]) == "number" then
              if     showNotes[i][3] > 0    and showNotes[i][3] <    10 then spacingD = "    "   -- spacing for the duration readout
              elseif showNotes[i][3] > 9    and showNotes[i][3] <   100 then spacingD = "   " 
              elseif showNotes[i][3] > 99   and showNotes[i][3] <  1000 then spacingD = "  " 
              elseif showNotes[i][3] > 999  and showNotes[i][3] < 10000 then spacingD = " " 
              elseif showNotes[i][3] > 9999                             then spacingD = ""
              end
            end
            
            if showNotes[i][1] == targetPitch and showNotes[i][1] ~= lastNote then  -- color if entry matches the target note & no lastNote
              if cursorSource == 1 then color = 0xFF8383FF else color = 0xFFB1FFFF end
              increment = "*" .. reaper.GetExtState(extName, 7 )
                             
            elseif showNotes[i][1] == lastNote and pop == 1 then      -- if note is received from controller
              notePresent = 1
              showNotes[i][2] = lastVel                               -- set incoming velocity
              showNotes[i][3] = ""                                    -- duration
              showNotes[i][4] = "in"
              increment = "" --incr[incrIndex] = ""
              color = 0x00FF45FF                            -- green for incoming
            elseif showNotes[i][1] ~= lastNote then 
              color = 0xFFFFFFFF                            -- white for non-target
              increment = ""
            end
            
            if showNotes[i][6] == "true" then color = 0x7a7a7aFF end
            
            table.sort(showNotes, function(a, b) return a[1] < b[1] end)
            
            if i-1 ~= nil and showNotes[i] ~= showNotes[i+1] then
            reaper.ImGui_TextColored(ctx, color, showNotes[i][7] .. "n:" .. spacingN .. showNotes[i][1] .. 
              spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " ..
              "ch:" .. spacingCH .. showNotes[i][4] ..   "  v: " .. spacingV .. showNotes[i][2] .. 
              "  d: " .. spacingD .. showNotes[i][3] .. "  " ..  increment  )
            end
          end
        end                                               -- for each shown note
        
        if toggleNoteHold == 1 and noteHoldNumber ~= -1 then 
          local togPad = ""
          for j = 1, posStringSize[#posStringSize] do togPad = " " .. togPad end
          octave = math.floor(noteHoldNumber/12)-1                    -- establish the octave for readout
          cursorNoteSymbol = pitchList[(noteHoldNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
          
          reaper.ImGui_TextColored(ctx, 0x00FF45FF, togPad .. "n: " .. noteHoldNumber ..spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " .. "(RE target note)"  ) 
          
        end
        
        reaper.ImGui_End(ctx)
      end                                                 -- if imgui begin
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopStyleVar(ctx)
    end           
  end
  reaper.defer(loop)
  editCurPosLast = reaper.GetCursorPosition()
end
--------------------------------------------

local function Clean()
  reaper.JS_LICE_DestroyBitmap( bitmap )
end

--------------------------------------------
function main()
  reaper.defer(function() xpcall(Main, Clean) end)
  reaper.defer(loop)
end
-----------------------------------------------
function SetButtonON()
  reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
reaper.RefreshToolbar2( sec, cmd )
  main()
end
-----------------------------------------------
function SetButtonOFF()
  Clean()
  reaper.JS_LICE_DestroyBitmap( noteOnLine)
  reaper.JS_LICE_DestroyBitmap( noteOffLine)
  reaper.JS_LICE_DestroyBitmap( noteOnLineShadow)
  reaper.JS_LICE_DestroyBitmap( noteOffLineShadow)

  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  reaper.RefreshToolbar2( sec, cmd ) 
end
-----------------------------------------------
_, _, sec, cmd = reaper.get_action_context()
SetButtonON()
reaper.atexit(SetButtonOFF)

--[[
 * Changelog:
* v1.71 (2023-7-19)
  + added ability to toggle holding of last hit note using script: mccrabney_MIDI edit - toggle hold input note for 'show notes'
    * running this action sets RE target note to note under cursor
    * inputting notes from controller will change target note.
    * running the script again again releases the note.
* v1.70 (2023-6-9)
  + ghost cursors drop shadows
* v1.69 (2023-6-9)
  + added ability to step through the notes/change target note currently under the cursor
    * use Script: mccrabney_MIDI edit - step through notes under cursor in 'show notes'.lua
    * targetNote will step through notes under cursor, closest to farthest.
* v1.68 (2023-6-9)
  + fixed bug where n.1.000 displayed as (n-1).1.000
* v1.67a (2023-6-8)
  + reverted 1.66 ghost cursor disable on middle click, bc it was suppressing middle clicks down w/out middle drag.
* v1.67 (2023-6-8)
  + added ghost cursor to show the noteOFF position
* v1.66 (2023-6-7)
  + time display: add support for time signatures other than 4/4
  + disable ghost cursor and text readout while left or middle clicking mouse
* v1.65 (2023-6-3)
  + fixed samedistance bug preventing closest note from being targeted
* v1.64 (2023-5-31)
  + added a ghost cursor that indicates the target note: blue for edit cursor, red for mouse cursor
* v1.63 (2023-5-27)
  + updated name of script, extstate 
  + changed display for edit cursor mode: blue, vs red, and non-rounded tooltip corners
* v1.63 (2023-5-27)
  + updated name of script, extstate 
  + changed display for edit cursor mode: blue, vs red, and non-rounded tooltip corners
+ v1.62 (2023-5-26)
  + added "edit cursor mode" where edit cursor provides note data rather than mouse cursor
+ v1.61 (2023-5-25)
  + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts"
  + added note position readout, where time 1.1.000 begins at a marker named "start"
     if no marker named "start" is present, or if notes begin before "start" marker,
     then no time readout is displayed.
+ v1.6 (2023-5-23)
   + removed pause function, chasing an index as one note is nudged past another proved too difficult
+ v1.511 (2023-5-22)
   + minor typo fix
+ v1.51 (2023-5-21)
   + now reports toolbar button toggle state
 + v1.50 (2023-5-20)
   + added secondary script "pause show notes" to "hold" a target note in yellow
   + issue, mouse must still be over target Take, fix eventually? 
 + v1.45 (2023-5-09)
   + added muted note coloration
 + v1.44 (2023-5-07)
   + added extstates to output notes under mouse to other scripts
 + v1.43 (2023-5-05)
   + fixed error message, improved spacing on readout
 + v1.42 (2023-5-04)
   + added note duration display, changed readout to conform to conventional MPC step edit screen
 * v1.41 (2023-5-04)
   + fixed show last-hit MIDI note, appears in green, replacing existing readout if present
 * v1.4 (2023-5-04)
   + added velocity readout for all notes
* v1.3 (2023-5-03)
   + added velocity readout for target note only
 * v1.2 (2023-5-01)
   + fixed error message on MIDI item glue
 * v1.1 (2023-03-12)
   + fixed retriggering upon new MIDI notes
 * v1.0 (2023-03-12)
   + Initial Release -- "Crab Vision" (combined previous scripts)
--]]
