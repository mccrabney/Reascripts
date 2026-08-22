--[[
 * ReaScript Name: transpose note closest to mouse (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
 * Changelog:
 * v1.00 (2026-08-22)
   + initial release
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1)

-----------------------------------------------------------
    --[[------------------------------[[--
          check for razor edit 
    --]]------------------------------]]--
    
function RazorEditSelectionExists()
  for i = 0, reaper.CountTracks(0)-1 do
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then 
    return true end
  end
  return false
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
  
  take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  if take ~= nil then 
    track = reaper.GetMediaItemTake_Track(take)
    reaper.SetOnlyTrackSelected(track)
  end
  
  if RazorEditSelectionExists() then
    job = 1
    task = 21  
    SetGlobalParam(job, task, _, _, incr)
  else
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take then 
      track = reaper.GetMediaItemTake_Track(take)
      reaper.SetOnlyTrackSelected(track)
      reaper.MIDI_DisableSort(take)
      
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item,               
          item = reaper.GetTrackMediaItem(track,i)      
          take = reaper.GetTake( item, 0 )       -- get the take
          if take ~= nil then 
            notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
            for n = notesCount-1, 0, -1 do                        -- for each note, from back to front
              _, selected, muteState, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
              if n == targetNoteIndex then               -- if it's the note closest to mouse
                _, _, _, startppqpos,  endppqpos,  _,  pitch, _ = reaper.MIDI_GetNote( take, n )
                _, _, _, startppqposPrev, endppqposPrev, _, pitchPrev, _ = reaper.MIDI_GetNote( take, n -1)
                _, _, _, startppqposNext, endppqposNext, _, pitchNext, _ = reaper.MIDI_GetNote( take, n +1)
                
                
                pitch = pitch + incr
                if pitch > 127 then pitch = 127 end
                if pitch < 0 then pitch = 0 end  
                
                reaper.MIDI_SetNote( take, n, nil, nil, nil, nil, nil, pitch, nil)
              end
            end
          end
        end
      end
      reaper.MIDI_Sort(take)
    end
  end
  
  reaper.Undo_OnStateChange2(proj, "transposed note(s)" )
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

end
 
main()
