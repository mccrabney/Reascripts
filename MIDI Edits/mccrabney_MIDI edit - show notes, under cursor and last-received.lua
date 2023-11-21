
--[[
 * ReaScript Name: show notes, under cursor and last-received.lua
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.79
--]]
 
-- HOW TO USE -- 
-- run this defer script, then use my other scripts to edit MIDI from the arrange screen.
-- for example, "mccrabney_MIDI edit - delete notes under cursor, or notes in RE.lua"
-- to change nudge increment, use "mccrabney_MIDI edit - adjust ppq increment for edit scripts (mousewheel).lua"
-- to switch between mouse/edit cursor, use "mccrabney_MIDI edit - toggle between mouse and edit cursor for 'show notes'.lua"
-- to set the target note, use "mccrabney_MIDI edit - step through notes under cursor in 'show notes'.lua"

---------------------------------------------------------------------
-- Requires js_ReaScriptAPI extension: https://forum.cockos.com/showthread.php?t=212174

--idleTask = 1

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')
extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'
if reaper.HasExtState(extName, 8) then            -- get the cursorsource, if previously set
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
end

resetCursor = 50  -- how many loopCounts should pass before cursor is reset from Edit to Mouse
                  -- this resets cursor to mouse when idle

local main_wnd = reaper.GetMainHwnd()                                -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
local ctx = reaper.ImGui_CreateContext('shownotes')                  -- create imgui context

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
    
toggleNoteHold = 0                              -- set notehold off by default
noteHoldNumber = -1                             -- default notehold number to an inapplicable value

function getLastNoteHit()                       -- what is the last note that has been struck on our controllers?
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the reference track present, initialized to no
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )  -- get trackname
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastVel = reaper.TrackFX_GetParam(findTrack, 0, 3)   -- find last hit velocity
        lastNote = math.floor(lastNote)                      -- round it off        
        lastVel = math.floor(lastVel)                        -- round it off
        if toggleNoteHold == 1 then             -- if notehold is true, 
          noteHoldNumber = lastNote             -- set it to the last note received
        else 
          noteHoldNumber = -1                   -- set notehold to inapplicable value
        end 
        reaper.SetExtState(extName, 'noteHold', noteHoldNumber, false)   -- write the note hold number to extstate
      else                                      -- if noteoff, display no-note value
        lastNote = -1                           -- no note value, so set to inapplicable
      end                                       -- if vel not 0
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
          get the track name of the target note if RS5K
    --]]------------------------------]]--

function getInstanceTrackName(cursorNote)
  if cursorNote then                                 -- if there's a note under the cursor
    for j = 1, reaper.CountTracks(0) do              -- for each track
      tr = reaper.GetTrack(0, j - 1)                 -- get track
      fxCount = reaper.TrackFX_GetCount(tr)          -- count fx on each instance track
        
      for p = 0, fxCount-1 do                        -- for each fx
        retval, buf = reaper.TrackFX_GetNamedConfigParm( tr, p, "fx_name" )    -- get fx name
      
        if buf:match("ReaSamplOmatic5000")  then     -- if RS5K
          local _, param = reaper.TrackFX_GetParamName(tr, p, 3)               -- get param name        
          
          if param == "Note range start" then        -- if it's the right one, and if it's rs5k,
            noteStart = reaper.TrackFX_GetParam(tr, p, 3)        -- set/fix math for noteStart value
            noteStart = math.floor(noteStart*128) if noteStart == 128 then noteStart = noteStart - 1 end
            
            if cursorNote == noteStart then          -- if it's the same as our note under cursor,
              _, trName = reaper.GetTrackName( tr )  -- get track name  
            end
          end
        end                                          -- if RS5K
      end                                            -- for each fx
    end                                              -- for each track
  end
  return trName
end

-----------------------------------------------------------
    --[[------------------------------[[--
          get details of MIDI notes under cursor
    --]]------------------------------]]--
    
step = 0
function getCursorInfo()         -- this is a heavy action, run it as little as possible
  --reaper.ShowConsoleMsg("getCursorInfo called" .. "\n")
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local showNotes = {}           -- table consisting of sub-tables grouping Pitch and Vel
  local trackHeight              
  local take, takes, channel
  local targetNoteIndex, targetPitch  -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take
  window, _, _ = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local track = reaper.BR_GetMouseCursorContext_Track()
  local hZoom = reaper.GetHZoomLevel()

  if window ~= "midi editor" and hZoom > 2 then   -- ifn't ME, and if slightly zoomed in
    if track then                                                     -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")  -- set track height
      if cursorSource == 1 then                       -- if cursorSource is mouse cursor,
        take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse 
        cursorPos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
      else                                            -- if cursorSource is edit cursor,
        cursorPos = reaper.GetCursorPosition()        -- get pos at edit cursor
        local CountTrItem = reaper.CountTrackMediaItems(track)
        if CountTrItem then                           -- if track has items
          for i = 0, CountTrItem-1 do                 -- for each item,               
            local item = reaper.GetTrackMediaItem(track,i)      
            local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
            local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
            if itemStart <= cursorPos and itemEnd > cursorPos then  -- if edit cursor is within item bounds,
               take = reaper.GetTake( item, 0 )       -- get the take
            end
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
        item = reaper.BR_GetMouseCursorContext_Item()        -- get item under mouse
        position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert to PPQ
        --reaper.ShowConsoleMsg(position_ppq .. " _ ")
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

    return take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trackName, cursorPos
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

function GetItemsInRange(track, areaStart, areaEnd)
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


--]]-----------------------------------------------------------------------------------------
------------LOOP-----------------------------------------------------------------
-- [[-----------------------------------------------------------------

        
incrIndex = 2                   -- vars/setup for loop
loopCount = 0
idleCount = 0
lastX = 0
elapsed = 0
arrangeTime = 0
lastArrangeTime = 0
pop = 0 
editCurPosLast = -1

local elapsed 
local incr = {1, 10, 24, 48, 96, 240, 480, 960}

    --[[------------------------------[[--
          loop and show tooltips, cursor as necessary  
    --]]------------------------------]]--

function loop()
  loopCount = loopCount+1                                       -- advance loopcount
  idleCount = idleCount+1                                       -- advance idlecount
  editCurPos = reaper.GetCursorPosition()
  local lastMIDI = {}                                          
  reaper.ImGui_GetFrameCount(ctx)                               -- "a fast & inoffensive function"
   
  if reaper.HasExtState(extName, 'DoRefresh') then              -- update display, called from child scripts
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo()
    reaper.DeleteExtState(extName, 'DoRefresh', false)
    lastX = -1                                                  -- n/a x val fools the optimizer into resetting
    lastAllAreas = -1                                           -- allow reset after nudge for RE targeted notes
    reset = 1                                                   -- allow reset after nudge for cursor targeted notes
  end        
  
  if reaper.HasExtState(extName, 6) then                        -- set increment of nudge,
    q = tostring(reaper.GetExtState( extName, 6 ))              -- based on input from child script
    if incrIndex + q > 0 and incrIndex + q < 9 then             -- set bounds for incrIndex
      incrIndex = incrIndex + q
    end
    reaper.SetExtState(extName, 7, incr[incrIndex], true)       -- set incr extstatem, save between sessions
    reaper.DeleteExtState(extName, 6, false)                    -- delete increment setting extstate
  end   
    
  if reaper.HasExtState(extName, 'toggleCursor') then           -- toggle whether focus is edit or mouse cursor                                        -- fools the optimizer into resetting
    if cursorSource ~= 1 then                                   
      cursorSource = 1                                          
    elseif cursorSource == 1 then                               
      cursorSource = 0  
    end 
    reaper.SetExtState(extName, 8, cursorSource, true)          -- extstate management
    reaper.DeleteExtState(extName, 'toggleCursor', false)
  end
  
  if loopCount > resetCursor then                               -- if idle,
    cursorSource = 1                                            -- set cursor to mouse
    reaper.SetExtState(extName, 8, cursorSource, true)          -- set extstate to reflect the change
  end
  
  ------------------------------------------------------------ optimizer to reduce calls to getCursorInfo
  if loopCount >= 3 and info == "arrange" and lastX ~= x and pop == 0  -- if we're in the right place, and on the move
  or editCurPos ~= editCurPosLast then                                 -- or if the edit cursor has moved,
                                                                       -- get all the info:
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo() 
    
    if take ~= nil and reaper.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      idleCount = 0                                             -- reset loopcount
      lastX = x                                                 -- set lastX mouse position
    else                                                        -- if take is nil or isn't MIDI
      lastX = x                                                 -- set lastX mouse position
    end
    if reset == 1 then reset = 0 end                            -- set reset
  end                                                           
  
  ------------------------------------------------------------- are we holding a note?                                        
  if reaper.HasExtState(extName, 'noteHoldUpdate') then         
    noteHoldNumber = tostring(math.floor(reaper.GetExtState(extName, 'noteHold')))
    reaper.DeleteExtState(extName, 'noteHoldUpdate', false)
  end       

  if reaper.HasExtState(extName, 'toggleNoteHold') then         -- if extstate says we are holding a note,
    if toggleNoteHold == 0 and RazorEditSelectionExists() then  -- if RE exists but notehold is 0
      toggleNoteHold = 1                                        -- set notehold to 1
      if targetPitch then noteHoldNumber = targetPitch end      -- set the held note to the targetpitch 
      reaper.SetExtState(extName, "noteHold", noteHoldNumber, false)   -- write the note hold number to exstate
    elseif toggleNoteHold == 1 then                             -- toggle note hold value if 1
      toggleNoteHold = 0
      noteHoldNumber = -1
      reaper.SetExtState(extName, "noteHold", -1, false)        -- write the note hold number
    end
    reaper.DeleteExtState(extName, 'toggleNoteHold', false)     -- cleanup extstate
  end      
  
  if RazorEditSelectionExists() and noteHoldNumber ~= -1 then   -- ifn't RE and if noteholdnumber == -1   
  else
    toggleNoteHold = 0                                          
    reaper.SetExtState(extName, "noteHold", -1, false)          -- write the note hold number
  end
  
                                         -- insert last-received MIDI into table
  
  --------------------------------------------------------
  -- idle sensor -----------------------------------------
  --------------------------------------------------------
  if idleTask == 1 then
    while idleCount > 100 do
      if idleCount > 101 then break end         -- just do it once
      --reaper.ShowConsoleMsg("idle" .."\n")
      for i = 1, reaper.CountTracks(0) do
        track = reaper.GetTrack(0,i-1)
        item_num = reaper.CountTrackMediaItems(track)
        for j = 0, item_num-1 do -- LOOP THROUGH MEDIA ITEMS
          item = reaper.GetTrackMediaItem(track, j)
          for t = 0, reaper.CountTakes(item)-1 do       -- for each take,
            take = reaper.GetTake(item, t)              -- get take
            if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
              _, ccCount, _ = reaper.MIDI_CountEvts(take) -- count notes in current take 
              for n = 0, ccCount do
                _, _, _, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC( take, n )
                --reaper.ShowConsoleMsg(chan .. " " .. msg2 .. " " .. msg3 .. "\n")
                if chan == 15 and msg2 == 119 and msg3 == 1 then 
                   reaper.MIDI_DeleteCC( take, n )
                   --reaper.ShowConsoleMsg("deleted" .. "\n")
                end
              end
            end
          end
        end
      end
      break
    end
  end  
  
  ---------------------------------------------------  get last note hit and feed it into table 
  if loopCount < 500 then lastNote, lastVel = getLastNoteHit() end   -- if idle, stop getting lastnotehit                                                        
  x, y = reaper.GetMousePosition()                              -- mousepos
  _, info = reaper.GetThingFromPoint( x, y )                    -- mousedetails
  local skip = 0       
  
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
    
    if skip ~= 1 and toggleNoteHold == 0 then                   -- if incoming note is not present in table,
      lastMIDI[1] = {lastNote, lastVel, 0, 0} 
      table.insert(showNotes, 1, lastMIDI[1])                   -- insert it
      showNotes[1][7] = ""                                      -- blank n/a text readout values
      
      _, sourceTrName = reaper.GetTrackName( track )            -- get the name of the track where the note originates
      if sourceTrName == "sequencer" then                       -- if it's from a sequencer, 
        local trName = getInstanceTrackName(lastNote)           -- detect trackname of RS5K instance
        trName = "'" .. trName .. "'"                           -- pad with quote
      end
      
      if trName == nil then trName = "" end                     -- if nil, write empty
      showNotes[1][8] = trName                                  -- put into table
    end    
  
    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1) 
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  -------------------------------------------------------------------------------------------------
  ------------------------------GUI ---------------------------------------------------------------
  
  startTime, endTime = reaper.GetSet_ArrangeView2( 0, 0, 0, 0)      -- get arrangescreen pos
  arrangeTime = startTime + endTime                                 -- sum values to determine change
  
  if arrangeTime ~= lastArrangeTime then            -- if arrange screen bounds have moved
    elapsed = 0                                     -- timer == 0
    time_start = reaper.time_precise()              -- start the clock
    lastPixelLength = -1
    lastAllAreas = -1
  else                                              -- if arrange screen bounds haven't changed,
    elapsed = reaper.time_precise() - time_start    -- set elapsed time since arrange hasn't moved
  end
  lastArrangeTime = arrangeTime                     -- get last arrangetime value
  
  if cursorSource == 1 then curColor = 0xFFFF0000 else curColor = 0xFF0033FF end   -- set cursor colors

  --]]------------------------------------------------------------------
  ----------------multiple target notes in RE --------------------------  
  -- [[-----------------------------------------------------------------
  
  --if RazorEditSelectionExists() and info == arrange and noteHoldNumber ~= -1 and elapsed > .2 then      
  if noteHoldNumber == -1 then lastAllAreas = -1 end
  local areas 
  local zoom_lvl = reaper.GetHZoomLevel()   
  
  if RazorEditSelectionExists() then
    local areas = GetRazorEdits()          -- get all areas 
    areaNum = #areas                       -- get number of areas
    for i = 1, #areas do                   -- for each razor edit area
      --reaper.ShowConsoleMsg(i .. "\n")
      local areaData = areas[i]            -- get area data
      if not areaData.isEnvelope then      -- if it's not an envelope area
        if i == 1 then start_pos = areaData.areaStart end   -- get the first area's start position
        if i == #areas or i == #areas-1 then     -- if it's the last or second to last area (FIX)
          end_pos = areaData.areaEnd             -- get the last area's end position
        end -- if it's the last relevant area
      end   -- if it's not an envelope area
    end     -- for each area
    
    if lastAreaNum ~= areaNum then        -- if number of areas changed,
      lastAreaNum = areaNum
      lastAllAreas = -1                   -- reset print
    end
    
    if lastTCPheight ~= tcpHeight then
      lastTCPheight = tcpHeight
      lastAllAreas = -1
    end
    
    if lasttrPos ~= trPos then
      lasttrPos = trPos
      lastAllAreas = -1
    end
    
    allAreas = start_pos + end_pos         -- get the full area span
    
    if noteHoldNumber ~= nil and noteHoldNumber ~= -1 and elapsed > .2 then      
      if lastAllAreas ~= allAreas then
        --reaper.ShowConsoleMsg("areas is redrawn" .. "\n")
        lastAllAreas = allAreas
        areaStartPixel = math.floor((start_pos - startTime) * zoom_lvl)   -- get the pixel for area start BM
        areaEndPixel   = math.floor((end_pos   - startTime) * zoom_lvl)   -- get the pixel for area end BM
        areaLengthPixel = areaEndPixel-areaStartPixel                     -- area length in pixels
        reaper.JS_Composite_Unlink(track_window, guideLines, true)        -- unlink previous BM
        reaper.JS_LICE_DestroyBitmap(guideLines)                          -- destroy prev BM
        if tcpHeight == nil then tcpHeight = 0 end
        guideLines = reaper.JS_LICE_CreateBitmap(true, areaLengthPixel+3, tcpHeight)  -- create the BMM
        reaper.JS_LICE_Clear(guideLines, 0 )                              -- clear the BM
        
        for i = 1, #areas do                   --          -- for each area
          local areaData = areas[i]                        -- get area data
          if not areaData.isEnvelope then                  -- if it's not an envelope area
            reStart = areaData.areaStart                   -- get local area start
            reEnd = areaData.areaEnd                       -- get local area end
            local items = areaData.items                   -- get local area items
            for j = 1, #items do                           -- for each area item, 
              local item = items[j]                        -- get item from array
              local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")  -- get item start, end
              local itemEnd = itemStart+ reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
              for t = 0, reaper.CountTakes(item)-1 do       -- for each take,
                take = reaper.GetTake(item, t)              -- get take
                if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
                  razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reStart) 
                  razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reEnd) 
                  notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take                    
                  for n = notesCount-1, 0, -1 do          -- for each note, from back to front
                    _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
                    if startppq > razorStart_ppq_pos and startppq < razorEnd_ppq_pos then  -- if in RE bounds
                      if noteHoldNumber == pitch then     -- if it's the targeted pitch
                        noteStartPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)  -- note pos of note under cursor
                        noteEndPos =   reaper.MIDI_GetProjTimeFromPPQPos(take, endppq)      -- note pos of note under cursor
                        targetNotePixel    = math.floor((noteStartPos -  start_pos) * zoom_lvl)  -- note start pixel
                        targetNotePixelEnd = math.floor((noteEndPos   -  start_pos) * zoom_lvl)  -- note end pixel
                        if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
                        if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
                        pixelLength = targetNotePixelEnd-targetNotePixel    -- pixel length of note
                        -- red guidelines
                        --reaper.JS_LICE_Line( guideLines, targetNotePixel, 0, targetNotePixel,     tcpHeight,   curColor, 1,    "COPY", true )
                        reaper.JS_LICE_Line( guideLines, targetNotePixel,   0, targetNotePixelEnd+1 ,         0,            curColor, .25,       "COPY", true )  -- red guidelines
                        
                        --reaper.JS_LICE_Line( guideLines, targetNotePixelEnd+1, 0, targetNotePixelEnd+1, tcpHeight,  curColor, 1, "COPY", true )
                        -- black guidelines
                        reaper.JS_LICE_Line( guideLines, targetNotePixel+1, 0, targetNotePixel+1, tcpHeight,  0xFF000000, .1, "COPY", true )
                        reaper.JS_LICE_Line( guideLines, targetNotePixelEnd+2, 0, targetNotePixelEnd+2, tcpHeight,  0xFF000000, .1, "COPY", true )
                      end  -- if MIDI note is targeted                 
                    end  -- if MIDI note is within RE bounds
                  end -- for each note
                end -- if take is MIDI
              end -- for each take
            end -- for each item
          end -- if area isn't envelope
        end -- for each area
        if tcpHeight == nil then tcpHeight = 0 end
        if trPos == nil then trPos = 0 end
        reaper.JS_Composite(track_window, areaStartPixel, trPos, areaLengthPixel+3, tcpHeight - 3, guideLines, 0, 0, areaLengthPixel+3, 1, true) -- DRAW          
      end -- if area moved
    else  -- if notehold is off
      reaper.JS_Composite_Unlink(track_window, guideLines, true)
    end -- if notehold is on
  else -- if RE doesn't exist
    reaper.JS_Composite_Unlink(track_window, guideLines, true)
    noteHoldNumber = -1
  end  -- if RE exists

---]]-----------------------------------------------------------------
----------------single target note------------------------------------  
-- [[-----------------------------------------------------------------
 if targetPitch == nil then lastPixelLength = -1 end  -- if no note is under cursor, set lastval to n/a
  if targetPitch ~= nil and info == "arrange" and take ~= nil and noteHoldNumber == -1 and elapsed > .2 then 
    if targetNotePos then                           -- if there's a note pos to target,
      local zoom_lvl = reaper.GetHZoomLevel()       -- get rpr zoom level
      targetNotePixel    = math.floor((targetNotePos - startTime) * zoom_lvl) -- get note start pixel
      targetNotePixelEnd = math.floor((targetEndPos  - startTime) * zoom_lvl) -- get note end pixel
      if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
      if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
      pixelLength = targetNotePixelEnd-targetNotePixel    -- get pixel length of note
      
      alpha=1-((cursorPos-targetNotePos)/(targetEndPos-targetNotePos))
      alpha = .2*alpha+.1
      
      if lastPixelLength ~= pixelLength or alpha ~= lastAlpha then              -- if the last pixel length is different than this one,
        lastAlpha = alpha
        lastPixelLength = pixelLength
        reaper.JS_Composite_Unlink(track_window, targetGuideline, true)   -- LICE: destroy prev BM, set up new one, 
        reaper.JS_LICE_DestroyBitmap(targetGuideline)                     -- and draw colored guidelines.    
        targetGuideline = reaper.JS_LICE_CreateBitmap(true, pixelLength+3, tcpHeight)
        reaper.JS_LICE_Clear(targetGuideline, 0 )   -- clear
        --reaper.JS_LICE_Line( bitmap,          x1, y1,             x2,          y2,          color,    alpha,    mode,  antialias )
        --reaper.JS_LICE_Line( targetGuideline, 0,  0,              0,           tcpHeight,   curColor, 1,       "COPY", true )  -- red guidelines
        reaper.JS_LICE_Line( targetGuideline, 0,  0,              pixelLength, 0,           curColor, alpha,       "COPY", true )  -- red guidelines
        --reaper.JS_LICE_Line( targetGuideline, pixelLength+1, 0, pixelLength+1, tcpHeight,  curColor, 1, "COPY", true )
        reaper.JS_LICE_Line( targetGuideline, 0, 0, 0, tcpHeight,  0xFF000000, .1, "COPY", true ) -- black guidelines
        reaper.JS_LICE_Line( targetGuideline, pixelLength, 0, pixelLength, tcpHeight,  0xFF000000, .1, "COPY", true )
      end
      reaper.JS_Composite(track_window, targetNotePixel, trPos, pixelLength+3, tcpHeight - 3, targetGuideline, 0, 0, pixelLength+3, 1, true) -- DRAW          redraw = nil
    end
  else  -- if single target note conditions not met,
    reaper.JS_Composite_Unlink(track_window, targetGuideline, true)
    reaper.JS_LICE_DestroyBitmap(targetGuideline)
  end
    
  
--]]------------------------------------------------------------------
----------------READOUT: ReaImGUI note data display ------------------
--        this whole section, esp the spacing code, is clumsy
-- [[-----------------------------------------------------------------

    if targetPitch ~= nil and info == "arrange" and take ~= nil and elapsed > .2 then
      
      local sx, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, trPos+tcpHeight) 
      reaper.ImGui_SetNextWindowPos(ctx, sx, sy)   -- getting screen pos for readout
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
            
            octave = math.floor(showNotes[i][1]/12)-1                               -- establish the octave for readout
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
              increment = "-" .. reaper.GetExtState(extName, 7 )
                             
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
              "  d: " .. spacingD .. showNotes[i][3] .. "  " ..  showNotes[i][8] .. "  " .. increment  )
            end
          end
        end                                               -- for each shown note
               
        if toggleNoteHold == 1 and noteHoldNumber ~= -1 then 
          local trName = getInstanceTrackName(noteHoldNumber)
          trName = "'" .. trName .. "'" 
          local togPad = ""
          for j = 1, posStringSize[#posStringSize] do togPad = " " .. togPad end
          octave = math.floor(noteHoldNumber/12)-1                    -- establish the octave for readout
          cursorNoteSymbol = pitchList[(noteHoldNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
          reaper.ImGui_TextColored(ctx, 0x00FF45FF, togPad .. "n: " .. noteHoldNumber ..spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " .. "(RE target note)       " .. trName  ) 
        end
        
        reaper.ImGui_End(ctx)
      end                                                 -- if imgui begin
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopStyleVar(ctx)
    end           
    
    reaper.defer(loop)
    --elapsed = 1
    --lastArrangeTime = arrangeTime
    --elapsed = 0
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
    reaper.JS_LICE_DestroyBitmap( guideLines)
    reaper.JS_LICE_DestroyBitmap( targetGuideline)
    reaper.JS_LICE_DestroyBitmap( guideLinesShadow)
    reaper.JS_LICE_DestroyBitmap( targetGuideline)
  
    reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
    reaper.RefreshToolbar2( sec, cmd ) 
  end
  -----------------------------------------------
  _, _, sec, cmd = reaper.get_action_context()
  SetButtonON()
  reaper.atexit(SetButtonOFF)

--[[
 * Changelog:
* v1.79 (2023-11-20)
  + changed placement of readout to below track (y) , and a little before the note (x) for less eye flicker
  + replaced note on/off guidelines with note duration blocks: easier on the eyes and better at conveying targeted notes
  + added an alpha gradient to redraw alpha of indicator block to be less if further away from note start
  + added idleTask section. for now, it just cleans up a dummy CC that I use in my "copy MIDI in REs" script. 
    + in the future, this could be a general sanitizer to clean up audio items without fades, etc
    + i'll try to leave this off by default for public use but may occasionally forget
  + added elapsed optimzer to prevent multi-guideline redrawing on arrange view change
  + fixed tracks looking for other tracks' RS5K links for naming note instances
    + now, only tracks named "sequencer" will do this. a coarse fix, mostly for me.
* v1.78 (2023-11-16)
  + for "note hold" RE multi-targeting, improve text readout explaining what is happening
  + added multiple guidelines for when multiple notes are targeted in REs
  + changed shift increment readout to show "t" for "tick"
* v1.77 (2023-11-5)
  + reverted mouse clearing in 1.75, and instead attempted blanking displays while screen scrolling via reaper.BR_GetArrangeView()
* v1.76 (2023-11-9)
  + lost version, see next
* v1.75 (2023-11-5)
  + when middle mouse scrolling (hand scroll in my setup), don't print ghost lines
* v1.74 (2023-10-22)
  + print named note or RS5K instance trackname to MIDI readout
* v1.73 (2023-7-20)
  + if loopcount passes resetCursor value, then cursor resets to "under mouse"
  + remove padding for guideliness
* v1.72a (2023-7-20)
  + clearing REs turns off RE-last-hit focus
* v1.72 (2023-7-20)
  + transposing last-hit notes in RE now updates the last-hit note
* v1.71 (2023-7-19)
  + added ability to toggle holding of last hit note using script: mccrabney_MIDI edit - toggle hold input note for 'show notes'
    * running this action sets RE target note to note under cursor
    * inputting notes from controller will change target note.
    * running the script again again releases the note.
* v1.70 (2023-6-9)
  + guideliness drop shadows
* v1.69 (2023-6-9)
  + added ability to step through the notes/change target note currently under the cursor
    * use Script: mccrabney_MIDI edit - step through notes under cursor in 'show notes'.lua
    * targetNote will step through notes under cursor, closest to farthest.
* v1.68 (2023-6-9)
  + fixed bug where n.1.000 displayed as (n-1).1.000
* v1.67a (2023-6-8)
  + reverted 1.66 guidelines disable on middle click, bc it was suppressing middle clicks down w/out middle drag.
* v1.67 (2023-6-8)
  + added guidelines to show the noteOFF position
* v1.66 (2023-6-7)
  + time display: add support for time signatures other than 4/4
  + disable guidelines and text readout while left or middle clicking mouse
* v1.65 (2023-6-3)
  + fixed samedistance bug preventing closest note from being targeted
* v1.64 (2023-5-31)
  + added guidelines that indicates the target note: blue for edit cursor, red for mouse cursor
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

