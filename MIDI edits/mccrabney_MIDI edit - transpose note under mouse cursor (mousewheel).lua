--[[
 * ReaScript Name: transpose note under mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2023-05-10)
   + fixed disappearing overlapping notes
 * v1.0 (2023-05-08)
   + requires extstates from mccrabney_MIDI edit - show notes, under mouse and last-received.lua
--]]

---------------------------------------------------------------------
extName = "mccrabney_MIDI edit - show notes, under mouse and last-received.lua"  

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   


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
      if reaper.HasExtState(extName, t+4) then
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
  reaper.PreventUIRefresh(1)
  
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  if mouse_scroll > 0 then 
    incr = 1                           -- how many vels to up notes
  elseif mouse_scroll < 0 then 
    incr = -1                          -- how many vels to down notes
  end
  
  if RazorEditSelectionExists() then
    job = 1
    task = 21  
    SetGlobalParam(job, task, _, _, incr)
  else
    
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
    
      _, _, _, startppqpos,  endppqpos,  _,  pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      _, _, _, startppqposPrev, endppqposPrev, _, pitchPrev, _ = reaper.MIDI_GetNote( take, targetNoteIndex -1)
      _, _, _, startppqposNext, endppqposNext, _, pitchNext, _ = reaper.MIDI_GetNote( take, targetNoteIndex +1)
      
      
      if pitch + incr == pitchNext or pitch + incr == pitchPrev then 
        if startppqpos >= startppqposPrev and startppqpos <= endppqposPrev then
          reaper.MIDI_SetNote( take, targetNoteIndex -1, nil, nil, nil, startppqpos, nil, nil, nil)
        end
      end
      
      --[[
      if math.abs(pitchPrev-pitch) == 1 or math.abs(pitch-pitchNext) == 1 then 
        if startppqpos >= startppqposPrev and startppqpos <= endppqposPrev then
          reaper.MIDI_SetNote( take, targetNoteIndex -1, nil, nil, nil, startppqpos, nil, nil, nil)
        end
      end
      
      --]]
      
      
      pitch = pitch + incr
      if pitch > 127 then pitch = 127 end
      if pitch < 0 then pitch = 0 end  
      
      reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, nil, nil, pitch, nil)
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "transposed " .. targetNoteNumber .. "(" .. cursorNoteSymbol .. octave .. ")" .. " to " .. targetNoteNumber+incr .. "(" .. cursorNoteSymbol .. octave .. ")")
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

end
 
main()

  

  
  
