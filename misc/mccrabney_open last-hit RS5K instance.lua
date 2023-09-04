--[[
 * ReaScript Name: open last-hit RS5K instance
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.02
--]]
 
-- HOW TO USE -- 
-- run script after hitting a note assigned in RS5K
-- todo: handle multiple RS5K instances assigned to same note

-- CHANGELOG
--  - fixed nil comparison when extstate isn't created yet
--  - is now a defer script, toggle on and off

---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track        
    --]]------------------------------]]--
local extName = 'open last-hit RS5K instance'
local _, _, sec, cmd = reaper.get_action_context()
local samplerInstances = {}

function getLastNoteHit()                       
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
      lastNote = math.floor(lastNote)
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
    reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\n", "No MIDI reference", 0)  
  end
  return lastNote

end

prevNote = -1

function Main()
  local lastNote = getLastNoteHit()
  local samplerCount = 0
  
  if reaper.HasExtState(extName, 'prevNote') then
    prevNote = tonumber(reaper.GetExtState( extName, 'prevNote' ))
  else 
    prevNote = -1
  end
 
  if lastNote ~= prevNote then
      reaper.ClearConsole()
  
    for j = 1, reaper.CountTracks(0) do
      tr = reaper.GetTrack(0,j-1)
      local _, chunk = reaper.GetTrackStateChunk( tr, '', false )
      
      for line in chunk:gmatch('[^\r\n]+') do
        if line:find('reasamplomatic.dll') then 
          local _, name = reaper.GetTrackName(tr, "") 
                       
          for count = 0, reaper.TrackFX_GetCount(tr)-1 do
            local _, param = reaper.TrackFX_GetParamName(tr, count, 3, "")              
            
            if param == "Note range start" then
              nstart = reaper.TrackFX_GetParam(tr, count, 3)
              nstart = math.floor(nstart*128) if nstart == 128 then nstart = nstart-1 end
              
              if lastNote == nstart then
                --reaper.ShowConsoleMsg("nstart - " .. nstart .. "\n") 
              
                samplerCount = samplerCount+1
                --reaper.ShowConsoleMsg(samplerCount .. "\n")
              
                reaper.SetOnlyTrackSelected( tr, true )
                reaper.TrackFX_Show(tr, count, 1)
                reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSTL_SHOWMCPEX"), 0)

              end
            end
          end  
        end
      end
    end
  end
  
  if prevNote ~= nil then 
    reaper.SetExtState(extName, 'prevNote', lastNote, false)         -- write the note hold number
  end
  
  reaper.defer(Main)
end    

function Exit()
    reaper.SetToggleCommandState(sec, cmd, 0)
    reaper.RefreshToolbar2(sec, cmd)
end

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)

reaper.atexit(Exit)

Main()
