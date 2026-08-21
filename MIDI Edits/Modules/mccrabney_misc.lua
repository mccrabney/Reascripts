--[[
 * @noindex
--]]
---------------------------------------------------------------------

local incr = {1, 10, 24, 48, 96, 240, 480, 960}  -- table of incr values
local incrIndex = 2  -- vars/setup for loop
dbg = 0        -- print debug messages or not
input = 0            -- input notes or not
--local proj = "!"
local noteHoldNumber =-1
local inputNote =-1
local inputState = 0

    
---------------------------------------------------------------------------
function debug(statement, newLine)
  if dbg == 1 then reaper.ShowConsoleMsg(statement)
    if newLine == 1 then reaper.ShowConsoleMsg("\n") end
  end
end

---------------------------------------------------------------------------
local ceil, floor = math.ceil, math.floor
function Round(n)
   return n % 1 >= 0.5 and ceil(n) or floor(n)
end

--------------- check for razor edit ------------------------------]]--
function RazorEditSelectionExists()
  for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end              -- if present, return true 
    if x == nil then return false end            -- return that no RE exists
  end
end            

  ---------------------------------------------------------------------------
function extStates()
  if reaper.HasExtState(extName, 'DoRefresh') then            -- update display, called from child scripts
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo()
    lastX = -1                                                -- n/a x val fools the optimizer into resetting
    reset = 1                                                 -- allow reset after nudge for cursor targeted notes
    --debug("doRefresh", 1)
    reaper.DeleteExtState(extName, 'DoRefresh', false)
  end  

   --[[-------------------------------------------------------------------------
  if reaper.HasExtState(extName, 'Refresh') then              -- update display, called from child scripts
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo()
    debug("step: " .. step, 1)
    debug("Refresh", 1)
    reaper.DeleteExtState(extName, 'Refresh', false)
  end        
  --]]
  
  ---------------------------------------------------------------------------
  if reaper.HasExtState(extName, 'debug') then                -- debug 
    if dbg == 1 then 
      dbg = 0 
      --reaper.ShowConsoleMsg("debug off" .. "\n")
    else 
      dbg = 1
      --reaper.ClearConsole()
      --debug("debug on", 1)
    end
    reaper.DeleteExtState(extName, 'debug', false)
  end   
 
  ---------------------------------------------------------------------------
  if reaper.HasExtState(extName, 'input') then                -- set input on/off
    if input == 1 then 
      input = 0 
    else 
      input = 1
      debug("input on", 1)
    end
    reaper.DeleteExtState(extName, 'input', false)
  end   
  
  --------------------------------------------------------------------------- 
  if not reaper.HasExtState(extName, 7) then                  -- set increment of nudge,
    reaper.SetExtState(extName, 7, incr[incrIndex], true)     -- set incr extstate, save between sessions
  end   
  
  ---------------------------------------------------------------------------
  if reaper.HasExtState(extName, 6) then                        -- set increment of nudge,
    local q = tostring(reaper.GetExtState( extName, 6 ))        -- based on input from child script
    if incrIndex + q > 0 and incrIndex + q < 9 then             -- set bounds for incrIndex
      incrIndex = incrIndex + q
    end
    reaper.SetExtState(extName, 7, incr[incrIndex], true)       -- set incr extstatem, save between sessions
    reaper.DeleteExtState(extName, 6, false)                    -- delete increment setting extstate
  end   
  
  -------------------------------- delete selected notes --------
  if reaper.HasExtState(extName, 'Delete') then         
    if track ~= nil then                            -- if there is a track
      if mouseTake then reaper.MIDI_DeleteNote(mouseTake, targetNoteIndex) end 
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item,               
          local item = reaper.GetTrackMediaItem(track,i)      
          local take = reaper.GetTake( item, 0 )       -- get the take
          if take ~= nil then 
            local notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
            for n = notesCount-1, 0, -1 do                        -- for each note, from back to front
              local _, selected, muteState, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then  -- if the note is selected
                reaper.MIDI_DeleteNote(take, n)
              end -- if selected
            end -- for each note
          end -- if take
        end -- for each item
      end -- if track has items
    end -- if track not nil
    reaper.UpdateArrange()
    reaper.Undo_OnStateChange2(proj, "deleted note(s)")
    reaper.SetExtState(extName, 'DoRefresh', 1, false)
    reaper.DeleteExtState(extName, 'Delete', false) 
  end -- if extstate "Delete"

    ------------------------------------------------------------ mute selected notes --------
  if reaper.HasExtState(extName, 'Mute') then         
    if track ~= nil then                            -- if there is a track
      local CountTrItem = reaper.CountTrackMediaItems(track)
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item,               
          local item = reaper.GetTrackMediaItem(track,i)      
          local take = reaper.GetTake( item, 0 )       -- get the take
          if take ~= nil then 
            local notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
            for n = notesCount-1, 0, -1 do                        -- for each note, from back to front
              local _, selected, muteState, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
              if selected == true then  -- if the note is selected
                if muteState == false then muteState = true else muteState = false end
                reaper.MIDI_SetNote(take, n, _, muteState)
              end -- if selected
            end -- for each note
          end -- if take
        end -- for each item
      end -- if track has items
    end -- if track not nil
    reaper.UpdateArrange()
    reaper.Undo_OnStateChange2(proj, "muted note(s)")
    reaper.SetExtState(extName, 'DoRefresh', 1, false)
    reaper.DeleteExtState(extName, 'Mute', false)    
  end -- if extstate "Delete"
  
  --------------------------------------------------------------- toggle note hold 
  if reaper.HasExtState(extName, 'noteHold') or reaper.HasExtState(extName, 'inputNote') then    
    debug("noteHold", 1)
    if track then                                   -- if there's a track
      reaper.SetOnlyTrackSelected(track)            -- set only that track selected
      local CountTrItem = reaper.CountTrackMediaItems(track)  -- count items
       if CountTrItem then                          -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item,               
          local item = reaper.GetTrackMediaItem(track,i)  -- get the item    
          local take = reaper.GetActiveTake(item, 0)      -- get the take
          if take and reaper.TakeIsMIDI(take) then  -- if take
            reaper.MIDI_SelectAll( take, 0 )        -- deselect all notes
          end -- if take
        end -- for each item
      end -- if track has items
                                                    -- if noteHold is called w/out target,

      if reaper.HasExtState(extName, 'inputNote') then   -- if we're using last-touched note instead
        noteHoldNumber = inputNote
      end
      
      if targetPitch == nil and reaper.HasExtState(extName, 'noteHold') then
        noteHoldNumber = -1
      end
      
      if targetPitch and targetPitch ~= -1 and reaper.HasExtState(extName, 'noteHold') then         -- if a valid mouseover note
        noteHoldNumber = targetPitch                    -- set noteHoldNumber to targetPitch
      end -- if valid mouseover note
      
      reaper.SetExtState(extName, 'noteHoldNumber', noteHoldNumber, false)  
      
      if RazorEditSelectionExists() then      -- select target notes
        job = 1
        task = 5
        SetGlobalParam(job, task, _)          -- select target notes in RE
      end -- if RE exists

      if not RazorEditSelectionExists() and mouseTake and reaper.TakeIsMIDI(mouseTake) then 
        local notesCount, _, _ = reaper.MIDI_CountEvts(mouseTake)  -- count notes in current take                    
        for n = notesCount-1, 0, -1 do                        -- for each note, from back to front
          local item = reaper.GetMediaItemTake_Item(mouseTake)
          local itemPos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
          local itemLength = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
          local _, _, _, startppqpos, endppqpos, _, pitch, _ = reaper.MIDI_GetNote(mouseTake, n)  -- get note data           
          local notePos = reaper.MIDI_GetProjTimeFromPPQPos(mouseTake, startppqpos)
          if pitch == noteHoldNumber and notePos >= itemPos and notePos < itemPos+itemLength then              
            reaper.MIDI_SetNote(mouseTake, n, true)  -- set note selected
          end -- if targetpitch
        end -- for each note
        if noteHoldNumber == -1 then 
          reaper.Undo_OnStateChange2(proj, "cleared selected notes")
        end
        reaper.Undo_OnStateChange2(proj, "select " .. noteHoldNumber)
      end -- if mousetake
    end -- if notehold
    reaper.SetExtState(extName, 'DoRefresh', '1', false)
    reaper.DeleteExtState(extName, 'inputNote', false)     -- cleanup extstate
    reaper.DeleteExtState(extName, 'noteHold', false)     -- cleanup extstate
  end -- if track
end  -- extstates

  ------------------------------------------------------ get last note hit 
function getLastNoteHit()  -- what is the last note that has been struck on our controllers?
  local retval, msg, ts, devIdx = reaper.MIDI_GetRecentInputEvent(0)
  if msg:byte(1) then
    local status = msg:byte(1)
    local messageType = status & 0xF0
    local channel = status & 0x0F
    local note, noteOff, velocity, controller, value
    if messageType == 0x90 then  -- Note On
      lastNote = msg:byte(2)
      lastVel = msg:byte(3)
    elseif messageType == 0x80 then  -- Note Off
      lastNote = -1
    elseif messageType == 0xB0 then  -- Control Change
      --controller = msg:byte(2)
      --value = msg:byte(3)
    end
    return lastNote, lastVel
  end
  
  if lastNote ~= nil and lastNote ~= -1 then 
    inputNote = lastNote
  end
  return lastNote, lastVel, inputNote
  
  --[[
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the reference track present, initialized to no
  local trackName
  local lastNote = 0
  local lastChan, lastVel
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )  -- get trackname
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = math.floor(reaper.TrackFX_GetParam(findTrack, 0, 2))  -- find last hit note
        lastVel  = math.floor(reaper.TrackFX_GetParam(findTrack, 0, 3))  -- find last hit velocity
        lastChan = math.floor(reaper.TrackFX_GetParam(findTrack, 0, 5)) + 1  -- find last hit velocity
      else                                      -- if noteoff, display no-note value
        lastNote = -1                           -- no note value, so set to inapplicable
      end                                       -- if vel not 0
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  --if lastVel == nil then lastVel = -1 end
  --reaper.ShowConsoleMsg(lastVel .. "\n")
  
  if isTrack == 0 then                          -- if reference track isn't present, 
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    local refTrack = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastmidi", true)
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    reaper.TrackFX_AddByName( refTrack, "midi_examine", false, 1 )  -- add js
    reaper.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    reaper.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- set folder
    reaper.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    local controller = reaper.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
                                        -- turn rec mon on, set to all MIDI inputs
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) ) 
  end 
  
  if lastNote ~= nil and lastNote ~= -1 then 
    inputNote = lastNote
  end
  --return lastNote, lastVel, inputNote

--]]

end


--]]

-----------------------------------------------------------
    --[[------------------------------[[--
          get the track name of the target note if RS5K
    --]]------------------------------]]--

function getInstanceTrackName(note)
  if note then                                 -- if there's a note under the cursor
    for j = 1, reaper.CountTracks(0) do              -- for each track
      local tr = reaper.GetTrack(0, j - 1)                 -- get track
      local fxCount = reaper.TrackFX_GetCount(tr)          -- count fx on each instance track
      for p = 0, fxCount-1 do                        -- for each fx
        local retval, buf = reaper.TrackFX_GetNamedConfigParm( tr, p, "fx_name" )    -- get fx name
        if buf:match("ReaSamplOmatic5000")  then     -- if RS5K
          local _, param = reaper.TrackFX_GetParamName(tr, p, 3)               -- get param name        
          if param == "Note range start" then        -- if it's the right one, and if it's rs5k,
            local noteStart = reaper.TrackFX_GetParam(tr, p, 3)        -- set/fix math for noteStart value
            noteStart = math.floor(noteStart*128) if noteStart == 128 then noteStart = noteStart - 1 end
            if note == noteStart then          -- if it's the same as our note under cursor,
              _, trName = reaper.GetTrackName( tr )  -- get track name
            end
          end
        end                                          -- if RS5K
      end                                            -- for each fx
    end                                              -- for each track
  end
  return trName
end
