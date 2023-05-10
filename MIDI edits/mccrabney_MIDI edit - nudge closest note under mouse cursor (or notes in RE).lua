--[[
 * ReaScript Name: nudge closest note under mouse cursor (or notes in RE)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2023-05-09)
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
  tableSize = tonumber(reaper.GetExtState(extName, 1 ))
  guidString = reaper.GetExtState(extName, 2 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 3 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 4 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+4) then
        for i in string.gmatch(reaper.GetExtState(extName, t+4), "-?%d+,?") do
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
    incr = 100                           -- how many ticks to move noteoff forwards, adjust as desired
    task = 6
    job = 1
  elseif mouse_scroll < 0 then 
    incr = -100                          -- how many ticks to move noteoff backwards, adjust as desired
    task = 7
    job = 1
  end
  
  if RazorEditSelectionExists() then
    SetGlobalParam(job, task, _)
    else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endposppqpos, _, _, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, startppqpos + incr, endposppqpos + incr, nil, nil, nil, nil)
      reaper.MIDI_Sort(take)
      
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "nudged note " .. targetNoteNumber .. "(" .. cursorNoteSymbol .. octave .. ")")
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
  end
end
 
main()

  

  
  
