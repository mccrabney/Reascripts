--[[
 * ReaScript Name: open last-hit RS5K instance
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.04
--]]
 
-- HOW TO USE -- 
-- run script after hitting a note assigned in RS5K
-- todo: handle multiple RS5K instances assigned to same note

-- CHANGELOG
--1.04  - moved to obvious MIDI_GetRecentInputEvent from inferior gettrackfxparam hack
--      - no longer a defer script, after all.
--1.03  - fixed typo
--1.02  - fixed nil comparison when extstate isn't created yet
--1.01  - is now a defer script, toggle on and off
--1.00  - IR
---------------------------------------------------------------------
    --[[------------------------------[[--
          look for last-hit note on dedicated track        
    --]]------------------------------]]--
local extName = 'open last-hit RS5K instance'
local _, _, sec, cmd = reaper.get_action_context()
local samplerInstances = {}
reaper.set_action_options(1)

function getLastNoteHit()                       
  local retval, msg, ts, devIdx = reaper.MIDI_GetRecentInputEvent(0)
  if msg:byte(1) then
    local status = msg:byte(1)
    local messageType = status & 0xF0
    local channel = status & 0x0F
    local note, noteOff, velocity, controller, value
    if messageType == 0x90 then  -- Note On
      note = msg:byte(2)
      velocity = msg:byte(3)
    elseif messageType == 0x80 then  -- Note Off
      noteOff = msg:byte(2)
      velocity = msg:byte(3)
    elseif messageType == 0xB0 then  -- Control Change
      controller = msg:byte(2)
      value = msg:byte(3)
    end
    return note
  end
end

function Main()
  lastNote = getLastNoteHit()
  for j = 1, reaper.CountTracks(0) do
    tr = reaper.GetTrack(0, j-1)
    local _, chunk = reaper.GetTrackStateChunk(tr, '', false)
    for line in chunk:gmatch('[^\r\n]+') do
      if line:find('reasamplomatic.dll') then 
        local _, name = reaper.GetTrackName(tr, "") 
        for count = 0, reaper.TrackFX_GetCount(tr)-1 do
          local _, param = reaper.TrackFX_GetParamName(tr, count, 3, "")              
          if param == "Note range start" then
            local nstart = reaper.TrackFX_GetParam(tr, count, 3)
            nstart = math.floor(nstart*128) 
            if nstart == 128 then nstart = nstart-1 end
            if lastNote == nstart then
              reaper.SetOnlyTrackSelected(tr, true)
              reaper.TrackFX_Show(tr, count, 1)
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSTL_SHOWMCPEX"), 0)
            end
          end
        end
      end
    end
  end
end    

function Exit()
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)

reaper.atexit(Exit)

Main()
