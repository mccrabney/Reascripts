--[[
 * ReaScript Name: adjust length of target notes (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.32
--]]
 
--[[
 * Changelog:
 * v1.32 (2024-4-9)
   + nudge increments now snap to next/prev increment division 
 * v1.31 (2023-5-27)
   + updated name of parent script extstate
 * v1.3 (2023-05-26)
   + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts" 
 * v1.2 (2023-05-19)
   + added hzoom dependent increment
 * v1.1 (2023-05-08)
   + requires extstates from mccrabney_MIDI edit - show notes, under mouse and last-received.lua
 * v1.0 (2023-01-01)
   + Initial Release
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
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
  
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  
  if mouse_scroll > 0 then 
    incr = incr     
    elseif mouse_scroll < 0 then 
    incr = incr * -1                          -- how many ticks to move noteoff backwards, adjust as desired
  end
  
  if RazorEditSelectionExists() then
    job = 1
    task = 18
    SetGlobalParam(job, task, _, _, incr)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, targetNoteIndex )
      _, _, _, startppqposNext, _, _, pitchNext, _ = reaper.MIDI_GetNote( take, targetNoteIndex+1 )
      
      comp = math.fmod(endppqpos, math.abs(incr))
      
      if endppqpos-startppqpos + incr > 10 then 
        
        if comp ~= 0 then 
          incr = incr - comp 
        end
        
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

  

  
  
