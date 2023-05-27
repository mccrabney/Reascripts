--[[
 * ReaScript Name: show notes, under mouse and last-received
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.62
--]]
 
--[[
 * Changelog:
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


---------------------------------------------------------------------
local r = reaper
dofile(r.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')
extName = 'mccrabney_MIDI edit - show notes, under mouse and last-received.lua'

loopCount = 0
loopReset = 0
lastX = 0

local cursorSource = 0
local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
local pitchUnderCursor = {}
local channel
local ctx = r.ImGui_CreateContext('crabvision')
local monospace = r.ImGui_CreateFont('courier_new', 18)
r.ImGui_Attach(ctx, monospace)


---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track -- mccrabney        
    --]]------------------------------]]--

function getLastNoteHit()                       
  local numTracks = r.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = r.GetTrack(0,i-1)    -- get each track
    _, trackName = r.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if r.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = r.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastNote = math.floor(lastNote)

        lastVel = r.TrackFX_GetParam(findTrack, 0, 3)  -- find last hit velocity
        lastVel = math.floor(lastVel)        
        
      else                                      -- if noteoff, display no-note value
        lastNote = -1                           -- no note value
      end
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  if isTrack == 0 then                          -- if reference track isn't present, 
    r.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    refTrack = r.GetTrack( 0, numTracks)     -- get the new track
    _, _ = r.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastmidi", true)
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    r.TrackFX_AddByName( refTrack, "midi_examine", false, 1 )  -- add js
    r.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    r.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- set folder
    r.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    controller = r.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = r.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    r.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    r.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    r.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
                                        -- turn rec mon on, set to all MIDI inputs
    r.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) ) 
  
    r.ShowMessageBox("A folder has been created to watch your MIDI controllers.\n", "No MIDI reference", 0)  
  end
  return lastNote, lastVel         

end


-----------------------------------------------------------
    --[[------------------------------[[--
          get details of MIDI notes under mouse -- mccrabney        
    --]]------------------------------]]--
   
function getMouseInfo()
  
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local showNotes = {}    -- table consisting of sub-tables grouping Pitch and Vel
  local trackHeight
  local takes, channel
  local targetNoteIndex, targetPitch  -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take
  window, _, _ = r.BR_GetMouseCursorContext() -- initialize cursor context
  local track = r.BR_GetMouseCursorContext_Track()
  local hZoom = r.GetHZoomLevel()

  if window ~= "midi editor" and hZoom > 2 then   -- ifn't ME, and if slightly zoomed in
    if track ~= nil then                      -- if there is a track
      trackHeight = r.GetMediaTrackInfo_Value( track, "I_TCPH")
    end
    
    if cursorSource == 1 then
      cursorPos = r.BR_GetMouseCursorContext_Position() -- get mouse position
      take = r.BR_GetMouseCursorContext_Take() -- get take under mouse 
    else
      cursorPos = reaper.GetCursorPosition()   -- get pos at edit cursor
      itemnumbers = reaper.CountMediaItems()
      
      local item = {}
      for i = 0, itemnumbers-1 do
        item[i] = reaper.GetMediaItem(0, i)
        item_pos = reaper.GetMediaItemInfo_Value(item[i], "D_POSITION")
        item_length = reaper.GetMediaItemInfo_Value(item[i], "D_LENGTH")
        if item_pos <= cursorPos and item_pos + item_length > cursorPos then
          take = reaper.GetTake( item[i], 0 )
        end
      end
    
      take = r.BR_GetMouseCursorContext_Take() -- get take under mouse -- to-do: replace with under edit cursor!!!!
    end
            
    local firstMarkerPos = -1
    local firstMarkerMeasure = 0
    local firstMarkerQN = 0     
    local mrk_cnt = r.CountProjectMarkers(0)
    
    if mrk_cnt ~= nil then
      markers = {}
      
      for i = 0, mrk_cnt - 1 do                   -- get pos of each marker
        local _, isrgn, pos, _, markerName, index = r.EnumProjectMarkers( i )
         
        if markerName == "start" then
          local markerQN = r.TimeMap_timeToQN_abs( proj, pos )
          local markerMeasure, _ = r.TimeMap_QNToMeasures( proj, markerQN )
          
          firstMarkerPos = pos
          firstMarkerMeasure = markerMeasure
          firstMarkerQN = markerQN 
        end
      end
    end

    if take ~= nil and trackHeight > 25 or take ~= nil and cursorSource == 0 then      -- if track height isn't tiny
      if r.TakeIsMIDI(take) then 
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromMouse = {}            -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        item = r.BR_GetMouseCursorContext_Item() -- get item under mouse
        position_ppq = r.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert to PPQ
        local notesCount, _, _ = r.MIDI_CountEvts(take) -- count notes in current take
        
        for n = notesCount-1, 0, -1 do
          _, selected, muted, startppq, endppq, ch, pitch, vel = r.MIDI_GetNote(take, n) -- get note start/end position              
          
          if startppq <= position_ppq and endppq >= position_ppq then  -- is current note the note under the cursor?
            notePos = reaper.MIDI_GetProjTimeFromPPQPos( take, startppq)
            
            if firstMarkerPos ~= -1 and notePos >= firstMarkerPos then 
              ptidx = reaper.CountTempoTimeSigMarkers( proj )
              
              if ptidx == 0 then 
                _, bpi = reaper.GetProjectTimeSignature2( proj )
              elseif ptidx ~= 0 then 
                lastTempoMarker = reaper.FindTempoTimeSigMarker( proj , notePos)
                _, _, _, _, _, bpi, _, _ = reaper.GetTempoTimeSigMarker( proj, lastTempoMarker)
                if bpi == -1 then bpi = 4 end
              end
              
              --notePos = notePos - firstMarkerPos
              noteQN = reaper.TimeMap_timeToQN( notePos )
              noteQN = noteQN - firstMarkerQN
              _, remainder = math.modf(noteQN)
              noteMeasure = (math.floor(noteQN / bpi )) + 1
              
              notePPQ = math.floor((remainder * 960) + .5)
              if notePPQ == 960 then notePPQ = 0 end
              while noteQN > 4 do noteQN = noteQN - 4 end
              noteQN = math.floor((noteQN + 1) +.000005 )
              if noteQN == 5 then noteQN = 1 end
   
              stringNotePPQ = tostring(notePPQ)
              while string.len(stringNotePPQ) < 3 do stringNotePPQ = "0" .. stringNotePPQ end 
              stringNoteMeasure = tostring(noteMeasure)
              posString = noteMeasure .. "." .. noteQN .. "." .. stringNotePPQ .. "  "
            else
              posString = ""
            
            end
            
            numberNotes = numberNotes+1                           -- add to count of how many notes are under mouse cursor
            noteLength = math.floor(endppq - startppq)
            showNotes[numberNotes] = {pitch, vel, noteLength, ch+1, n, tostring(muted), posString}              -- get the pitch and corresponding velocity as table-in-table
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch
            distanceFromMouse[numberNotes] = position_ppq - startppq       -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppq          -- put distance to cursor in index position of sorting table
          end
        end
        
        table.sort(distanceSorted)  -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)     -- sort the pitch table so the lowest pitch is at index position 1
        
        local targetNoteDistance = distanceSorted[1]                  -- find the distance from mouse cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local sameDistance = 0                                        -- initialize the sameDistance variable
        local sameLowest
               
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            sameDistance = sameDistance+1
             
            for p = 1, #distanceFromMouse do                          -- for each entry in the distancefrommouse array
              if distanceFromMouse[p] == distanceSorted[1] then       -- if distFromMouse index = closest note entry,
                sameLowest = p                                        -- get the index 
              end
            end 
          end
        end
        
        --~~~~~~~  closest note
        for i = 1, #distanceFromMouse do                        -- for each entry in the unsorted distance array
          if targetNoteDistance == distanceFromMouse[i] and sameDistance == 0 then   
            
            targetNoteIndex = showNotes[i][5]
            targetPitch = showNotes[i][1]                -- get the pitch value of the closest note
          end                                     
        end                                                         -- end for each entry in array
               
        --~~~~~~~  multiple equidistant notes
        if sameDistance > 0 then                          -- if there are notes that are the same distance from mouse
          for t = 1, #distanceFromMouse do                 -- for each entry in the unsorted pitch array
            if lowestPitch == showNotes[t][1] then    -- if the entry matchest the closest note distance from mouse cursor
            
              targetNoteIndex = showNotes[t][5]              
              targetPitch = lowestPitch
            end
          end
        end
             
      end           -- if take is MIDI
    end             -- if take not nil
         
    table.sort(showNotes, function(a, b)                -- sort the shownotes table
      return a[1] < b[1]
    end)
    
    -------------------------------------------- set up extstate to communicate with other scripts

    local numVars = 8                                             -- see below
    r.SetExtState(extName, 1, numVars, false)                -- how many variables are we sending via extstates
    r.SetExtState(extName, 2, #showNotes, false)             -- how many notes are under mouse
    guidString = r.BR_GetMediaItemTakeGUID( take )           -- get guidString from take
    r.SetExtState(extName, 3, tostring(guidString), false)   -- what take is under mouse
    
    if targetNoteIndex ~= nil and targetPitch ~= nil then    
      r.SetExtState(extName, 4, targetPitch, false)          -- what is the target pitch under mouse
      r.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    elseif targetNoteIndex == nil then 
      targetNoteIndex = -1
      r.SetExtState(extName, 5, targetNoteIndex, false)      -- what is the target index under mouse
    end
    

    for i = 1, #showNotes do                             -- send off the table after all of the other variables
      r.SetExtState('extName', i + numVars, table.concat(showNotes[i],","), false)
    end
    
  return take, targetPitch, showNotes
    
  end
end


-----------------------------------------------------------
    --[[------------------------------[[--
          loop and show tooltips as necessary  -- mccrabney        
    --]]------------------------------]]--
    
pop = 0 
incrIndex = 2
lastIndex = 2
incr = {1, 10, 24, 48, 96, 240, 480, 960}
local function loop()
  
  local lastMIDI = {}
                                                                -- reset loop from external scripts
  r.ImGui_GetFrameCount(ctx)                               -- "a fast & inoffensive function"
  loopCount = loopCount+1                                       -- advance loopcount
   
  if r.HasExtState(extName, 'DoRefresh') then
    r.DeleteExtState(extName, 'DoRefresh', false)
    lastX = -1                                                  -- fools the optimizer into resetting
  end        
  
  if r.HasExtState(extName, 6) then                             -- increment of nudge,
    q = tostring(reaper.GetExtState( extName, 6 ))
    if incrIndex + q > 0 and incrIndex + q < 9 then 
      incrIndex = incrIndex + q 
    end
    --reaper.ShowConsoleMsg(incr[incrIndex] .. "\n")
    r.SetExtState(extName, 7, incr[incrIndex], true)
    r.DeleteExtState(extName, 6, false)
  end   
    
  if r.HasExtState(extName, 'toggleCursor') then                -- toggle edit or mouse cursor                                        -- fools the optimizer into resetting
    if cursorSource == 0 then 
      cursorSource = 1 
    elseif cursorSource == 1 
      then cursorSource = 0  
    end
    r.SetExtState(extName, 8, cursorSource, true)
    r.DeleteExtState(extName, 'toggleCursor', false)
    
    --reaper.ShowConsoleMsg(cursorSource .. "\n")
    --lastX = -1
  end         
  
  
                                                                -- optimizer to reduce calls to getMouseInfo
  if loopCount >= 3 and info == "arrange" and lastX ~= x and pop == 0 or loopCount >= 3 and cursorSource == 0  then 
    take, targetPitch, showNotes = getMouseInfo() 
    if take ~= nil and r.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      lastX = x                                                 -- set lastX mouse position
    end
  end                                                           -- end optimizer
  
  if loopCount < 500 then                                       -- optimizer2, stops checking for last note if idle
    lastNote, lastVel = getLastNoteHit()   
  end                                                           -- end optimizer2

  if cursorSource == 1 then 
    x, y = r.GetMousePosition()         -- mousepos
  else 
    _, y = r.GetMousePosition() 
    x = 1000
  end
  
  _, info = r.GetThingFromPoint( x, y )                  -- mousedetails
  
  if lastNote == -1 then pop = 0 end

  local skip = 0                                                -- insert last-received MIDI into table
  if lastNote ~= -1 and lastNote ~= nil and take ~= nil and pop == 0 then
    pop = 1                                                     -- MIDI is being received
                                                                -- package the pitch/vel info
    local currentVel
    for i = 1, #showNotes do                   -- check each note to see if it is already present
      if lastNote == showNotes[i][1] then 
        currentVel = showNotes[i][2]
        skip = 1
      end  
    end    
    
    if skip ~= 1 then
      lastMIDI[1] = {lastNote, lastVel, 0, 0} 
      table.insert(showNotes, 1, lastMIDI[1]) 
      showNotes[1][7] = "    => "

    end   

    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1) 
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  
  if targetPitch ~= nil and info == "arrange" and take ~= nil 
  or targetPitch ~= nil and info == "arrange" and cursorSource == 0 then  -- if mousing over a note in a MIDI item in arrange
    
    r.ImGui_SetNextWindowPos(ctx, x - 11, y + 25)
    r.ImGui_PushFont(ctx, sans_serif)  
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), 0x0F0F0FD8)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowRounding(), 12)

    if r.ImGui_Begin(ctx, 'Tooltip', false,
    r.ImGui_WindowFlags_NoFocusOnAppearing() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_TopMost() |
    r.ImGui_WindowFlags_AlwaysAutoResize()) then
    
      local octaveNote                                  -- variables for readout
      local noteSymbol                                  
      local color = 0x00F992FF
      local spacingO = " "
      local spacingN = ""
      local spacingV = ""
      local spacingD = ""
      local spacingCH = " "
      local postNote = "  "
  
      local numberNotes = #showNotes
      posStringSize = {}
      noteStringSize = {}
      
      for i = 1, numberNotes do
        posStringSize[i] = string.len(showNotes[i][7])
      end
      
      table.sort(posStringSize)
      
      for i = numberNotes, 1, -1 do                   -- for each top-level entry in the showNotes table,
        if showNotes[1] ~= nil and targetPitch ~= nil then
          
          if string.len(showNotes[i][7]) < posStringSize[#posStringSize] then
            showNotes[i][7] = " " .. showNotes[i][7]
          end
          
          octave = math.floor(showNotes[i][1]/12)-1                    -- establish the octave for readout
          cursorNoteSymbol = pitchList[(showNotes[i][1] - 12*(octave+1)+1)]       -- establish the note symbol for readout
    
          if     showNotes[i][1] > -1  and showNotes[i][1] <  10 then spacingN = "  "     -- spacingN for the note readout
          elseif showNotes[i][1] > 9  and showNotes[i][1] < 100 then spacingN = " " 
          elseif showNotes[i][1] > 99                           then spacingN = "" 
          end
          
          if octave < 0 then 
            spacingO = "" 
            --cursorNoteSymbol = cursorNoteSymbol:gsub(' ', '') 
            postNote = postNote:gsub(' ', '') 
          end
          
          if showNotes[i][4] ~= "in" then                             -- spacingCH for channel readout
            if showNotes[i][4] <    10 then 
              spacingCH = "  " 
            else  
              spacingCH = " "
            end
          else
            spacingCH = " "
          end
            
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
          
          if showNotes[i][1] == targetPitch and showNotes[i][1] ~= lastNote then  -- color red if entry matches the target note & no lastNote
            color = 0xFF8383FF                             -- red                        
          elseif showNotes[i][1] == lastNote and pop == 1 then      -- if note is received from controller
            notePresent = 1
            showNotes[i][2] = lastVel                               -- set incoming velocity
            showNotes[i][3] = ""                                  -- duration
            showNotes[i][4] = "in"
            --incr[incrIndex] = ""
            color = 0x00F992FF                            -- green for incoming
          elseif showNotes[i][1] ~= lastNote then 
            color = 0xFFFFFFFF                            -- white for non-target
          end
          
          table.sort(showNotes, function(a, b) return a[1] < b[1] end)
          
          if i-1 ~= nil and showNotes[i] ~= showNotes[i+1] then
            r.ImGui_TextColored(ctx, color, "" .. showNotes[i][7] .. "n:" .. spacingN .. showNotes[i][1] .. 
            spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " ..
            "ch:" .. spacingCH .. showNotes[i][4] ..   "  v: " .. spacingV .. showNotes[i][2] .. 
            "  d: " .. spacingD .. showNotes[i][3] .. "  *" ..  incr[incrIndex]  )
          end
        end
      end                                               -- for each shown note
       
    r.ImGui_End(ctx)
    end        -- if imgui begin
    
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_PopFont(ctx)
    r.ImGui_PopStyleVar(ctx)
  end            -- if take, cursornote, and loopReset conditions are met
  
  r.defer(loop)
end

--------------------------------------------

function main()

  r.defer(loop)
end
----------------------------

--main()

-----------------------------------------------

function SetButtonON()
  r.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  r.RefreshToolbar2( sec, cmd )
  main()
end

-----------------------------------------------

function SetButtonOFF()
  r.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  r.RefreshToolbar2( sec, cmd ) 
end

-----------------------------------------------

_, _, sec, cmd = r.get_action_context()
SetButtonON()
r.atexit(SetButtonOFF)
