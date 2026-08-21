--[[
 * ReaScript Name: select previous or next note on track (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.9
--]]
 
--[[
 * Changelog:
 * v1.9 (
   + better RazorEditSelectionExists function
 * v1.8 (2025-9-27)
   + re-adapted from "nudge notes" script
   + mouse cursor moves with selection 
--]]
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


local startTime, endTime = reaper.GetSet_ArrangeView2( 0, 0, 0, 0)  -- get arrangescreen pos
local zoom_lvl = reaper.GetHZoomLevel()  

local main_wnd = reaper.GetMainHwnd()                                -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW

if reaper.HasExtState(extName, 7) then
  incr = tostring(reaper.GetExtState( extName, 7 ))
end

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
          select next/prev note and move edit cursor
    --]]------------------------------]]--

selectedNotes = 0
      

function main()
  reaper.PreventUIRefresh(1)
  
  _, _, a, b, c, device, direction  = reaper.get_action_context() 
  --reaper.ShowConsoleMsg(a .. " | " .. b .. " | " .. c .. " | " .. device .. " | " .. direction .. "\n")
  
  if device == 16383 and direction == 129      -- for relative 
  or device == 127   and direction >= 15 then    -- for mousewheel
    incr = 1
  end
  
  if device == 16383 and direction == 16383     -- for relative
  or device == 127   and direction <= -15 then    -- for mousewheel
    incr = -1
  end  
  
  take, _, _, targetNoteIndex, _, _, _, _, _, _, cursorPos = getCursorInfo() 
  x, y = reaper.GetMousePosition()
  
  noteTable = {}
  if take ~= nil then 
    track = reaper.GetMediaItemTake_Track(take)
    reaper.SetOnlyTrackSelected(track)
  end
  
  if not RazorEditSelectionExists() then            -- perform the edit on RE                                          -- perform the edit on extState target note
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    if take ~= nil then
      reaper.MIDI_DisableSort(take)
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in take under mouse                    
        local i = -1                  -- in order to assess selection status of idx 0
        while i < notesCount-1 do     -- check to see if there are selected notes in the item
          local nextSel = reaper.MIDI_EnumSelNotes(take, i)  -- get idx of next selected note
          if nextSel ~= -1 then       -- if there is one,
            selectedNotes = 1
            i = nextSel               -- set i to next selected note idx 
          else                        -- if there isn't
            break                     -- 
          end                         -- 
        end                           -- end the while loop
        
        if selectedNotes == 0 then    
          if targetNoteIndex ~= -1 then 
            reaper.MIDI_SetNote( take, targetNoteIndex, true) 
          end
          selectedNotes = 1
        end
      
        if selectedNotes == 1 then
          if incr == 1 then
            for n = notesCount-1, 0, -1 do       -- for each note, last to first
              _, selected, _, startppqpos, endposppq, _, _, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then           -- if it's selected
                if n + incr > notesCount-1 then incr = 0 end
                reaper.MIDI_SelectAll(take, false)
                reaper.MIDI_SetNote( take, n + incr, true, nil, nil, nil, nil, nil, nil, nil)
              end
            end -- for each note
          end
          
          if incr == -1 then
            for n = 0, notesCount-1, 1 do       -- for each note, first to lsat
              _, selected, _, startppqpos, endposppq, _, _, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then           -- if it's selected
                if n + incr < 0 then incr = 0 end
                reaper.MIDI_SelectAll(take, false)
                reaper.MIDI_SetNote( take, n + incr, true, nil, nil, nil, nil, nil, nil, nil)
                
              end
            end -- for each note
          end
          
          for n = notesCount-1, 0, -1 do                  -- for each note, from back to front
            _, selected, muteState, startppqpos, endposppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
            if selected == true then
              notePos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + (endposppq - startppqpos)/2) -- move cursor to middle of next/prev note
              editCurPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos) -- move cursor to middle of next/prev note
              notePosPixel = math.floor((notePos - startTime) * zoom_lvl) -- note start pixel
              local sx, sy = reaper.JS_Window_ClientToScreen( track_window, notePosPixel, y )
              reaper.SetEditCurPos(editCurPos, 1, 0)
              reaper.JS_Mouse_SetPosition(sx, y)
              --reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_HSCROLL10"), 0)
              --_, _= reaper.GetSet_ArrangeView2(0, isSet, screen_x_start, screen_x_end, start_time, end_time )
            end
          end
        end
      end -- if track has items
    end -- if take is not nil
  end -- if not razor edit
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end -- main

main()

