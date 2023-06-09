--[[
 * ReaScript Name: nudge closest note under cursor (or notes in RE)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.37
--]]
 
--[[
 * Changelog:
 * v1.37 (2023-6-3)
   + fixed equidistant note nudge bug
   + if negatively nudged note occupies same space as another note, add 1 tick instead of subtracting one tick
 * v1.36 (2023-6-3)
   + reverted to local getCursorInfo function, prevents de-sync with "show notes" script
 * v1.35 (2023-5-28)
   + disallow nudged note from occupying the same tick position as the next/previous note
 * v1.34 (2023-5-27)
   + added relative support
 * v1.33 (2023-5-27)
   + updated name of parent script extstate 
 * v1.32 (2023-05-26)
   + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts" 
 * v1.31 (2023-05-21)
   + removed hzoom dependent increment
   + fixed note overwrite bug
 * v1.3 (2023-05-19)
   + added hzoom dependent increment
 * v1.2 (2023-05-11)
   + updated to prevent notes from escaping RE bounds
 * v1.1 (2023-05-09)
   + requires extstates from mccrabney_MIDI edit - show notes, under mouse and last-received.lua
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'

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
  

-----------------------------------------------------------
    --[[------------------------------[[--
          get details of MIDI notes under mouse -- mccrabney        
    --]]------------------------------]]--
    
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
    end
 
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse 
    cursorSource = tonumber(reaper.GetExtState(extName, 8 )) 
    if cursorSource == 1 then
      cursorPos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
    else
      cursorPos = reaper.GetCursorPosition()   -- get pos at edit cursor
    end
            
    if take and trackHeight > 25 then -- and cursorSource == 0 then      -- if track height isn't tiny
      if reaper.TakeIsMIDI(take) then 
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local distanceFromCursor = {}            -- corresponding distances of notes from mouse
        local distanceSorted = {}               -- ^ same, but to be sorted
        item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
        position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos) -- convert to PPQ
        local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
        
        for n = notesCount-1, 0, -1 do
          _, selected, muted, startppq, endppq, ch, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note start/end position              
          
          if startppq <= position_ppq and endppq >= position_ppq then  -- is current note the note under the cursor?
            notePos = reaper.MIDI_GetProjTimeFromPPQPos( take, startppq)
            
            numberNotes = numberNotes+1                           -- add to count of how many notes are under cursor
            noteLength = math.floor(endppq - startppq)
            showNotes[numberNotes] = {pitch, vel, noteLength, ch+1, n, tostring(muted), posString}   -- get the pitch and corresponding velocity as table-in-table
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch
            distanceFromCursor[numberNotes] = position_ppq - startppq       -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppq          -- put distance to cursor in index position of sorting table
          end
        end
        
        table.sort(distanceSorted)  -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)     -- sort the pitch table so the lowest pitch is at index position 1
        local targetNoteDistance = distanceSorted[1]                  -- find the distance from cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local sameDistance = 0                                        -- initialize the sameDistance variable
        local sameLowest
               
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            if j == 1 then sameDistance = sameDistance+1 end 
            for p = 1, #distanceFromCursor do                          -- for each entry in the distanceFromCursor array
              if distanceFromCursor[p] == distanceSorted[1] then       -- if distFromMouse index = closest note entry,
                sameLowest = p                                         -- get the index 
              end
            end 
          end
        end
        
                  --~~~~~~~  multiple equidistant notes
        if sameDistance > 0 then                           -- if there are notes that are the same distance from mouse
          for t = 1, #distanceFromCursor do                 -- for each entry in the unsorted distance array
            if targetNoteDistance == distanceSorted[t] then         -- if the entry matchest the closest note distance from cursor
              targetNoteIndex = showNotes[t][5]          
              targetPitch = showNotes[t][1]
            end
          end
        end
                 
        --~~~~~~~  closest note
        for i = 1, #distanceFromCursor do                        -- for each entry in the unsorted distance array
          if targetNoteDistance == distanceFromCursor[i] and sameDistance == 0 then   
            targetNoteIndex = showNotes[i][5]
            targetPitch = showNotes[i][1]                  -- get the pitch value of the closest note
          end                                     
        end                                                
        
        
        
      end           -- if take is MIDI
    end             -- if take not nil
         
    table.sort(showNotes, function(a, b)                -- sort the shownotes table
      return a[1] < b[1]
    end)
    
    if targetNoteIndex then 
      _, _, _, targetPPQ, _, _, _, _= reaper.MIDI_GetNote(take, targetNoteIndex) -- get note start/end position              
      targetNotePos = reaper.MIDI_GetProjTimeFromPPQPos( take, targetPPQ)
      track = reaper.GetMediaItemTake_Track( take )
      trPos = reaper.GetMediaTrackInfo_Value( track, 'I_TCPY' )
      tcpHeight = reaper.GetMediaTrackInfo_Value( track, 'I_TCPH')
    end 
    
  return take, targetPitch, targetNoteIndex, targetNotePos, track, trPos, tcpHeight, cursorSource
  end
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          nudge notes whose ons are in RE if present, else nudge note under mouse, closest first
    --]]------------------------------]]--

function main()
  
  reaper.SetExtState(extName, 'DoRefresh', '1', false)
    
  reaper.PreventUIRefresh(1)
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  
  take, targetNoteNumber, targetNoteIndex, _, track, trPos, tcpHeight, cursorSource = getCursorInfo()
  
  _,_,a,b,c,device,direction  = reaper.get_action_context() 
  --reaper.ShowConsoleMsg(a .. " | " .. b .. " | " .. c .. " | " .. device .. " | " .. direction .. "\n")
  
  if device == 16383 and direction == 129      -- for relative 
  or device == 127 and direction >= 15 then    -- for mousewheel
    incr = incr
  end
  
  if device == 16383 and direction == 16383     -- for relative
  or device == 127 and direction <= -15 then    -- for mousewheel
    incr = incr * -1
  end  
  
  if RazorEditSelectionExists() then            -- perform the edit on RE
    job = 1
    task = 6
    SetGlobalParam(job, task, _, _, incr)
  else                                          -- perform the edit on extState target note
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil and targetNoteIndex ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endposppq, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
    
      if incr > 0 then 
        _, _, _, startppqposNext, _, _, pitch2, _ = reaper.MIDI_GetNote( take, targetNoteIndex +1 )      
        _, _, _, startppqposPrev, endposppqPrev, _, _, _ = reaper.MIDI_GetNote( take, targetNoteIndex -1 )
        if pitch == pitch2 and endposppq + incr < startppqposNext then 
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
        end
      end
      
      if incr < 0 then
        _, _, _, startppqposPrev, endposppqPrev, _, pitch2, _ = reaper.MIDI_GetNote( take, targetNoteIndex -1 ) 
        _, _, _, startppqposNext, _, _, _, _ = reaper.MIDI_GetNote( take, targetNoteIndex +1 )
        if pitch == pitch2 and startppqpos + incr > endposppqPrev then 
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
        end
      end
      
      if pitch ~= pitch2 then             -- if two different notes
        if incr > 0 then                  -- if moving forwards
          if startppqpos + incr == startppqposNext then           -- if nudge encroaches on next note 
            incr = incr + 1                                       -- add 1 tick to incr
          end
        elseif incr < 0 then                                      -- if nudge encroaches on prev note
          if startppqpos + incr == startppqposPrev then           -- subtract 1 tick to incr
            incr = incr + 1
          end
        end
        reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
      end
     
      if cursorSource ~= 1 then 
        local newTime = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + incr)
        reaper.SetEditCurPos( newTime, 1, 0)
      end
      
      reaper.MIDI_Sort(take)
    
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "nudged note " .. targetNoteNumber .. "(" .. cursorNoteSymbol .. octave .. ")")
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
  end
  

end

main()

