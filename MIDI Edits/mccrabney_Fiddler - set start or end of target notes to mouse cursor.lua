--[[
 * ReaScript Name: set start or end of target note to mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.01
--]]
 
--[[
 * Changelog:
 * v1.01 (2024-11-4)
  * improve conditions when changed notes overlap with notes of the same pitch
 * v1.00 (2024-11-4)
 
--]]

--[[
  howto: this script changes the target cursor to EDIT (blue) and adjusts the length to mousepos
  if mouse is after target notestart, running this script will adjust note endpoint.
  if mouse is before target notestart, the note startpoint will move to mouse point.
  if your target cursor is currently on EDIT but no note is found, this script will swap cursor to MOUSE
  and you can run it again to change the length of the note under mouse cursor.
--]]


---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

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
          refer to extstates to get MIDI under mouse
    --]]------------------------------]]--
    
function getNotesUnderMouseCursor()
  showNotes = {}
  numVars = tonumber(reaper.GetExtState(extName, 1 ))
  tableSize = tonumber(reaper.GetExtState(extName, 2 ))
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 4 ))
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+4) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  
  return take, targetNoteNumber, targetNoteIndex, numTargets
end

function getMouseInfo()    
  local item, mouseposppq, take, note
  window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
  
  if details == "item" or inline_editor then         -- hovering over item in arrange
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
  
    if reaper.TakeIsMIDI(take) then -- is take MIDI?
      item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
      mouseposppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos)) -- convert to PPQ
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      for n = notesCount-1, 0, -1 do
        _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position              

      end
    end 
  end     
  
  return take, item, mouseposppq, notesCount
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          set start or end of target note to mouse cursor
    --]]------------------------------]]--

function main()
  reaper.ClearConsole()
  reaper.PreventUIRefresh(1)
  
  if RazorEditSelectionExists() then
  else
    local take, selectedItem, mouseposppq, notesCount = getMouseInfo()
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
    
    if cursorSource == 0 and targetNoteNumber == nil then 
      reaper.SetExtState(extName, 'toggleCursor', 1, true)
      reaper.SetExtState(extName, 'DoRefresh', 1, true)
    end
    
    if cursorSource ~= 0 then 
      reaper.SetExtState(extName, 'toggleCursor', 1, true)
      reaper.SetExtState(extName, 'DoRefresh', 1, true)
    end
    
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      
      if mouseposppq ~= nil then              -- if mouse is pointing at item
        match = 0
        for n = notesCount, 0, -1 do        -- for each note, last to first, get ppqs of the next/prev instances of note
          if n ~= targetNoteIndex then
            _, _, _, checkStart, checkEnd, _, checkPitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position              
            
            if pitch == checkPitch and endppqpos < checkStart then -- if pitch matches target and its start is greater than target end
              match = 1
              --reaper.ShowConsoleMsg("next pitchmatch's start is past target end" .. "\n")
              --reaper.ShowConsoleMsg("match n: " .. n .. "\n")
              --reaper.ShowConsoleMsg("targetindex: " .. targetNoteIndex .. "\n")
              startppqposNext = checkStart
              --reaper.ShowConsoleMsg("startppqposNext: " .. startppqposNext .. "\n")
            elseif pitch == checkPitch and startppqpos > checkEnd then -- if pitch matches target and end is before targetstart 
              match = 1 
              endppqposPrev = checkEnd
              --reaper.ShowConsoleMsg("prev pitchmatch's end is before target start " .. "\n")
              --reaper.ShowConsoleMsg("match n: " .. n .. "\n")
              --reaper.ShowConsoleMsg("targetindex: " .. targetNoteIndex .. "\n")
              --reaper.ShowConsoleMsg("endppqposPrev: " .. endppqposPrev .. "\n")
              --reaper.ShowConsoleMsg("break loop" .."\n")
              break
            end
          end
        end
        
        --reaper.ShowConsoleMsg("startppqpos: " .. startppqpos .. "\n")
        
        if mouseposppq > startppqpos and startppqposNext ~= nil then     -- if mouse cursor is greater than notestart
          --reaper.ShowConsoleMsg("\n" .. "mouse cursor is greater than notestart and there is a nextnote" .. "\n")
          --reaper.ShowConsoleMsg("mousepos: " .. mouseposppq .. "\n")
          --reaper.ShowConsoleMsg("startppqposNext: " .. startppqposNext .. "\n")
          --reaper.ShowConsoleMsg("match= " .. match .. "\n")
          if match ~= 1 then
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, mouseposppq, nil, nil, nil, nil)  -- set length to mousecursor
          elseif mouseposppq < startppqposNext and match == 1 then   -- mouse cursor is before next pitchmatch
            --reaper.ShowConsoleMsg("mouse cursor is before next pitchmatch" .. "\n")
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, mouseposppq, nil, nil, nil, nil)  -- set length to mousecursor
          elseif mouseposppq > startppqposNext and match == 1 then  -- mouse cursor is past next note start
            --reaper.ShowConsoleMsg("mouse cursor is past next note start" .. "\n")
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, startppqposNext-1, nil, nil, nil, nil)  -- set length to next note
          end
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)  
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to noteon
        end
        
        if mouseposppq > startppqpos and startppqposNext == nil then  -- if no next note
          --reaper.ShowConsoleMsg("mousepos: " .. mouseposppq .. "\n")
          
          --reaper.ShowConsoleMsg("\n" .. "mouse cursor is greater than notestart and there is no nextnote" .. "\n")
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, mouseposppq, nil, nil, nil, nil)  -- set length to next note
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)  
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to noteon
        end
        
        if mouseposppq < startppqpos and endppqposPrev ~= nil then     -- if mouse cursor is less than notestart
          --reaper.ShowConsoleMsg("\n" .. "mouse cursor is less than notestart and there is a prevnote" .. "\n")
          --reaper.ShowConsoleMsg("mousepos: " .. mouseposppq .. "\n")
          --reaper.ShowConsoleMsg("endppqposPrev: " .. endppqposPrev .. "\n")
          --reaper.ShowConsoleMsg("match= " .. match .. "\n")
          
          if mouseposppq > endppqposPrev then --
            --reaper.ShowConsoleMsg("mouse cursor is past prev note end " .. "\n")
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, mouseposppq, nil, nil, nil, nil, nil)
          elseif mouseposppq < endppqposPrev then
            --reaper.ShowConsoleMsg("mouse cursor is less than prev note end " .. "\n")
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, endppqposPrev+1, nil, nil, nil, nil, nil)  -- set length to next note
          end
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)  
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to noteon
        end
  
        if mouseposppq < startppqpos and endppqposPrev == nil then  -- if no prev note 
          --reaper.ShowConsoleMsg("\n" .. "mouse cursor is earlier than notestart and there is no prevnote" .. "\n")
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, mouseposppq, nil, nil, nil, nil, nil)  -- set length to next note
          curPos = reaper.MIDI_GetProjTimeFromPPQPos(take, mouseposppq)  
          reaper.SetEditCurPos(curPos, 1, 0)  -- set cursor to noteon
        end
      end
      
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "changed length of note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
 
main()

  

  
  
