--[[
 * ReaScript Name: nudge target notes (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 2.00

-- @provides
--   Modules/Sexan_Area_51_mouse_mccrabney_tweak.lua > mccrabney_Fiddler - nudge target notes (mousewheel)/Sexan_Area_51_mouse_mccrabney_tweak.lua
--   Modules/mccrabney_MIDI_Under_Mouse.lua          > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_MIDI_Under_Mouse.lua
--   Modules/mccrabney_Razor_Edit_functions.lua      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_Razor_Edit_functions.lua
--   Modules/mccrabney_misc.lua                      > mccrabney_Fiddler - nudge target notes (mousewheel)/mccrabney_misc.lua

--]]
 
--[[
 * Changelog:

 * v2.00 (2025)
   + better RazorEditSelectionExists function
   + nudge mouse cursor with note nudge

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
          nudge notes whose ons are in RE if present, else nudge note under mouse, closest first
    --]]------------------------------]]--

selectedNotes = 0
      

function main()
  --step = tonumber(reaper.GetExtState(extName, 0 ))
  reaper.PreventUIRefresh(1)
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  if incr == nil then incr = 0 end
  
  _, _, a, b, c, device, direction  = reaper.get_action_context() 
  --reaper.ShowConsoleMsg(a .. " | " .. b .. " | " .. c .. " | " .. device .. " | " .. direction .. "\n")
  
  if device == 16383 and direction == 129      -- for relative 
  or device == 127   and direction >= 15 then    -- for mousewheel
    incr = incr
  end
  
  if device == 16383 and direction == 16383     -- for relative
  or device == 127   and direction <= -15 then    -- for mousewheel
    incr = incr * -1
  end  
  
  take, _, _, targetNoteIndex, _, _, _, _, _, _, cursorPos = getCursorInfo() 
  x, y = reaper.GetMousePosition()
  
  noteTable = {}
  if take ~= nil then 
    track = reaper.GetMediaItemTake_Track(take)
    reaper.SetOnlyTrackSelected(track)
  end
  
  if RazorEditSelectionExists() then            -- perform the edit on RE
    job = 1
    task = 6
    SetGlobalParam(job, task, _, _, incr)
    --reaper.ShowConsoleMsg(incr .. "\n")
  else                                          -- perform the edit on extState target note
    local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    
    --if take ~= nil and targetNoteIndex ~= nil and targetNoteIndex ~= -1 then
    if take ~= nil then
      reaper.MIDI_DisableSort(take)
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        
        notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in take under mouse                    
        for n = notesCount-1, 0, -1 do                  -- for each note, from back to front
          _, selected, muteState, startppqpos, endposppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
          if selected == true then                  -- if it's selected
            selectedNotes = selectedNotes + 1
          end
        end
        
        if selectedNotes == 0 then 
          reaper.MIDI_SetNote( take, targetNoteIndex, true) 
          selectedNotes = 1
        end
      
        if selectedNotes == 1 then
          notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
          for n = notesCount-1, 0, -1 do       -- for each note, last to first
            _, selected, _, startppqpos, endposppq, _, _, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
            if selected == true then           -- if it's selected
              comp = math.fmod(startppqpos, math.abs(incr))
              
              if incr > 0 then 
                if comp ~= 0 then incr = incr - comp end
              elseif incr < 0 then
                if comp ~= 0 then incr = comp * -1 end
              end
              
              reaper.MIDI_SetNote( take, n, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
              local newTime = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + incr)
              reaper.SetEditCurPos( newTime, 1, 0)
              
              cursorPosPpq = reaper.MIDI_GetPPQPosFromProjTime(take, cursorPos)
              if cursorPosPpq > startppqpos and cursorPosPpq < endposppq then
                cursorPos = reaper.MIDI_GetProjTimeFromPPQPos(take, cursorPosPpq + incr)
                cursorPosPixel = math.floor((cursorPos - startTime) * zoom_lvl) -- note start pixel
                local sx, sy = reaper.JS_Window_ClientToScreen( track_window, cursorPosPixel, y )
                reaper.JS_Mouse_SetPosition(sx, y)
              end
            end
          end -- for each note
          --reaper.MIDI_Sort(take)
        elseif selectedNotes > 1 then
          for i = 0, CountTrItem-1 do              -- for each item, last to first               
            local item = reaper.GetTrackMediaItem(track,i)      
            local take = reaper.GetTake( item, 0 )       -- get the take
            if take ~= nil then 
              notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
              
              for n = notesCount-1, 0, -1 do       -- for each note, last to first
                _, selected, _, startppqpos, endposppq, _, _, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
                if selected == true then           -- if it's selected
                  reaper.MIDI_SetNote( take, n, nil, nil, startppqpos + incr, endposppq + incr, nil, nil, nil, nil)
                  local newTime = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos + incr)
                  reaper.SetEditCurPos( newTime, 1, 0)
                end
              end -- for each note
            end -- if take not nil
          end -- for each item
        end
        reaper.MIDI_Sort(take)
      end -- if track has items
    end -- if take is not nil
  end -- if not razor edit
  if selectedNotes > 0 then 
    reaper.Undo_OnStateChange2(proj, "nudged note(s)")
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end -- main

main()

