--[[
 * ReaScript Name: nudge notes whose note-ons are contained in Razor Edit (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2022-01-08)
   + nudge notes under mouse if no RE is present
 
 * v1.0 (2022-01-01)
   + Initial Release
--]]

 
 for key in pairs(reaper) do _G[key]=reaper[key]  end 
 
 local info = debug.getinfo(1,'S');
 script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]):match('(.*)\\')
 dofile(script_path .. "/mccrabney_Razor Edit Control Functions.lua")    

 ----------------------------  
function getMouseInfo()    
  local item, position_ppq, take, note
  window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local mouse_pos = reaper.BR_GetMouseCursorContext_Position() -- get mouse position
  if details == "item" or inline_editor then         -- hovering over item in arrange
    take = reaper.BR_GetMouseCursorContext_Take() -- get take under mouse
    
    if reaper.TakeIsMIDI(take) then -- is take MIDI?
      item = reaper.BR_GetMouseCursorContext_Item() -- get item under mouse
      position_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, mouse_pos) -- convert to PPQ
      local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      
      for n = notesCount-1, 0, -1 do
        _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note start/end position              
        if startppq <= position_ppq and endppq >= position_ppq then 
          note = pitch
          --reaper.SetMediaItemSelected( mouseItem, true )
        end
      end
    end 
  end     
  return note, take, item, position_ppq
end

-----------------------------
  
function RazorEditSelectionExists()
    local itemUnderMouse
    local itemCount = reaper.CountSelectedMediaItems(0)  -- how many items are selected
  
    if itemCount == 0 then                               -- if none,
      _, _, itemUnderMouse, _ = getMouseInfo()           -- get item under mouse
      if itemUnderMouse ~= nil then 
        itemCount = 1
      end
                                            -- update item count
    end
    
    for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
      local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
      if x ~= "" then return true end            -- if present, return true 
      if x == nil then return false end            -- return that no RE exists
    end
  end                                 -- end RazorEditSelectionExists()
  
  
----------------------------------------------  
  
function main()
  reaper.PreventUIRefresh(1)
  local note, take, selectedItem, position_ppq = getMouseInfo()
  local ppqIncr
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  
  if selectedItem ~= nil then 
      
    -- if there's already an RE, pass on to RE Control Functions script
    if RazorEditSelectionExists() then  
      if mouse_scroll > 0 then 
        task = 6
        job = 1
        SetGlobalParam(job, task, _)
      elseif mouse_scroll < 0 then 
        task = 7
        job = 1
        SetGlobalParam(job, task, _)
      end     -- mouse scroll

    else            -- if no RE, then nudge the note under the mouse
      
      reaper.Undo_BeginBlock()
      if mouse_scroll > 0 then ppqIncr = 50 elseif mouse_scroll < 0 then ppqIncr = -50 end
    
      for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
      --take = reaper.GetTake(selectedItem, t)
        if reaper.TakeIsMIDI(take) then           -- make sure that take is MIDI
          notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
          for n = notesCount-1, 0, -1 do
            _, selected, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, n) -- get note start/end position
            if startppqposOut <= position_ppq and endppqposOut >= position_ppq then -- is current note the note under the cursor?
              reaper.MIDI_SetNote( take, n, selected, muted, startppqposOut+ppqIncr, endppqposOut+ppqIncr, nil, nil, nil, nil) 
            end
          end  -- for each note
        end  -- if midi
      end   -- for t = 0  
      reaper.Undo_EndBlock('nudge notes under mouse cursor', -1)
        
    
    end   -- if RE exists/doesn't exist
  
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
  end  -- if selected item not nil

  
end  -- main function
  
main()
