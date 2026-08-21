--[[
 * ReaScript Name: move target notes to mouse cursor (maintaining relative position)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
 * Changelog:
 * v1.00 (2024-11-4)
 
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

function getMouseInfo()
  local item, mouseposppq, take, note
  window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
  
  if details == "item" or inline_editor then         -- hovering over item in arrange
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
  
    if reaper.TakeIsMIDI(take) then -- is take MIDI?
      item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
      mouseposppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos)) -- convert to PPQ
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
    end 
  end     
  
  return take, item, mouseposppq, notesCount
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          move target notes to mouse cursor (maintaining relative position)
    --]]------------------------------]]--

function main()
  reaper.ClearConsole()
  reaper.PreventUIRefresh(1)
  
  if RazorEditSelectionExists() then
  else
    local take, selectedItem, mouseposppq, notesCount = getMouseInfo()
    --local pitchList = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
    local firstStart
    local selCount = 0
    if mouseposppq and take ~= nil then
      reaper.MIDI_DisableSort(take)
      for i = 0, notesCount do
        _, sel, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote(take, i)
        if sel == true then 
          selCount = selCount+1
          if selCount == 1 then
            offset = mouseposppq - startppqpos
          end
          reaper.MIDI_SetNote(take, i, nil, nil, startppqpos + offset, endppqpos + offset, nil, nil, nil, nil)  -- set startpos to mousecursor
        end
      end

      reaper.MIDI_Sort(take)
      --reaper.SetExtState(extName, 'DoRefresh', '1', false)
      reaper.Undo_OnStateChange2(proj, "moved note(s)")
    end
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
 
main()

  

  
  
