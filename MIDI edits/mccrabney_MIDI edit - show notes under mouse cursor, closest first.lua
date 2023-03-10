--[[
 * ReaScript Name: show notes under mouse cursor, closest first
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 + v1.1 (2023-03-10)
   + limited calls to BR_GetMouseCursorContext to prevent UI jerkiness
 * v1.0 (2023-02-01)
   + Initial Release
--]]


---------------------------------------------------------------------

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

loopCount = 0 

local pitchList = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local showNotes = {}
local channel

local ctx = reaper.ImGui_CreateContext('crabvision')
local sans_serif = reaper.ImGui_CreateFont('sans_serif', 15)
reaper.ImGui_Attach(ctx, sans_serif)

-----------------------------------------------------------
function getMouseInfo()
  local trackHeight
  local takes, channel
  local pitchUnderCursor = {}    -- pitches of notes under the cursor (for undo)
  local targetNote, targetPitch              -- initialize target variable
  local numberNotes = 0
  local item, position_ppq, take, note
  window, _, _ = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local track = reaper.BR_GetMouseCursorContext_Track()
  local hZoom = reaper.GetHZoomLevel()
 
  if window ~= "midi editor" and hZoom > 8 then   -- ifn't ME, and if slightly zoomed in
    if track ~= nil then                      -- if there is a track
      trackHeight = reaper.GetMediaTrackInfo_Value( track, "I_TCPH")  -- get trackheight
    end
    
    local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
    if take ~= nil and trackHeight > 25 then      -- if track height isn't tiny
      if reaper.TakeIsMIDI(take) then 
        local pitchSorted = {}                  -- pitches under cursor to be sorted
        local notesUnderCursor = {}             -- item notecount numbers under the cursor
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
            pitchUnderCursor[numberNotes] = pitch                 -- get the pitch to reference for undo message
            pitchSorted[numberNotes] = pitch
            notesUnderCursor[numberNotes] = n                     -- add the notecount number to the array
            distanceFromMouse[numberNotes] = position_ppq - startppq       -- put distance to cursor in index position reference table
            distanceSorted[numberNotes] = position_ppq - startppq          -- put distance to cursor in index position of sorting table
          end
        end
        
        table.sort(distanceSorted)  -- sort the note table so the closest noteon is at index position 1
        table.sort(pitchSorted)     -- sort the pitch table so the lowest pitch is at index position 1
               
        local targetNoteDistance = distanceSorted[1]                 -- find the distance from mouse cursor of the closest noteon
        local lowestPitch = pitchSorted[1]                            -- find the lowest pitch in array
        local sameDistance = 0                                        -- initialize the sameDistance variable
        local sameLowest
               
        for j = 1, #distanceSorted do                                 -- for each entry in the sorted distance array
          if distanceSorted[j] == distanceSorted[j+1] then            -- if entries are equal
            sameDistance = sameDistance+1
            
            for p = 1, #distanceFromMouse do                          -- for each entry in the distancefrommouse array
              if distanceFromMouse[p] == distanceSorted[1] then      -- if distFromMouse index = closest note entry,
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
          end                                     
        end                                                         -- end for each entry in array
               
        --~~~~~~~  multiple equidistant notes
        if sameDistance > 0 then                          -- if there are notes that are the same distance from mouse
          for t = 1, #distanceFromMouse do                 -- for each entry in the unsorted pitch array
            if lowestPitch == pitchUnderCursor[t] then    -- if the entry matchest the closest note distance from mouse cursor
              targetPitch = lowestPitch
              targetNote = notesUnderCursor[sameLowest]
            end
          end
        end
      end           -- if take is MIDI
    end             -- if take not nil
         
    table.sort(pitchUnderCursor)
    return pitchUnderCursor, note, take, targetNote, targetPitch
  end
end

----------------------------------------------------------------------------------
local function loop()
  
  reaper.ImGui_GetFrameCount(ctx) -- a fast & inoffensive function
  
  loopCount = loopCount+1
  x, y = reaper.GetMousePosition()
  _, info = reaper.GetThingFromPoint( x, y )
  
  if loopCount >= 5 and info == "arrange" then 
    showNotes, cursorNote, take, targetNote, targetPitch = getMouseInfo()
    loopCount = 0
  end                             -- defer delay
  
  if cursorNote ~= nil and info == "arrange" then       -- if mouseover note,
    if take ~= nil and reaper.TakeIsMIDI(take) then 
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
           
        for i = #showNotes, 1, -1 do
          if showNotes[i] ~= nil and targetPitch ~= nil then
            local octave = math.floor(showNotes[i]/12)-1
            local cursorNoteSymbol = (showNotes[i] - 12*(octave+1)+1) 
              
            if showNotes[i] == targetPitch then
              reaper.ImGui_TextColored(ctx, 0xFF8383FF, " " .. pitchList[cursorNoteSymbol] .. octave .. " (" .. showNotes[i] .. ")")
            else
              reaper.ImGui_TextColored(ctx, 0xFFFFFFFF, pitchList[cursorNoteSymbol] .. octave .. " (" .. showNotes[i] .. ")")
            end
          end
        end
        
        reaper.ImGui_End(ctx)
      end
      
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopFont(ctx)
      reaper.ImGui_PopStyleVar(ctx)
    end
  else
    lastNote = -1
  end                   -- if take and cursornote ain't nil 

  reaper.defer(loop)
end

--------------------------------------------
reaper.defer(loop)


