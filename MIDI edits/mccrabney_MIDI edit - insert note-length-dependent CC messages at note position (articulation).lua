--[[
 * ReaScript Name: insert note-length-dependent CC messages at note position (articulation)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-1-14)
--]]

--[[

  NOTE: This is a "main screen" script- if using it from the MIDI editor, pass through the 
  keyboard shortcut to the main screen so that the script gets run.

  NOTE II: this script assumes you're using 960 ppq, scale as necessary

--]]

local articulationCC = 4    -- articulation CC, adjust as needed
local ccValTable = {  16,   24,   48,   96,  120 } -- EDIT THESE with desired CCvals per corresponding note   
                --  1/16,  1/8,  1/4,  1/2,    1  etc ... populate as desired by doubling number
local noteTable  = { 240,  480,  960, 1920, 3840 } -- ppq duration of common note divisions
local slop = .25     -- % of note duration over/undershoot to allow
               -- (set to 0 if you only run this on perfectly quantized MIDI)

prefix = 0  -- probably unnecessary. how many ticks ahead of note should CCs be inserted?

function insertCC()
  selectedItem = reaper.GetSelectedMediaItem(0, 0)
  if selectedItem ~= nil then
    for t = 0, reaper.CountTakes(selectedItem)-1 do -- Loop through all takes within each selected item
      take = reaper.GetTake(selectedItem, t)
      if reaper.TakeIsMIDI(take) then -- make sure, that take is MIDI
        local currentCC
        local ccCount, _, _ = reaper.MIDI_CountEvts(take) -- count cc in current take  
        
        for j = ccCount-1, 0, -1 do         -- delete pre-existing articulation CCs
          _, _, _, _, _, _, currentCC, _ = reaper.MIDI_GetCC( take, j )                
          if currentCC == articulationCC then reaper.MIDI_DeleteCC( take, j ) end
        end
        
        _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
        for n = 0, noteCount-1, 1 do         --- for each note
          _, _, _, noteStart, noteEnd, channel, _, _ = reaper.MIDI_GetNote( take, n )                
          local noteLength = noteEnd - noteStart
                      
          for i = 1, #noteTable do    -- for each entry in the noteTable,
            local note = noteTable[i]     -- set the note filter
            if math.abs(noteLength-note) < note*slop then   -- if within allowable length range,
              reaper.MIDI_InsertCC(take, 0, 0, noteStart-prefix, 191, channel, articulationCC, ccValTable[i]) 
            end
          end                 -- end for each entry in noteTable
        end                   -- end for each note
      end                     -- end ifMIDI
    end                       -- end for each take
  end                         -- end for ifnot nil
  reaper.UpdateArrange()
  reaper.Undo_OnStateChange2(proj, "inserted articulation CCs")
end      -- end function insertCC
  

function main()
  if window == "midi_editor" and not inline_editor then -- MIDI editor focused and not hovering inline editor
    local midi_editor = reaper.MIDIEditor_GetActive()   -- get active MIDI editor
    local take = reaper.MIDIEditor_GetTake(midi_editor) -- get take from active MIDI editor
    local item = reaper.GetMediaItemTake_Item(take)   -- get item from take
    insertCC() 
  
  else                   -- if user is in the inline editor or anywhere else
    if reaper.CountSelectedMediaItems(0) == 0 then
      --reaper.ShowMessageBox("Please select at least one item", "Error", 0)
      return false
  
    else                                        -- if an item is selected 
      for i = 0, reaper.CountSelectedMediaItems(0)-1 do -- loop through all selected items
        local item = reaper.GetSelectedMediaItem(0, i)  -- get current selected item
        local take = reaper.GetActiveTake(item)
        if reaper.TakeIsMIDI(take) then
          insertCC()
        else
          --reaper.ShowMessageBox("Selected item #".. i+1 .. " does not contain a MIDI take and won't be altered", "Error", 0)     
        end     
      end
    end
  end
end

main()
