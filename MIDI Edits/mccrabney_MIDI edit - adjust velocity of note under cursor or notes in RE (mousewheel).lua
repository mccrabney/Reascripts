--[[
 * ReaScript Name: adjust velocity of note under cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.12
--]]
 
--[[
 * Changelog:
 * v1.12 (2023-10-16)
   + fixed scenario where extstate doesn't exist yet
 * v1.11 (2023-5-27)
   + updated name of parent script extstate 
 * v1.1 (2023-05-26)
   + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts"
 * v1.0 (2023-05-08)
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
  if incr == nil then incr = 1
  if incr == 10 then incr = 2
  elseif incr == 24 then incr = 4
  elseif incr == 48 then incr = 8
  elseif incr == 96 then incr = 16
  elseif incr >= 240 then incr = 32
  end
  
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  
  if mouse_scroll > 0 then 
    incr = incr                          -- how many vels to up notes
  elseif mouse_scroll < 0 then 
    incr = incr*-1                        -- how many vels to down notes
  end
  
  if RazorEditSelectionExists() then
    job = 1
    task = 20  
    SetGlobalParam(job, task, _, _, incr)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
    
      _, _, _, _, _, _, _, vel = reaper.MIDI_GetNote( take, targetNoteIndex )
  
      vel = vel+incr
      if vel > 127 then vel = 127 end
      if vel < 1 then vel = 1 end
       
      reaper.MIDI_SetNote( take, targetNoteIndex, nil, nil, nil, nil, nil, nil, vel)
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "changed velocity of note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

end
 
main()

  

  
  
