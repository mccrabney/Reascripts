--[[
 * ReaScript Name: nudge target notes (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.40
 * Provides: Modules/*.lua
--]]
 
--[[
 * Changelog:
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
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
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
  
---------------------------------------------------------------------
    --[[------------------------------[[--
          nudge notes whose ons are in RE if present, else nudge note under mouse, closest first
    --]]------------------------------]]--

function main()
  
  --reaper.SetExtState(extName, 'DoRefresh', '1', false)
  --reaper.SetExtState(extName, 'SlowRefresh', '1', false)
    
  reaper.PreventUIRefresh(1)
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  
  --take, targetPitch, targetNoteIndex, targetNotePos, track, tcpHeight, cursorSource = getCursorInfo()
  take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo() 
  
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
      
      local targetChange = 0
      if pitch ~= pitch2 then             -- if two different notes
        if incr > 0 then                  -- if moving forwards
          if startppqpos + incr == startppqposNext then           -- if nudge encroaches on next note 
            targetChange = 1
            incr = incr + 1                                       -- add 1 tick to incr
          end
        elseif incr < 0 then                                      -- if nudge encroaches on prev note
          if startppqpos + incr == startppqposPrev then           -- subtract 1 tick to incr
            targetChange = -1
            incr = incr - 1
          end
        end
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
    
    reaper.SetExtState(extName, 'DoRefresh', '1', false)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
  end
  

end

main()

