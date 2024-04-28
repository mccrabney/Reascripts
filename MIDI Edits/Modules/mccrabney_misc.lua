--[[
 * @noindex
--]]
---------------------------------------------------------------------


local incr = {1, 10, 24, 48, 96, 240, 480, 960}
incrIndex = 2                   -- vars/setup for loop
dbg = 0        -- print debug messages or not

function debug(statement, newLine)
  if dbg == 1 then
    reaper.ShowConsoleMsg(statement)
    if newLine == 1 then reaper.ShowConsoleMsg("\n") end
  end
end

function extStates()
  if reaper.HasExtState(extName, 'DoRefresh') then              -- update display, called from child scripts
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo()
    lastX = -1                                                -- n/a x val fools the optimizer into resetting
    reset = 1                                                   -- allow reset after nudge for cursor targeted notes
    debug("doRefresh", 1)
    lastAllAreas = -1  
    --debug(reset, 1)
    reaper.DeleteExtState(extName, 'DoRefresh', false)
  end  
 
  if reaper.HasExtState(extName, 'Refresh') then              -- update display, called from child scripts
    lastPixelLength = -1
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo()
    lastAllAreas = -1     
    debug("step: " .. step, 1)
    debug("Refresh", 1)
    reaper.DeleteExtState(extName, 'Refresh', false)
    
  end        

  if not reaper.HasExtState(extName, 7) then                        -- set increment of nudge,
    reaper.SetExtState(extName, 7, incr[incrIndex], true)       -- set incr extstatem, save between sessions
  end   
  
  if reaper.HasExtState(extName, 'debug') then                        -- set increment of nudge,
    if dbg == 1 then 
      dbg = 0 
    else 
      dbg = 1 
      reaper.ClearConsole()
      debug("debug on", 1)
    end
    reaper.DeleteExtState(extName, 'debug', false)
  end   
 
  if reaper.HasExtState(extName, 6) then                        -- set increment of nudge,
    q = tostring(reaper.GetExtState( extName, 6 ))              -- based on input from child script
    if incrIndex + q > 0 and incrIndex + q < 9 then             -- set bounds for incrIndex
      incrIndex = incrIndex + q
    end
    reaper.SetExtState(extName, 7, incr[incrIndex], true)       -- set incr extstatem, save between sessions
    reaper.DeleteExtState(extName, 6, false)                    -- delete increment setting extstate
  end   
    
  if reaper.HasExtState(extName, 'toggleCursor') then           -- toggle whether focus is edit or mouse cursor                       
    if cursorSource ~= 1 then 
      cursorSource = 1                                          
    elseif cursorSource == 1 then 
      cursorSource = 0 
    end 
    
    debug("cursorSource is " .. cursorSource, 1)
    reaper.SetExtState(extName, 8, cursorSource, true)          -- extstate management
    reaper.DeleteExtState(extName, 'toggleCursor', false)
    reaper.SetExtState(extName, 'Refresh', '1', false)
  end 
  
  if reaper.HasExtState(extName, 'setCursorEdit') then          -- set cursor to edit
    if cursorSource ~= 0 then                                   
      cursorSource = 0                                         
      reaper.SetExtState(extName, 8, cursorSource, true)        -- extstate management
    end
    reaper.DeleteExtState(extName, 'setCursorEdit', false)
  end
  
  if loopCount > resetCursor and cursorSource == 0 then                               -- if idle, reset cursor
  while loopCount > resetCursor do
    if loopCount > resetCursor+1 then break end               -- just do it once
    cursorSource = 1                                          -- set cursor to mouse
    reaper.SetExtState(extName, 8, cursorSource, true)        -- set extstate to reflect the change
    debug("small idle, resetCursor" .. "\n")
    reaper.SetExtState(extName, 'Refresh', '1', false)
    break end
  end
  
  if loopCount > resetCursor and cursorSource == 1 then                               -- if idle, reset cursor
  while loopCount > resetCursor do
    if loopCount > resetCursor+1 then break end               -- just do it once
    reaper.SetExtState(extName, 8, cursorSource, true)        -- set extstate to reflect the change
    debug("small idle, resetCursor" .. "\n")
    reaper.SetExtState(extName, 'Refresh', '1', false)
    break end
  end
  
  ------------------------------------------------------------- are we holding a note?                                        
  if reaper.HasExtState(extName, 'noteHoldUpdate') then         
    --if multiple == 1 then
      noteHoldNumber = tostring(math.floor(reaper.GetExtState(extName, 'noteHold')))
      lastNoteHoldNumber = noteHoldNumber
      text = tostring("lastHold: " .. lastNoteHoldNumber .. " noteHold " .. noteHoldNumber)
      debug(text, 1)
      reaper.DeleteExtState(extName, 'noteHoldUpdate', false)
      --reaper.SetExtState(extName, 'Refresh', '1', false)
  end       
  
  if reaper.HasExtState(extName, 'toggleNoteHold') then         -- if extstate says we are holding a note,
    --if toggleNoteHold == 0 and RazorEditSelectionExists() then  -- if RE exists but notehold is 0
    --lastX = -1
    reaper.SetExtState(extName, 'DoRefresh', '1', false)
    --lastAllAreas = -1  
    if toggleNoteHold == 0 and RazorEditSelectionExists() and track ~= nil  
    or toggleNoteHold == 1 and lastTargetPitch ~= targetPitch and track ~= nil then -- if RE exists but notehold is 0
      toggleNoteHold = 1                                        -- set notehold to 1
      mTrack = track
      _, mTrackName = reaper.GetTrackName(mTrack)
      if targetPitch then 
        noteHoldNumber = targetPitch 
        lastTargetPitch = targetPitch
      end      -- set the held note to the targetpitch 
      reaper.SetExtState(extName, "noteHold", noteHoldNumber, false)   -- write the note hold number to exstate
    
    elseif toggleNoteHold == 1 then                             -- toggle note hold value if 1
      toggleNoteHold = 0
      noteHoldNumber = -1
      reaper.SetExtState(extName, "noteHold", -1, false)        -- write the note hold number
    end
    reaper.DeleteExtState(extName, 'toggleNoteHold', false)     -- cleanup extstate
  end    

  if RazorEditSelectionExists() and noteHoldNumber ~= -1 then   -- ifn't RE and if noteholdnumber == -1   
  else
    toggleNoteHold = 0                                          
    reaper.SetExtState(extName, "noteHold", -1, false)          -- write the note hold number
  end
  
  --if targetPitch == nil then targetPitch = -1 end
  
end
    
function getLastNoteHit()  -- what is the last note that has been struck on our controllers?
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the reference track present, initialized to no
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )  -- get trackname
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastVel = reaper.TrackFX_GetParam(findTrack, 0, 3)   -- find last hit velocity
        lastNote = math.floor(lastNote)                      -- round it off        
        lastVel = math.floor(lastVel)                        -- round it off
        if toggleNoteHold == 1 then             -- if notehold is true, 
          noteHoldNumber = lastNote             -- set it to the last note received
        else 
          noteHoldNumber = -1                   -- set notehold to inapplicable value
        end 
        reaper.SetExtState(extName, 'noteHold', noteHoldNumber, false)   -- write the note hold number to extstate
      else                                      -- if noteoff, display no-note value
        lastNote = -1                           -- no note value, so set to inapplicable
      end                                       -- if vel not 0
    end                                         -- end if/else desired trackname
  end                                           -- end for every track
  
  if isTrack == 0 then                          -- if reference track isn't present, 
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert one at end of project
    refTrack = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(refTrack, "P_NAME", "lastmidi", true)
        -- using data byte 1 of midi notes received by JS MIDI Examiner - thanks, schwa!
    reaper.TrackFX_AddByName( refTrack, "midi_examine", false, 1 )  -- add js
    reaper.SetMediaTrackInfo_Value( refTrack, "D_VOL", 0 )      -- volume off
    reaper.SetMediaTrackInfo_Value( refTrack, 'I_FOLDERDEPTH', 1 )   -- set folder
    reaper.InsertTrackAtIndex( numTracks+1, false ) -- insert another track
    controller = reaper.GetTrack( 0, numTracks+1)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(controller, "P_NAME", "controller", true)
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECARM', 1 )   -- arm it
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMODE', 2 )  -- turn recording off
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECMON', 1 )  -- turn rec mon on
                                        -- turn rec mon on, set to all MIDI inputs
    reaper.SetMediaTrackInfo_Value( controller, 'I_RECINPUT', 4096 | 0 | (63 << 5) ) 
    --reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\n", "No MIDI reference", 0)  
  end
  
  return lastNote, lastVel         
end

function idleSensor()
  if idleTask == 1 then
    while idleCount > 100 do
      if idleCount > 101 then break end                 -- just do it once
      debug("idle", 1)
      for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0,i-1)
        item_num = reaper.CountTrackMediaItems(tr)
        for j = 0, item_num-1 do -- LOOP THROUGH MEDIA ITEMS
          itm = reaper.GetTrackMediaItem(tr, j)
          for t = 0, reaper.CountTakes(itm)-1 do       -- for each take,
            tk = reaper.GetTake(itm, t)              -- get take
            if tk ~= nil and reaper.TakeIsMIDI(tk) then             -- if it's MIDI, get RE PPQ values
              _, ccCount, _ = reaper.MIDI_CountEvts(tk) -- count notes in current take 
              for n = 0, ccCount do
                _, _, _, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC( tk, n )
                if chan == 15 and msg2 == 119 and msg3 == 1 then 
                  reaper.MIDI_DeleteCC( tk, n )
                  undo = 1
                  debug("dummies deleted", 1)
                end
              end
            end
          end
        end
      end
    if undo == 1 then reaper.Undo_OnStateChange2(proj, "idle cleanup" ) end    
      break
    end
  end 
end

-----------------------------------------------------------
    --[[------------------------------[[--
          get the track name of the target note if RS5K
    --]]------------------------------]]--

function getInstanceTrackName(note)
  if note then                                 -- if there's a note under the cursor
    for j = 1, reaper.CountTracks(0) do              -- for each track
      tr = reaper.GetTrack(0, j - 1)                 -- get track
      fxCount = reaper.TrackFX_GetCount(tr)          -- count fx on each instance track
      for p = 0, fxCount-1 do                        -- for each fx
        retval, buf = reaper.TrackFX_GetNamedConfigParm( tr, p, "fx_name" )    -- get fx name
        if buf:match("ReaSamplOmatic5000")  then     -- if RS5K
          local _, param = reaper.TrackFX_GetParamName(tr, p, 3)               -- get param name        
          if param == "Note range start" then        -- if it's the right one, and if it's rs5k,
            noteStart = reaper.TrackFX_GetParam(tr, p, 3)        -- set/fix math for noteStart value
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
