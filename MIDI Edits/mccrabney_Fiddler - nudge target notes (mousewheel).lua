--[[
 * ReaScript Name: nudge target notes (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.43

-- @provides
--   Modules/Sexan_Area_51_mouse_mccrabney_tweak.lua > mccrabney_Fiddler - nudge target notes (mousewheel)/Sexan_Area_51_mouse_mccrabney_tweak.lua
--   Modules/mccrabney_MIDI_Under_Mouse.lua          > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_MIDI_Under_Mouse.lua
--   Modules/mccrabney_Razor_Edit_functions.lua      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_Razor_Edit_functions.lua
--   Modules/mccrabney_misc.lua                      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_misc.lua

--]]
 
--[[
 * Changelog:

 * v1.44 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.43 (2024-4-7)
   + nudge increments now snap to next/prev increment division 
 * v1.42 (2023-12-23)
   + fixed loss of target note if "step" function has been engaged
 * v1.41 (2023-12-23)
   + disable refresh (do in Fiddler script instead)
 * v1.40 (2023-12-08)
   + conform to changes in other scripts 
 * v1.39 (2023-6-11)
   + reset step upon nudge 
   + switch target cursor to edit cursor upon nudge - makes more predictable
 * v1.38 (2023-6-11)
   + bring up to speed with "shownotes" target note selector feature 
 * v1.37a 2023-6-9)
   + reverted previous negatively nudged note change
 * v1.37 (2023-6-8)
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
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/mccrabney_MIDI_Under_Mouse")
require("Modules/mccrabney_misc")
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")   -- GET DIRECTORY FOR REQUIRE  -- AREA MOUSE INPUT HANDLING

if reaper.HasExtState(extName, 8) then                        -- get cursor
  cursorSource = tonumber(reaper.GetExtState( extName, 8 ))         -- based on input from child script
else
  cursorSource = 1
end

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
  
  
function getNotesUnderMouseCursor()
  
  showNotes = {}
  numVars = tonumber(reaper.GetExtState(extName, 1 ))
  tableSize = tonumber(reaper.GetExtState(extName, 2 ))
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 4 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+numVars) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  
  return take, targetNoteNumber, targetNoteIndex
end


---------------------------------------------------------------------
    --[[------------------------------[[--
          nudge notes whose ons are in RE if present, else nudge note under mouse, closest first
    --]]------------------------------]]--

function main()
  step = tonumber(reaper.GetExtState(extName, 0 ))
  --reaper.ShowConsoleMsg("step " .. step .. "\n")
  --reaper.SetExtState(extName, 'DoRefresh', '1', false)
  --reaper.SetExtState(extName, 'SlowRefresh', '1', false)
  reaper.ClearConsole()  
  reaper.PreventUIRefresh(1)
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  
  --take, targetPitch, targetNoteIndex, targetNotePos, track, tcpHeight, cursorSource = getCursorInfo()
  take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo() 
  --_, _, targetNoteIndex = getNotesUnderMouseCursor()
  --reaper.ShowConsoleMsg("nudge - " .. targetPitch .. "\n")
  
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

      --reaper.ShowConsoleMsg("targetnoteindex: " .. targetNoteIndex .. "\n")
      --reaper.ShowConsoleMsg("start: " .. startppqpos .. "\n")
      --reaper.ShowConsoleMsg("incr: " .. incr .. "\n")
      
      comp = math.fmod(startppqpos, math.abs(incr))

      
      --if targetNoteIndex - 1 == -1 then reaper.ShowConsoleMsg("-1" .. "\n") end
      if targetNoteIndex - 1 == -1 then pitch2 = -1 end
      
      if incr > 0 then 
        if comp ~= 0 then 
          incr = incr - comp 
          --reaper.ShowConsoleMsg("comp: " .. comp .. "\n")
          
        end

        _, _, _, startppqposNext, _, _, pitch2, _ = reaper.MIDI_GetNote( take, targetNoteIndex +1 )      
        _, _, _, startppqposPrev, endposppqPrev, _, _, _ = reaper.MIDI_GetNote( take, targetNoteIndex -1 )
        --reaper.ShowConsoleMsg("startppqposPrev: " .. targetNoteIndex - 1 .. " " .. startppqposPrev .. "\n")
        
        if pitch == pitch2 and endposppq + incr < startppqposNext then 
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
        end
      end
      
      if incr < 0 then
        if comp ~= 0 then 
          incr = comp * -1
        end
        
--      if targetNoteIndex - 1 or targetNoteIndex +1  == 0
        _, _, _, startppqposPrev, endposppqPrev, _, pitch2, _ = reaper.MIDI_GetNote( take, targetNoteIndex -1 ) 
        _, _, _, startppqposNext, _, _, _, _ = reaper.MIDI_GetNote( take, targetNoteIndex +1 )
        
        if pitch == pitch2 and startppqpos + incr > endposppqPrev then 
          reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
        end
      end
      
      --reaper.ShowConsoleMsg("amount added: " .. incr .. "\n")
      --reaper.ShowConsoleMsg(notePPQ .. "\n")
      
      local targetChange = 0
      if pitch ~= pitch2 and pitch2 ~= -1 then                                     -- if two different notes
        if incr > 0 and startppqposNext ~= 0 then                 -- if moving forwards
          if startppqpos + incr == startppqposNext then           -- if nudge encroaches on next note 
            targetChange = 1
            incr = incr + 1                                       -- add 1 tick to incr
          end
        elseif incr < 0 and startppqposPrev ~= 0 then             -- if nudge encroaches on prev note
          if startppqpos + incr == startppqposPrev then           -- subtract 1 tick to incr
            targetChange = -1
            incr = incr - 1
          end
        end
        
        --reaper.ShowConsoleMsg(incr .. "\n")
        
        reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
      end

      if cursorSource == 0 then         -- 
        reaper.SetExtState(extName, 'stepDown', 1, false) 
      else
        reaper.SetExtState(extName, 'toggleCursor', 1, true)
        reaper.SetExtState(extName, 'stepDown', 1, false) 
      end
     
      local newTime = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + incr)
      reaper.SetEditCurPos( newTime, 1, 0)
      
      reaper.MIDI_Sort(take)
    
      octave = math.floor(targetPitch/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetPitch - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "nudged note " .. targetPitch .. "(" .. cursorNoteSymbol .. octave .. ")")
    end
    
    --reaper.SetExtState(extName, 'DoRefresh', '1', false)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
  end
  

end

main()

