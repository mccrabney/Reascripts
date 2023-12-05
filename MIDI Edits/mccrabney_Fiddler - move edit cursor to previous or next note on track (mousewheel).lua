--[[
 * ReaScript Name: move edit cursor to previous or next note on track (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.4
--]]
 
--[[
 * Changelog:
 * v1.4 (2023-11-26)
   + switch to edit cursor target
 * v1.3 (2023-1-4)
   + fixed another nil comparison
 * v1.2 (2023-1-3)
   + fixed nil comparisons
 * v1.1 (2023-1-3)
   + fixed in-between, end, start cursor pos 
 * v1.0 (2023-1-3)
   + Initial Release
--]]

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

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

if reaper.HasExtState(extName, 8) then                        -- get cursor
  cursor = tonumber(reaper.GetExtState( extName, 8 ))         -- based on input from child script
end   

if cursor == 1 then 
  cursPos = reaper.BR_PositionAtMouseCursor( 0 )
else  
  cursPos = reaper.GetCursorPosition()
end

local track = reaper.GetSelectedTrack( 0, CountTrack-1 )
if track then
  local CountTrItem = reaper.CountTrackMediaItems(track)
  
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  if mouse_scroll > 0 then 
    incr = 1
    undoMessage = "move edit cursor to next note"
  elseif mouse_scroll < 0 then 
    incr = -1
    undoMessage = "move edit cursor to prev note"
  end
  
  if CountTrack   == 0 then no_undo() return end  -- if no tracks or items, just give it up and quit
  if CountTrItems == 0 then no_undo() return end  
  ----------------------- this if statement puts all track notes in a big table -------------
  reaper.SetExtState(extName, 'setCursorEdit', '1', false)       -- set incr extstatem, save between sessions
    
  for i = 0, CountTrItem-1 do                       
    local item = reaper.GetTrackMediaItem(track,i)      
    local take = reaper.GetActiveTake(item)
    local IsMIDI = reaper.TakeIsMIDI(take)
      
    if IsMIDI then                                   -- if take is MIDI
      notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
      if notesCount == 0  then no_undo() return end  -- if no notes, give up and quit
   
      for n = 0, notesCount-1 do               -- for each note
        _, _, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) 
        tallyNotes = tallyNotes+1
        startPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut) -- prj time of noteon ^
        endPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqposOut) -- prj time of noteoff ^
        --notePitchTable[tallyNotes] = pitch     -- pitch of current note, unused for now
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
        if     incr ==  1 then cursNote = t 
        elseif incr == -1 then cursNote = t+1 end
      end
    end
  end
  --]]
  
  --------------------------forwards-----------------------
  if incr == 1 then  
    if cursNote ~= nil and cursNote + incr <= tallyNotes then -- if cursor+1 won't exceed total number of notes, 
      while startPosTable[cursNote] == startPosTable[cursNote + incr] do  -- if next note is in same place as note,
        incr = incr - 1                                  -- add another tick to incr to blast past the layered notes
      end
      reaper.SetEditCurPos(startPosTable[cursNote + incr], 1, 0 )  -- set edit cursor to next note position
    end
  
  ----------------------------backwards-----------------------------------------
  elseif incr == -1 then 
  
    if cursNote ~= nil and cursNote + incr >= 1 then -- if cursor is in note and movement won't > 1, 
      while startPosTable[cursNote] == startPosTable[cursNote + incr] do  -- if next note is in same place as note,
        incr = incr - 1                                  -- add another tick to incr to blast past the layered notes
      end
      reaper.SetEditCurPos(startPosTable[cursNote + incr], 1, 0 )  -- set edit cursor to first note pos
    end
  
  end
  
  
  
  
  reaper.PreventUIRefresh(-1)  
  reaper.Undo_EndBlock(undoMessage ,-1)
  reaper.UpdateArrange()
end
