--[[
 * ReaScript Name: show notes, under mouse and last-received
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.41
--]]
 
--[[
 * Changelog:
 * v1.41 (2023-5-04)
   + fixed show last-hit MIDI note, appears in green, replacing existing readout if present
 * v1.4 (2023-5-04)
   + added velocity readout for all notes, despite last comment. thanks, cfillion!
   + more cleanup
 * v1.3 (2023-5-03)
   + added velocity readout for target note only
      - note, readout for all notes unlikely due to (necessarily) sorted pitchUnderCursor[]
   + misc cleanup
 * v1.2 (2023-5-01)
   + fixed error message on MIDI item glue
 * v1.1 (2023-03-12)
   + fixed retriggering upon new MIDI notes
 * v1.0 (2023-03-12)
   + Initial Release -- "Crab Vision" (combined previous scripts)
--]]


---------------------------------------------------------------------
dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

loopCount = 0
loopReset = 0
lastX = 0

local pitchList = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local pitchUnderCursor = {}
local channel
local ctx = reaper.ImGui_CreateContext('crabvision')
local sans_serif = reaper.ImGui_CreateFont('sans_serif', 15)
reaper.ImGui_Attach(ctx, sans_serif)


---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track -- mccrabney        
    --]]------------------------------]]--

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
  return lastNote, lastVel         -- lastNoteHit is a referenced variable for edits
end                                             -- end function


-----------------------------------------------------------
    --[[------------------------------[[--
          sparingly call GetMouseCursorContext for some under-mouse details -- mccrabney        
    --]]------------------------------]]--
    
function getMouseInfo()
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local pitchWithVel = {}    -- table consisting of sub-tables grouping Pitch and Vel
  
  local trackHeight
  local takes, channel
  local targetPitch  -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take, note
  window, _, _ = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local track = reaper.BR_GetMouseCursorContext_Track()
  local hZoom = reaper.GetHZoomLevel()
 
  if window ~= "midi editor" and hZoom > 8 then   -- ifn't ME, and if slightly zoomed in
    if track ~= nil then                      -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")
    end
    
    local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
    if take ~= nil and trackHeight > 25 then      -- if track height isn't tiny
      if reaper.TakeIsMIDI(take) then 
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromMouse = {}            -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
        position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos) -- convert to PPQ
        local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
        
        for n = notesCount-1, 0, -1 do
          _, selected, _, startppq, endppq, _, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note start/end position              
          
          if startppq <= position_ppq and endppq >= position_ppq then -- is current note the note under the cursor?
            note = pitch
            numberNotes = numberNotes+1                           -- add to count of how many notes are under mouse cursor
            
            pitchWithVel[numberNotes] = {pitch, vel}              -- get the pitch and corresponding velocity as table-in-table
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
            targetPitch = pitchWithVel[i][1]                -- get the pitch value of the closest note
          end                                     
        end                                                         -- end for each entry in array
               
        --~~~~~~~  multiple equidistant notes
        if sameDistance > 0 then                          -- if there are notes that are the same distance from mouse
          for t = 1, #distanceFromMouse do                 -- for each entry in the unsorted pitch array
            if lowestPitch == pitchWithVel[t][1] then    -- if the entry matchest the closest note distance from mouse cursor
              targetPitch = lowestPitch
            end
          end
        end
      end           -- if take is MIDI
    end             -- if take not nil
         
    table.sort(pitchWithVel, function(a, b)
      return a[1] < b[1]
    end)
    
    return take, targetPitch, pitchWithVel
    
  end
end


-----------------------------------------------------------
    --[[------------------------------[[--
          loop and show tooltips as necessary  -- mccrabney        
    --]]------------------------------]]--
    
pop = 0 

local function loop()
  local lastMIDI = {}
                                                                -- reset loop from external scripts
  if reaper.HasExtState('mccrabney_MIDI edit - show notes, under mouse and last-received.lua', 'DoRefresh') then
    reaper.DeleteExtState('mccrabney_MIDI edit - show notes, under mouse and last-received.lua', 'DoRefresh', false)
    lastX = -1                                                  -- fools the optimizer into resetting
  end
 
  reaper.ImGui_GetFrameCount(ctx)                               -- "a fast & inoffensive function"
   
  loopCount = loopCount+1                                       -- advance loopcount
  
  x, y = reaper.GetMousePosition()                              -- mousepos
  _, info = reaper.GetThingFromPoint( x, y )                    -- mousedetails
                                                                -- optimizer to reduce calls to getMouseInfo
  if loopCount >= 5 and info == "arrange" and lastX ~= x and pop == 0 then 
    take, targetPitch, pitchWithVel = getMouseInfo()
    if take ~= nil and reaper.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      lastX = x                                                 -- set lastX mouse position
    end
  end                                                           -- end optimizer
  
  if loopCount < 500 then                                       -- optimizer2, stops checking for last note if idle
    lastNote, lastVel = getLastNoteHit()   
  end                                                           -- end optimizer2

  if lastNote == -1 then pop = 0 end

  local skip = 0                                                -- insert last-received MIDI into table
  if lastNote ~= -1 and lastNote ~= nil and take ~= nil and pop == 0 then
    pop = 1                                                     -- MIDI is being received
                          -- package the pitch/vel info
    local currentVel
    for i = 1, #pitchWithVel do                                 -- check each note to see if it is already present
      if lastNote == pitchWithVel[i][1] then 
        currentVel = pitchWithVel[i][2]
        skip = 1
      end  
    end    
    
    if skip ~= 1 then
      lastMIDI[1] = {lastNote, lastVel} 
      table.insert(pitchWithVel, 1, lastMIDI[1]) 
    else
      --lastMIDI[1] = {lastNote, currentVel} 
      --table.remove(pitchWithVel, 1)
      --table.insert(pitchWithVel, 1, lastMIDI[1])
    end   

    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1) 
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  
  if targetPitch ~= nil and info == "arrange" and take ~= nil then  -- if mousing over a note in a MIDI item in arrange
    local x, y = reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition())
    reaper.ImGui_SetNextWindowPos(ctx, x - 11, y + 25)
    reaper.ImGui_PushFont(ctx, sans_serif)  
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x0F0F0FD8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 12)

    if reaper.ImGui_Begin(ctx, 'Tooltip', false,
    reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoDecoration() |
    reaper.ImGui_WindowFlags_TopMost() |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    
      local octaveNote                                  -- variables for readout
      local noteSymbol                                  
      local color = 0x00F992FF
      local spacing = ""
          
      for i = #pitchWithVel, 1, -1 do                   -- for each top-level entry in the pitchWithVel table,
        if pitchWithVel[1] ~= nil and targetPitch ~= nil then
        
          octave = math.floor(pitchWithVel[i][1]/12)-1                    -- establish the octave for readout
          cursorNoteSymbol = (pitchWithVel[i][1] - 12*(octave+1)+1)       -- establish the note symbol for readout
        
          if pitchWithVel[i][1] == targetPitch and pitchWithVel[i][1] ~= lastNote then  -- color red if entry matches the target note & no lastNote
            color = 0xFF8383FF                             -- red                        
            spacing = ""                                  -- no indentation
          elseif pitchWithVel[i][1] == lastNote and pop == 1 then      -- if 
            notePresent = 1
            pitchWithVel[i][2] = lastVel
            color = 0x00F992FF                            -- green
            spacing = "" 
          elseif pitchWithVel[i][1] ~= lastNote then 
            color = 0xFFFFFFFF                            -- white
            spacing = " "                                 -- slight indentation
          end                                             -- end color readout red if entry matches the target note
          
          table.sort(pitchWithVel, function(a, b) return a[1] < b[1] end)
        
          if i-1 ~= nil and pitchWithVel[i] ~= pitchWithVel[i+1] then
            reaper.ImGui_TextColored(ctx, color, spacing .. pitchWithVel[i][1] .. " " .. pitchList[cursorNoteSymbol] .. octave .. " " .. pitchWithVel[i][2])
          end
        end
      end                                               -- for each shown note
       
    reaper.ImGui_End(ctx)
    end        -- if imgui begin
    
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleVar(ctx)
  end            -- if take, cursornote, and loopReset conditions are met
  
  reaper.defer(loop)
end

--------------------------------------------

function main()

  reaper.defer(loop)
end
----------------------------

main()
