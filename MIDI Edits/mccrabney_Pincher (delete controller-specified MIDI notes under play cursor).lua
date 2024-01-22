--[[
 * ReaScript Name: Pincher (delete controller-specific MIDI notes under play cursor)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
   
  how to use: 
    run this script, select a track with MIDI content, and then hit play.
    using your MIDI controller, hold the note you want deleted.
    instances of this note will be deleted from your MIDI item as the play cursor draws near.
    increase "slop" value if you're missing notes
    
  potetial improvements: 
    improve note collector to receive/delete multiple distinct notes at the same time
    
--]] 

slop = 200    -- how many ticks ahead of play cursor to delete notes

--loopCount = 0

--[[-----------------------------------------------------------------
    --[[------------------------------[[--
          get last note hit
    --]]------------------------------]]--
function getLastNoteHit()  -- what is the last note that has been struck on our controllers?
  local numTracks = reaper.CountTracks(0)       -- how many tracks
  local isTrack = 0                             -- is the reference track present, initialized to no
  
  for i = 1, numTracks do                       -- for every track 
    local findTrack = reaper.GetTrack(0,i-1)    -- get each track
    _, trackName = reaper.GetSetMediaTrackInfo_String( findTrack, 'P_NAME', '', 0 )
    if trackName:lower():find("lastmidi") then  -- if desired trackname
      isTrack = 1                               -- flag that the ref track is present
      if reaper.TrackFX_GetParam(findTrack, 0, 3) ~= 0 then  -- if vel not 0 (noteoff)
        lastNote = reaper.TrackFX_GetParam(findTrack, 0, 2)  -- find last hit note
        lastVel = reaper.TrackFX_GetParam(findTrack, 0, 3)   -- find last hit velocity
        lastNote = math.floor(lastNote)                      -- round it off        
        lastVel = math.floor(lastVel)                        -- round it off
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
    reaper.ShowMessageBox("A folder has been created to watch your MIDI controllers.\n", "No MIDI reference", 0)  
  end
  return lastNote, lastVel         
end


--[[-----------------------------------------------------------------
  --[[------------------------------[[--
          loop and show tooltips, cursor as necessary  
  --]]------------------------------]]--

local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
function loop()
  --playCurPos =  reaper.GetPlayPosition()               -- "returns latency-compensated actual-what-you-hear position"
  --playCurPos =  reaper.GetPlayPositionEx( proj )       -- "returns latency-compensated actual-what-you-hear position"
  playCurPos =  reaper.GetPlayPosition2()              -- "returns position of next audio block being processed"
  --playCurPos =  reaper.GetPlayPosition2Ex( proj )      -- "returns position of next audio block being processed
  
  if playCurPos ~= prevPlayCurPos and playCurPos ~= -1 then   -- if we are playing
    --loopCount = loopCount+1                                 -- advance loopcount
    prevPlayCurPos = playCurPos                             
    lastNote, lastVel = getLastNoteHit()                    -- if idle, stop getting lastnotehit                                                        
    selTracks = reaper.CountSelectedTracks( 0 )             
    
    if selTracks == 1 then                                  -- if there's a selected track
      track = reaper.GetSelectedTrack( 0, 0 )
      items = reaper.CountTrackMediaItems( track )
      
      if items ~= nil then                                  -- if there are items
        for i = 1, items, 1 do                              -- for each item
          item = reaper.GetTrackMediaItem( track, i-1 )     -- get item start/endpos                    
          local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local itemEnd = itemStart+ reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
          
          for t = 0, reaper.CountTakes(item)-1 do           -- for each take,
            take = reaper.GetTake(item, t)                  -- get take
            if reaper.TakeIsMIDI(take) then                 -- if it's MIDI
              playCurPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, playCurPos)  -- get playcursor ppq 
              notesCount, _, _ = reaper.MIDI_CountEvts(take)    -- count notes in current take                    
              
              if playCurPos >= itemStart and playCurPos < itemEnd then         -- if playcursor is in item
                --for n = notesCount-1, 0, -1 do              -- for each note, starting with last in item
                for n = 0, notesCount, 1 do                 -- for each note, starting with first in item
                  _, _, _, startppqposOut, endppqposOut, chan, pitch, _ = reaper.MIDI_GetNote(take, n) -- get note info
                  if pitch == lastNote then   
                    --if startppqposOut <= playCurPPQ and endppqposOut > playCurPPQ-slop then   -- if note is under playcursor
                    if playCurPPQ >= startppqposOut-slop and playCurPPQ < endppqposOut then   -- if note is under playcursor
                      reaper.MIDI_DeleteNote( take, n )
                      octave = math.floor(lastNote/12)-1                               -- establish the octave for readout
                      cursorNoteSymbol = pitchList[(lastNote - 12*(octave+1)+1)]       -- establish the note symbol for readout
                      reaper.Undo_OnStateChange2(proj, "live-deleted note " .. lastNote .. ", (" .. cursorNoteSymbol .. octave .. ")")
                    end                                     -- if note is under playcursor         
                  end                                       -- if pitch is lastNote
                end                                         -- for each note
              end                                           -- if playcursor is in item
            end                                             -- if take is midi
          end                                               -- for each take
        end                                                 -- for each item
      end                                                   -- if item exists
    end                                                     -- if there's a selected track
  else                                                      -- if not playing
    --loopCount = 0                                           -- reset loop
  end                                                       -- if playstate = play
   
  reaper.defer(loop)

end

--------------------------------------------
function main()
  reaper.defer(loop)
end
-----------------------------------------------
function SetButtonON()
  reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  reaper.RefreshToolbar2( sec, cmd )
  main()
end
-----------------------------------------------
function SetButtonOFF()
--  Clean()
  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  reaper.RefreshToolbar2( sec, cmd ) 
end
-----------------------------------------------
_, _, sec, cmd = reaper.get_action_context()
SetButtonON()
reaper.atexit(SetButtonOFF)
