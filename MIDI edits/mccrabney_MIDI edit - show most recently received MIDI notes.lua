--[[
 * ReaScript Name: show most recently received MIDI notes
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-03-11)
   + Initial Release
--]]

prevNote = -1
loopCount = 0
local pitchList = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local ctx = reaper.ImGui_CreateContext('crabvision')
local sans_serif = reaper.ImGui_CreateFont('sans_serif', 15)
reaper.ImGui_Attach(ctx, sans_serif)


---------------------------------------------------------------------
    --[[------------------------------[[--
          watch for last-hit note on dedicated track -- mccrabney        
    --]]------------------------------]]--

function getLastNoteHit()                       -- open the function
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the track present
  local lastNote = -1                           -- initialize lastNote
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = isTrack+1                       -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then
        lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
      else 
        lastNote = -1
      end
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
  
    reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\nRetrigger the reference MIDI and rerun the script.", "No MIDI reference", 0)  
  
  end
  return lastNote         -- lastNoteHit is a referenced variable for edits
end                                             -- end function

    
--------------------------------------------------------------------

local function loop()
  
  reaper.ImGui_GetFrameCount(ctx) -- a fast & inoffensive function
   
  loopCount = loopCount+1
  
  local note = getLastNoteHit()
  
  if note ~= prevNote then 
    loopCount = 0 
    prevNote = note
  end
  
  if note ~= -1 then
    local x, y = reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition())
    reaper.ImGui_SetNextWindowPos(ctx, x - 11, y - 75)
    reaper.ImGui_PushFont(ctx, sans_serif)  
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x0F0F0FD8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 12)
  
    if reaper.ImGui_Begin(ctx, 'Tooltip', false,
    reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoDecoration() |
    reaper.ImGui_WindowFlags_TopMost() |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    
      if note ~= nil then
        local octave = math.floor(note/12)-1
        local cursorNoteSymbol = (note - 12*(octave+1)+1) 
             
        reaper.ImGui_TextColored(ctx, 0xffffff, pitchList[cursorNoteSymbol] .. octave .. " (" .. note .. ")")
      end
      
      reaper.ImGui_End(ctx)
    
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopFont(ctx)
      reaper.ImGui_PopStyleVar(ctx)
  
    end
      
  end
  reaper.defer(loop)
end


--------------------------------------------
reaper.defer(loop)
