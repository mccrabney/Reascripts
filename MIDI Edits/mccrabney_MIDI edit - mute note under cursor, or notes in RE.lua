--[[
 * ReaScript Name: mute notes under cursor, closest first
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.12
--]]
 
--[[
 * Changelog:
 * v1.12 (2023-5-27)
   + updated name of parent script extstate 
 * v1.11 (2023-05-09)
   + support REs first, notes under cursor if RE not present
 * v1.1 (2023-05-08)
   + requires extstates from mccrabney_MIDI edit - show notes, under cursor and last-received.lua
 * v1.0 (2023-05-02)
   + Initial Release
--]]

  
---------------------------------------------------------------------
    --[[------------------------------[[--
          get note and item under mouse   -- mccrabney      
    --]]------------------------------]]--

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
          mute notes whose ons are in RE if present, else mute note under mouse, closest first
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)
  
  if RazorEditSelectionExists() then
    job = 1
    task = 17
    SetGlobalParam(job, task, _)
  else
    take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
    if take ~= nil and targetNoteIndex ~= -1 then
      -- reaper.MIDI_SetNote( take, noteidx, selectedIn, mutedIn, startppqposIn, endppqposIn, chanIn, pitchIn, velIn, noSortIn )
      _, _, muteVal, _, _, _, _, _ = reaper.MIDI_GetNote(take, targetNoteIndex)
      
      if muteVal then muteVal = false elseif not muteVal then muteVal = true end
      
      reaper.MIDI_SetNote( take, targetNoteIndex, nil, muteVal, nil, nil, nil, nil, nil)
      reaper.MIDI_Sort(take)
      reaper.SetExtState(extName, 'DoRefresh', '1', false)
      octave = math.floor(targetNoteNumber/12)-1                               -- establish the octave for readout
      cursorNoteSymbol = pitchList[(targetNoteNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
      reaper.Undo_OnStateChange2(proj, "muted note " .. targetNoteNumber .. ", (" .. cursorNoteSymbol .. octave .. ")")
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

end
 
main()

