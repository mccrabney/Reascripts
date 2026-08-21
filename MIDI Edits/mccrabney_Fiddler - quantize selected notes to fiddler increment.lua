--[[
 * ReaScript Name: quantize selected notes to Fiddler increment
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00

-- @provides
--   Modules/Sexan_Area_51_mouse_mccrabney_tweak.lua > mccrabney_Fiddler - nudge target notes (mousewheel)/Sexan_Area_51_mouse_mccrabney_tweak.lua
--   Modules/mccrabney_MIDI_Under_Mouse.lua          > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_MIDI_Under_Mouse.lua
--   Modules/mccrabney_Razor_Edit_functions.lua      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_Razor_Edit_functions.lua
--   Modules/mccrabney_misc.lua                      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_misc.lua

--]]
 
--[[
 * Changelog:
 * v1.1 (
   + better RazorEditSelectionExists function
 * v1.0 (2025-06-11)
   + 
--]]

---------------------------------------------------------------------
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1,2)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/mccrabney_MIDI_Under_Mouse")
require("Modules/mccrabney_misc")
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")   -- GET DIRECTORY FOR REQUIRE  -- AREA MOUSE INPUT HANDLING

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

selectedNotes = 0
      

function main()
  reaper.PreventUIRefresh(1)
  local incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  
  local take, _, _, targetNoteIndex = getCursorInfo() 
  
  local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
  
  if take ~= nil then
    local track = reaper.GetMediaItemTake_Track(take)
    local ME_grid, swing = reaper.MIDI_GetGrid( take )
    reaper.MIDI_DisableSort(take)
    local CountTrItem = reaper.CountTrackMediaItems(track)
    if CountTrItem then                           -- if track has items
      
      notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in take under mouse                    
      for n = notesCount-1, 0, -1 do                  -- for each note, from back to front
        _, selected, muteState, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
        if selected == true then                  -- if it's selected
          selectedNotes = selectedNotes + 1
        end
      end
  
      if RazorEditSelectionExists() and selectedNotes == 0 then  -- perform the edit on RE
        job = 1
        task = 18                                 -- select all notes in RE
        SetGlobalParam(job, task, _, _, incr)     -- 
      end
      
      if not RazorEditSelectionExists() and selectedNotes == 0 then 
        reaper.MIDI_SetNote( take, targetNoteIndex, true) 
        selectedNotes = 1
      end
    
      for i = 0, CountTrItem-1 do              -- for each item, last to first               
        local item = reaper.GetTrackMediaItem(track,i)      
        local take = reaper.GetTake( item, 0 )       -- get the take
        if take ~= nil then 
          notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
          for n = notesCount-1, 0, -1 do       -- for each note, last to first
            local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, n )
------------------------------------------------MPL-----------
            if selected then
              local proj_time = reaper.MIDI_GetProjTimeFromPPQPos( take, startppqpos )
              local beats, _, _, tpos_beats = reaper.TimeMap2_timeToBeats( proj, proj_time )
              local out_pos, out_ppq, out_beatpos
              if swing == 0 then
                if (beats % ME_grid) < (ME_grid/2) then out_beatpos = tpos_beats - (beats % ME_grid) else out_beatpos = tpos_beats - (beats % ME_grid) + ME_grid end
                out_pos = TimeMap2_beatsToTime( 0, out_beatpos)
                out_ppq = MIDI_GetPPQPosFromProjTime( take, out_pos )
              else
                local midval = 0.5 + 0.25*swing
                local checkval = 0.5 * (beats % (ME_grid*2)) / ME_grid
                if checkval < midval then 
                  -- before swing grid
                  if checkval < 0.5*midval then 
                    out_beatpos = tpos_beats - (beats % ME_grid)  
                  else 
                    if swing < 0 then 
                      out_beatpos = tpos_beats - (beats % ME_grid) + ME_grid*midval*2
                    else
                      out_beatpos = tpos_beats - (beats % ME_grid) + ME_grid*swing/2
                      if checkval % midval < 0.5 then out_beatpos = out_beatpos + ME_grid end
                    end
                  end            
                else 
                  -- after swing grid
                  if checkval < midval + 0.5*  (1-midval)  then 
                    out_beatpos = tpos_beats - (beats % ME_grid) + ME_grid * 0.5 * swing
                  else 
                    out_beatpos = tpos_beats - (beats % ME_grid) + ME_grid
                  end            
                end
                out_pos = TimeMap2_beatsToTime( 0, out_beatpos)
                out_ppq = MIDI_GetPPQPosFromProjTime( take, out_pos )          
              end  
              if out_ppq then 
                MIDI_SetNote( take, n, true, muted, out_ppq, out_ppq + endppqpos - startppqpos, chan, pitch, vel, true )
              end
            end
-----------------------------------------------------thanks MPL----------------
          end -- for each note
        end -- if take not nil
        reaper.MIDI_Sort(take)
        --reaper.SetExtState(extName, 'DoRefresh', '1', false)
      end -- for each item
    end -- if track has items
  end -- if take is not nil
  
  if selectedNotes > 0 then 
    reaper.Undo_OnStateChange2(proj, "quantized note(s)")
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end -- main

main()

