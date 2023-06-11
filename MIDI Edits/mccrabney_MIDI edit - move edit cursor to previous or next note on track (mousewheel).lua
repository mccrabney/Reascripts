--[[
 * ReaScript Name: move edit cursor to next/previous MIDI note in track
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.3
--]]
 
--[[
 * Changelog:
 * v1.3 (2023-6-3)
   + added extstate refresh support for "show notes"
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
extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'

------------------------------------------------------
local function no_undo()reaper.defer(function()end)end
-------------------------------------------------------

reaper.Undo_BeginBlock();
reaper.PreventUIRefresh(1)

--reaper.SetExtState(extName, 'DoRefresh', '1', false)

local incr
local tallyNotes = 0
local cursNote
local undoMessage

local startPosTable = {}
local endPosTable = {}
local notePitchTable = {}

local track = reaper.BR_GetMouseCursorContext_Track()
if track == nil then return end
reaper.SetOnlyTrackSelected( track )

local cursPos = reaper.GetCursorPosition()

local CountTrItem = reaper.CountTrackMediaItems(track)

----------------------- this if statement puts all track notes in a big table -------------
incr = 1
_,_,_,_,_,device,direction  = reaper.get_action_context() 

if device == 16383 and direction == 129      -- for relative 
or device == 127 and direction >= 15 then    -- for mousewheel
  incr = incr
  undoMessage = "move edit cursor to next note"
end

if device == 16383 and direction == 16383     -- for relative
or device == 127 and direction <= -15 then    -- for mousewheel
  incr = incr * -1
  undoMessage = "move edit cursor to prev note"
end  


for i = 0, CountTrItem-1 do                       
  local item = reaper.GetTrackMediaItem(track,i)      
  local take = reaper.GetActiveTake(item)
  local IsMIDI = reaper.TakeIsMIDI(take)
    
  if IsMIDI then                                   -- if take is MIDI
    itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take
    if notesCount == 0  then no_undo() return end  -- if no notes, give up and quit
    
    reaper.ClearConsole()
    for n = 0, notesCount-1 do               -- for each note, from last to first
      _, _, _, startppqposOut, endppqposOut, _, _, _ = reaper.MIDI_GetNote(take, n) 
      tallyNotes = tallyNotes+1
      startPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut) -- prj time of noteon ^
      endPosTable[tallyNotes] = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqposOut) -- prj time of noteoff ^
      if startPosTable[n] == startPosTable[n+1] then

        
      end
      
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


--reaper.SetExtState(extName, 'DoRefresh', '1', false)


reaper.PreventUIRefresh(-1)  
if undoMessage ~= nil then reaper.Undo_EndBlock(undoMessage ,-1) end
reaper.UpdateArrange()
