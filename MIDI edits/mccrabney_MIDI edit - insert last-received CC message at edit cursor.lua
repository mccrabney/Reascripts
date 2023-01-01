--[[
 * ReaScript Name: Insert last-received CC in selected item under edit cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 (2023-1-1)
   + fixed add js by filename issue
 
 * v1.1 (2022-12-29)
   + Initial Release
--]]

--[[
  NOTE: This is a "main screen script" - if using it from the MIDI editor, pass through the 
  keyboard shortcut to the main screen so that the script gets run.
--]]


function getLastCC()                            -- observe/create reference track
  --reaper.PreventUIRefresh(1)
  
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  local lastCC = -1                             -- initialize lastCC
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = isTrack+1                       -- flag that the ref track is present
      isCC  = reaper.TrackFX_GetParam(findTrack, 0, 1)  -- is it a cc
      lastCC = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last received cc
      lastCCvalue = reaper.TrackFX_GetParam(findTrack, 0, 3)  -- find last received cc value
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  if isTrack == 0 then                          -- if reference track isn't present, 
     
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    refTrack = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastmidi", true)
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    reaper.TrackFX_AddByName( refTrack, "midi_examine", false, 1 )  -- add js
    reaper.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    reaper.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- set as folder
    reaper.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    controller = reaper.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
                                        -- turn rec mon on, set to all MIDI inputs
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) ) 
    
   --[[ reaper.ShowConsoleMsg("This script uses last-received MIDI as a reference for edits. \n")     -- communicate
    reaper.ShowConsoleMsg("A 'lastmidi' folder has been created for this purpose. \n")
    reaper.ShowConsoleMsg("It contains a track armed to 'All MIDI inputs'. \n")
    reaper.ShowConsoleMsg("This folder can be hidden and/or ignored from now on. \n")
    reaper.ShowConsoleMsg("Close this window, trigger your reference, and re-run the edit. \n")--]]
    
    reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\nRetrigger the reference MIDI and rerun the script.", "No MIDI reference", 0)
    end
  return lastCC, lastCCvalue, isCC         -- lastCC is a referenced variable for edits
  --reaper.PreventUIRefresh(-1)
end                                             -- end function

function insertLastCC(curPos)
  
  reaper.Undo_BeginBlock()
  lastCC, lastCCvalue, isCC = getLastCC()
  --reaper.ShowConsoleMsg(isCC)
  if isCC ~= nil and isCC >= 176 and isCC <= 191 then             -- if the last received message was a CC
    local channel = isCC - 176                      -- get channel
    --editCursorPos = reaper.GetCursorPosition()     -- get edit cursor position
    selectedItem = reaper.GetSelectedMediaItem(0, 0)
    if selectedItem ~= nil then
      for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
        take = reaper.GetTake(selectedItem, t)
        if reaper.TakeIsMIDI(take) then -- make sure, that take is MIDI
          editCursor_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, curPos) -- convert project time to PPQ
          ccCount, _, _ = reaper.MIDI_CountEvts(take) -- count cc in current take  
          for n = ccCount-1, 0, -1 do         --- for each cc, starting with last in item
            _, _, _, ppqpos, _, _, currentCC, _ = reaper.MIDI_GetCC( take, n )                
            if ppqpos == editCursor_ppq_pos then reaper.MIDI_DeleteCC( take, n ) end
          end
          reaper.MIDI_InsertCC( take, 0, 0, editCursor_ppq_pos, 191, channel, lastCC, lastCCvalue)    
        end
      end
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock('Insert last-received CC at edit cursor', -1)
  end
  
end

function main()
  
  local window, _, details = reaper.BR_GetMouseCursorContext() -- initialize cursor context
  local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI() -- check if mouse hovers an inline editor

  local cursor_position = reaper.GetCursorPosition()  -- get edit cursor position 

  if window == "midi_editor" and not inline_editor then -- MIDI editor focused and not hovering inline editor
    local midi_editor = reaper.MIDIEditor_GetActive()   -- get active MIDI editor
    local take = reaper.MIDIEditor_GetTake(midi_editor) -- get take from active MIDI editor
    local item = reaper.GetMediaItemTake_Item(take)   -- get item from take
    insertLastCC(cursor_position) 
  
  else                   -- if user is in the inline editor or anywhere else
    if reaper.CountSelectedMediaItems(0) == 0 then
      --reaper.ShowMessageBox("Please select at least one item", "Error", 0)
      return false
  
    else                                        -- if an item is selected 
      for i = 0, reaper.CountSelectedMediaItems(0)-1 do -- loop through all selected items
        local item = reaper.GetSelectedMediaItem(0, i)  -- get current selected item
        local take = reaper.GetActiveTake(item)
        if reaper.TakeIsMIDI(take) then
          insertLastCC(cursor_position)
        else
          --reaper.ShowMessageBox("Selected item #".. i+1 .. " does not contain a MIDI take and won't be altered", "Error", 0)     
        end     
      end
    end
  end
end

main()
