--[[
 * ReaScript Name: move edit cursor to next MIDI note in track
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2023-1-3)
   + fixed in-between, end, start cursor pos 
   
 * v1.0 (2023-1-3)
 
   + Initial Release
--]]

------------------------------------------------------
local function no_undo()reaper.defer(function()end)end
-------------------------------------------------------

reaper.Undo_BeginBlock();
reaper.PreventUIRefresh(1)

reaper.ClearConsole()

local incr
local tallyNotes = 0
local cursNote
local undoMessage

local startPosTable = {}
local endPosTable = {}
local notePitchTable = {}

local CountTrack =  reaper.CountSelectedTracks(0)
local cursPos = reaper.GetCursorPosition()
local track = reaper.GetSelectedTrack( 0, CountTrack-1 )
local CountTrItem = reaper.CountTrackMediaItems(track)

incr = 1
undoMessage = "move edit cursor to next note"

if CountTrack == 0 then no_undo() return end  -- if no tracks, just give it up and quit
  
----------------------- this if statement puts all track notes in a big table -------------
  
for i = 0, CountTrItem-1 do                       
  local item = reaper.GetTrackMediaItem(track,i)      
  local take = reaper.GetActiveTake(item)
  local IsMIDI = reaper.TakeIsMIDI(take)
    
  if IsMIDI then                 -- if take is MIDI
    notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take

    for n = 0, notesCount-1 do               -- for each note
      _, _, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) 
      tallyNotes = tallyNotes+1
      startPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut) -- prj time of noteon ^
      endPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqposOut) -- prj time of noteoff ^
      notePitchTable[tallyNotes] = pitch     -- pitch of current note
                                             -- if cursor is in current note
      if cursPos >= startPosTable[tallyNotes] and cursPos < endPosTable[tallyNotes] then 
        cursNote = tallyNotes                -- get the note the cursor is in
      end
    end         -- for each note
  end           -- if MIDI
end             -- for each item

------------------------if cursor is not in a note------------------------------
if cursNote == nil then                       
  
  for t = 1, tallyNotes do                    -- for each note tallied, do
    
    if cursPos < startPosTable[1] then        -- if edit cursor is before first noteon then 
      reaper.SetEditCurPos(startPosTable[1], 1, 0)  -- set cursor to 1st noteon
    return end
    
    if cursPos > endPosTable[tallyNotes] then  -- if edit cursor is after last noteoff then
      reaper.SetEditCurPos(startPosTable[tallyNotes], 1, 0)  -- set cursor to last noteon
    return end
    
                  -- if cursor position is in between notes 
    if cursPos > startPosTable[t] and cursPos > endPosTable[t] and cursPos < startPosTable[t+1] then
      if     incr ==  1 then cursNote = t  end
    end
  end
end
--]]

--------------------------forwards-----------------------
if incr == 1 then  
  if cursNote + incr <= tallyNotes then -- if cursor+1 won't exceed total number of notes, 
    while startPosTable[cursNote] == startPosTable[cursNote + incr] do  -- if next note is in same place as note,
      incr = incr - 1                                  -- add another tick to incr to blast past the layered notes
    end
    reaper.SetEditCurPos(startPosTable[cursNote + incr], 1, 0 )  -- set edit cursor to next note position
  end
end




reaper.PreventUIRefresh(-1)  
reaper.Undo_EndBlock(undoMessage ,-1)
reaper.UpdateArrange()
