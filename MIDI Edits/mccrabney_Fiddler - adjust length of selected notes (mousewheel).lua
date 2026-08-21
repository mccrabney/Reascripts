--[[
 * ReaScript Name: adjust length of target notes (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.35
--]]
 
--[[
 * Changelog:
 * v1.35 (2026-08-21)
   + better RazorEditSelectionExists function
   + fixed multi-selected note ends
 * v1.34 (2025-1-3)
   + reaper.set_action_options(1)
  * v1.33 (2024-5-21)
   + switch to using local Razor Edit Function module
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
  end--for  
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

local numSel = 0

function main()
  reaper.PreventUIRefresh(1)
  
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  
  if mouse_scroll > 0 then 
    incr = incr     
    elseif mouse_scroll < 0 then 
    incr = incr * -1                          -- how many ticks to move noteoff backwards, adjust as desired
  end
  
  take, targetNoteNumber, targetNoteIndex = getNotesUnderMouseCursor()
  if take~=nil then 
    track = reaper.GetMediaItemTake_Track(take)
    reaper.SetOnlyTrackSelected(track)
  end
  
  if RazorEditSelectionExists() then
    job = 1
    task = 19
    SetGlobalParam(job, task, _, _, incr)
  else
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    if take ~= nil then
      track = reaper.GetMediaItemTake_Track(take)
      local selectedNotes = 0
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
      
        notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in take under mouse                    
        for n = notesCount-1, 0, -1 do                        -- for each note, from back to front
          _, selected, muteState, startppqpos, endposppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
          if selected == true then      -- if it's selected
            selectedNotes = selectedNotes + 1
          end
        end
      
        for i = 0, CountTrItem-1 do              -- for each item, last to first               
          item = reaper.GetTrackMediaItem(track,i)      
          take = reaper.GetTake( item, 0 )       -- get the take
          if take ~= nil then 
            notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
            
            for n = notesCount-1, 0, -1 do       -- for each note, last to first
              local _, selected, muteState, startppqpos, endposppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then           -- if it's selected
                numSel = numSel + 1              -- get number of selected notes in item
              end
            end
            
            for n = notesCount-1, 0, -1 do       -- for each note, last to first
              local _, selected, muteState, startppqpos, endposppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then           -- if it's selected
                _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote( take, n )
                _, _, _, startppqposNext, _, _, pitchNext, _ = reaper.MIDI_GetNote( take, n+1 )
                comp = math.fmod(endppqpos, math.abs(incr))  -- how much is needed to snap to grid
                
                if endppqpos-startppqpos + incr > 10 then   -- prevent notes from getting too small
                  --reaper.MIDI_DisableSort( take )
                  if comp ~= 0 and numSel == 1 then    -- if there's a comp and only 1 note is selected
                    incr = incr - comp            -- add enough to snap to grid
                  end
                  
                  if pitch ~= pitchNext then      -- 
                    reaper.MIDI_SetNote( take, n, nil, nil, nil, endppqpos + incr, nil, nil, nil, nil)
                  else                            -- if next note is same
                    if endppqpos + incr > startppqpos then      -- if endpoint doesn't precede start
                      reaper.MIDI_SetNote( take, n, nil, nil, nil, endppqpos + incr, nil, nil, nil, nil)
                    end
                  end
                end -- if endpos-startpos + incr is greater than 10
              end -- if it's selected
            end -- for each note 
          end -- if take not nil
        end -- for each item                
      end -- if track has items

      --reaper.MIDI_Sort(take)
      
      if selectedNotes > 0 then 
        reaper.Undo_OnStateChange2(proj, "changed length of MIDI note(s)")
      end
    end
  end
  --reaper.SetExtState(extName, 'DoRefresh', '1', false)
  
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

--]]

end
 
main()

  

  
  
