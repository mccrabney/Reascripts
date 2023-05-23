--[[
 * ReaScript Name: adjust length of note under mouse cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 (2023-05-19)
   + added hzoom dependent increment
 * v1.1 (2023-05-08)
   + requires extstates from mccrabney_MIDI edit - show notes, under mouse and last-received.lua
 * v1.0 (2023-01-01)
   + Initial Release
--]]

---------------------------------------------------------------------
extName = "mccrabney_MIDI edit - show notes, under mouse and last-received.lua"  

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI edits\\", "")
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
  
  local hZoom = reaper.GetHZoomLevel()
    
 --[[ if hZoom > 1 then incr = 1000 end
  if hZoom > 40 then incr = 500 end
  if hZoom > 100 then incr = 100 end
  if hZoom > 150 then incr = 50 end
  if hZoom > 200 then incr = 25 end
  if hZoom > 300 then incr = 10 end
  if hZoom > 400 then incr = 5 end--]]

  incr = 24
  task = 18
  job = 1  
  
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  if mouse_scroll > 0 then 
  elseif mouse_scroll < 0 then 
    incr = incr * -1                          -- how many ticks to move noteoff backwards, adjust as desired
  end
  
  if RazorEditSelectionExists() then
    SetGlobalParam(job, task, _, _, incr)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      _, _, _, startppqposNext, _, _, pitchNext, _ = reaper.MIDI_GetNote( take, targetNoteIndex+1 )
      
      if endppqpos-startppqpos + incr > 10 then 
        if pitch ~= pitchNext then
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, endppqpos + incr, nil, nil, nil, nil)
        else 
          if endppqpos + incr > startppqpos and endppqpos + incr < startppqposNext then
            reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, endppqpos + incr, nil, nil, nil, nil)
          end
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

  

  
  
