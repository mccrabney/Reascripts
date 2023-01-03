--[[
 * ReaScript Name: move edit cursor to next/previous MIDI note in track
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-1-3)
   + Initial Release
--]]

------------------------------------------------------
local function no_undo()reaper.defer(function()end)end
-------------------------------------------------------

reaper.Undo_BeginBlock();
reaper.PreventUIRefresh(1)

local direction
local tallyNotes = 0
local cursNote
local undoMessage

local noteStartPosTable = {}
local noteEndPosTable = {}
local notePitchTable = {}

local CountTrack =  reaper.CountSelectedTracks(0)
local editCursorPos = reaper.GetCursorPosition()
local track = reaper.GetSelectedTrack( 0, CountTrack-1 )
local CountTrItem = reaper.CountTrackMediaItems(track)

_,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
if mouse_scroll > 0 then 
  direction = 1
  undoMessage = "move edit cursor to next note"
elseif mouse_scroll < 0 then 
  direction = -1
  undoMessage = "move edit cursor to prev note"
end

if CountTrack == 0 then no_undo() return end
  
for i = 0, CountTrItem-1 do                       -- this if statement puts all track notes in a big table,
  local item = reaper.GetTrackMediaItem(track,i)      
  local take = reaper.GetActiveTake(item)
  local IsMIDI = reaper.TakeIsMIDI(take)
    
  if IsMIDI then                 -- if take is MIDI
    notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take

    for n = 0, notesCount-1 do               -- for each note
      _, _, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) 
      tallyNotes = tallyNotes+1
      noteStartPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut) -- prj time of noteon ^
      noteEndPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqposOut) -- prj time of noteoff ^
      notePitchTable[tallyNotes] = pitch     -- pitch of current note
                                             -- if cursor is in current note
      if editCursorPos >= noteStartPosTable[tallyNotes] and editCursorPos < noteEndPosTable[tallyNotes] then 
        cursNote = tallyNotes                -- get the note the cursor is in
      end
    end         -- for each note
  end           -- if MIDI
end             -- for each item

if direction == 1 then  
  if editCursorPos > noteStartPosTable[tallyNotes] and cursNote == nil then     -- if edit cursor is after last note
    reaper.SetEditCurPos(noteStartPosTable[tallyNotes], 1, 0 )  -- set edit cursor to last note pos
    cursNote = tallyNotes+1                              
  end

  if cursNote ~= nil and cursNote + direction <= tallyNotes then -- if cursor is in note and movement won't < total of notes, 
    while noteStartPosTable[cursNote] == noteStartPosTable[cursNote + direction] do  -- if next note is in same place as note,
      direction = direction - 1                                  -- add another tick to direction
    end
    reaper.SetEditCurPos(noteStartPosTable[cursNote + direction], 1, 0 )  -- set edit cursor to first note pos
  end

elseif direction == -1 then 
  if editCursorPos > noteStartPosTable[tallyNotes] and cursNote == nil then     -- if edit cursor is after last note
    reaper.SetEditCurPos(noteStartPosTable[tallyNotes], 1, 0 )  -- set edit cursor to last note pos
    cursNote = tallyNotes+1                              
  end
  
  if cursNote ~= nil and cursNote + direction >= 1 then -- if cursor is in note and movement won't > 1, 
    while noteStartPosTable[cursNote] == noteStartPosTable[cursNote + direction] do  -- if next note is in same place as note,
      direction = direction - 1                                  -- add another tick to direction
    end
    
    reaper.SetEditCurPos(noteStartPosTable[cursNote + direction], 1, 0 )  -- set edit cursor to first note pos
  end
end

reaper.PreventUIRefresh(-1)  
reaper.Undo_EndBlock(undoMessage ,-1)
reaper.UpdateArrange()
