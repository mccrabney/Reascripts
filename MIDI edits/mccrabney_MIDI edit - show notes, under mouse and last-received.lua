--[[
 * ReaScript Name: show notes, under mouse and last-received
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.3
--]]
 
--[[
 * Changelog:
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
local showNotes = {}
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
        lastNote =reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastNote = math.floor(lastNote)
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
  return lastNote         -- lastNoteHit is a referenced variable for edits
end                                             -- end function


-----------------------------------------------------------
    --[[------------------------------[[--
          sparingly call GetMouseCursorContext for some under-mouse details -- mccrabney        
    --]]------------------------------]]--
    
function getMouseInfo()
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local notesUnderCursor = {}    -- item notecount numbers under the cursor
  local velUnderCursor = {}      -- ... vel
  
  local trackHeight
  local takes, channel
  local targetNote, targetPitch  -- initialize target variable
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
            velUnderCursor[numberNotes] = vel            
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch
            notesUnderCursor[numberNotes] = n                     -- add the notecount number to the array
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
            targetPitch = pitchUnderCursor[i]                -- get the pitch value of the closest note
            targetNote = notesUnderCursor[i]
            targetVel = velUnderCursor[i]
          end                                     
        end                                                         -- end for each entry in array
               
        --~~~~~~~  multiple equidistant notes
        if sameDistance > 0 then                          -- if there are notes that are the same distance from mouse
          for t = 1, #distanceFromMouse do                 -- for each entry in the unsorted pitch array
            if lowestPitch == pitchUnderCursor[t] then    -- if the entry matchest the closest note distance from mouse cursor
              targetPitch = lowestPitch
              targetNote = notesUnderCursor[sameLowest]
              targetVel = velUnderCursor[sameLowest]
            end
          end
        end
      end           -- if take is MIDI
    end             -- if take not nil
         
    table.sort(pitchUnderCursor) 
    return pitchUnderCursor, note, take, targetNote, targetPitch, targetVel
    
  end
end


-----------------------------------------------------------
    --[[------------------------------[[--
          loop and show tooltips as necessary  -- mccrabney        
    --]]------------------------------]]--
    
pop = 0 

local function loop()

  if reaper.HasExtState('mccrabney_MIDI edit - show notes, under mouse and last-received.lua', 'DoRefresh') then
    reaper.DeleteExtState('mccrabney_MIDI edit - show notes, under mouse and last-received.lua', 'DoRefresh', false)
    lastX = -1   -- use to fool the optimizer into resetting
  end
 
  reaper.ImGui_GetFrameCount(ctx) -- a fast & inoffensive function
   
  loopCount = loopCount+1
  
  x, y = reaper.GetMousePosition()
  _, info = reaper.GetThingFromPoint( x, y )
   
  if loopCount >= 5 and info == "arrange" and lastX ~= x and pop == 0 then 
    showNotes, cursorNote, take, targetNote, targetPitch, showVel = getMouseInfo()
    
    if take ~= nil and reaper.TakeIsMIDI(take) then
      loopCount = 0
      lastX = x
    end
  end                     -- optimizer, must meet criteria in order to call getMouseInfo
  
  if loopCount < 500 then
    note = getLastNoteHit()   
  end                     -- optimizer, stops checking for last note if idle

  if note ~= -1 and note ~= nil and take ~= nil and pop == 0 then
    pop = 1
    table.insert(showNotes, 1, note)
    table.sort(showNotes)
  end
  
  if note == -1 and pop == 1 then 
    lastX = -1
  end
  
  if cursorNote ~= nil and info == "arrange" then
    if take ~= nil then
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
      
        local octaveNote 
        local noteSymbol
        
        if note ~= -1 and note ~= nil then
          octaveNote = math.floor(note/12)-1
          noteSymbol = (note - 12*(octaveNote+1)+1) 
        else pop = 0 end
        
        local color
        local spacing
        
        for i = #showNotes, 1, -1 do
          if showNotes[i] ~= nil and targetPitch ~= nil then            
            octave = math.floor(showNotes[i]/12)-1
            cursorNoteSymbol = (showNotes[i] - 12*(octave+1)+1) 
            
            if showNotes[i] == targetPitch then
              color = 0xFF8383FF
              spacing = ""
            else
              color = 0xFFFFFFFF
              spacing = " "
            end  -- if match
            
            if i-1 ~= nil and showNotes[i] ~= showNotes[i+1] then
              if showNotes[i] == targetPitch then 
                --showVel = tostring(showVel)
                reaper.ImGui_TextColored(ctx, color, spacing .. "#" .. showNotes[i] .. " (" .. pitchList[cursorNoteSymbol] .. octave  .. "), "  .. showVel)
              elseif showNotes[i] ~= targetPitch then 
                reaper.ImGui_TextColored(ctx, color, spacing .. "#" .. showNotes[i] .. " (" .. pitchList[cursorNoteSymbol] .. octave  .. ") ")
              end
            end              
          end    -- if not nil
        end      -- for each shown note
         
      reaper.ImGui_End(ctx)
      end        -- if imgui begin
    
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopFont(ctx)
      reaper.ImGui_PopStyleVar(ctx)
    end 
  end                   -- if take, cursornote, and loopReset conditions are met
  
  reaper.defer(loop)
end

--------------------------------------------

function main()

  reaper.defer(loop)
end
----------------------------

main()
