--[[
 * ReaScript Name: nudge closest note under cursor (or notes in RE)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.34
--]]
 
--[[
 * Changelog:
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

local cursorSource
function main()
  
  reaper.PreventUIRefresh(1)
  
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  cursorSource = tonumber(reaper.GetExtState(extName, 8 )) 
  if cursorSource == nil then cursorSource = 0 end
  
  _,_,_,_,_,device,direction  = reaper.get_action_context() 
  --_,_,a,b,c,device,direction  = reaper.get_action_context() 
  --reaper.ShowConsoleMsg(a .. " | " .. b .. " | " .. c .. " | " .. device .. " | " .. direction .. "\n")
  
  if device == 16383 and direction == 129      -- for relative 
  or device == 127 and direction >= 15 then    -- for mousewheel
    incr = incr
  end
  
  if device == 16383 and direction == 16383     -- for relative
  or device == 127 and direction <= -15 then    -- for mousewheel
    incr = incr * -1
  end  
  
  --reaper.ShowConsoleMsg(incr .. "\n")
  
  if RazorEditSelectionExists() then
    job = 1
    task = 6
    SetGlobalParam(job, task, _, _, incr)
  else
  
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endposppq, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      
      if cursorSource ~= 1 then 
        local newTime = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + incr)
        reaper.SetEditCurPos( newTime, 1, 0)
      end
      
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

      if pitch ~= pitch2 then
        reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
      end
      
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      reaper.MIDI_Sort(take)
    
      
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "nudged note " .. targetNoteNumber .. "(" .. cursorNoteSymbol .. octave .. ")")
    end
    
    --reaper.DeleteExtState(extName, 8, false)
    
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
  end
end
 
main()


  

  
  
