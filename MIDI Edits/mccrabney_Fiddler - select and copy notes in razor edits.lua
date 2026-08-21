--[[
 * ReaScript Name: select and copy notes in razor edits
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.4
--]]
 
--[[
 * Changelog:
 * v1.6 (2025-_-_)
   + better RazorEditSelectionExists function
   + move from for getnote to while enumSel to speed up script
 * v1.5 (2025-_-_)
   + add single note copy without RE
   + improve RE selection behavior (if no notes are already selected, grab em all)
 * v1.4 (2025-1-3)
   + reaper.set_action_options(1)
 * v1.3 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.2 (2023-11-14)
   + fixed task #
 * v1.1 (2023-??-??)
   + new RE response
 * v1.0 (2023-??-??)
   + Initial Release
--]]


---------------------------------------------------------------------
    --[[------------------------------[[--
          get note and item under mouse   -- mccrabney      
    --]]------------------------------]]--
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
reaper.set_action_options(1)
-----------------------------------------------------------
    --[[------------------------------[[--
          check for razor edit 
    --]]------------------------------]]--
    
function RazorEditSelectionExists()
  for i = 0, reaper.CountTracks(0)-1 do
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then 
    return true end
  end--for  
  return false
end                              
            

----------------------

local function leq( a, b ) -- a less than or equal to b
  return a < b + 0.00001
end

local function geq( a, b ) -- a greater than or equal to b
  return a + 0.00001 > b 
end

local function GetItemsInRange(track, areaStart, areaEnd)
  --reaper.ShowConsoleMsg("GetItemsInRange" .. "\n")  
  local items, it = {}, 0
  for k = 0, reaper.CountTrackMediaItems(track) - 1 do 
    local item = reaper.GetTrackMediaItem(track, k)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemEndPos = pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        --check if item is in area bounds
    if geq(pos, areaEnd) or leq(itemEndPos, areaStart) then
      -- outside, do nothing
    else -- inside
      it = it + 1
      items[it] = item
    end
  end
  return items
end


------------------------------------
--
function GetRazorEdits()
  local trackCount = reaper.CountTracks(0)
  local areaMap = {}
  for i = 0, trackCount - 1 do
    local track = reaper.GetTrack(0, i)
    local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    if area ~= '' then            --PARSE STRING
      local str = {}
      for j in string.gmatch(area, "%S+") do table.insert(str, j) end
      local j = 1
      while j <= #str do                --area data
        local areaStart = tonumber(str[j])
        local areaEnd = tonumber(str[j+1])
        local GUID = str[j+2]
        local isEnvelope = GUID ~= '""'
        local items = {}            --get item/envelope data
        local envelopeName, envelope
        local envelopePoint
        if not isEnvelope then
          items = GetItemsInRange(track, areaStart, areaEnd)
        else
          --envelope = reaper.GetTrackEnvelopeByChunkName(track, GUID:sub(2, -2))
          --local ret, envName = reaper.GetEnvelopeName(envelope)
          --envelopeName = envName
          --envelopePoints = GetEnvelopePointsInRange(envelope, areaStart, areaEnd)
        end

        local areaData = {
          areaStart = areaStart,  areaEnd = areaEnd,
          track = track,  items = items,
          isEnvelope = isEnvelope,    --envelope data
          envelope = envelope,  envelopeName = envelopeName,
          envelopePoints = envelopePoints,  GUID = GUID:sub(2, -2)
        }

        table.insert(areaMap, areaData)
        j = j + 3
      end
    end
  end

  return areaMap
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          refer to extstates to get MIDI under mouse
    --]]------------------------------]]--

function getNotesUnderMouseCursor()
  
  showNotes = {}
  numVars = tonumber(reaper.GetExtState(extName, 1 ))
  tableSize = tonumber(reaper.GetExtState(extName, 2 ))
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 4 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+4) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  
  return take, targetNoteNumber, targetNoteIndex
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          select notes whose ons are in RE if present, else mute note under mouse, closest first
    --]]------------------------------]]--

selectedNotes = 0

function main()
  reaper.PreventUIRefresh(1)
  
  if RazorEditSelectionExists() then
    job = 1
    task = 11
    
    local areas = GetRazorEdits()          -- get all areas 
    for i = 1, #areas do                   -- for each razor edit, get each item
      local areaData = areas[i]
      if not areaData.isEnvelope then
        local items = areaData.items        
        local start_pos = areaData.areaStart  
        local end_pos = areaData.areaEnd
        
        for j = 1, #items do                           -- for each item, 
          local item = items[j]
          for t = 0, reaper.CountTakes(item)-1 do       -- for each take,
            take = reaper.GetTake(item, t)              -- get take
            if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
              local notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take    
              local i = -1                  -- in order to assess selection status of idx 0
              while i < notesCount-1 do     -- 
                local nextSel = reaper.MIDI_EnumSelNotes(take, i)  -- get idx of next selected note
                if nextSel ~= -1 then       -- if there is one,
                  selectedNotes = selectedNotes+1 
                  i = nextSel               -- set i to next selected note idx 
                else                        -- if there isn't
                  break                     -- 
                end                         -- end the while loop
              end
            end
          end
        end
      end
    end
    
    if selectedNotes == 0 then     -- if no notes are selected, select all notes in RE
      SetGlobalParam(1, 18)  -- select all in RE
    end
    
    SetGlobalParam(job, task)
  else                                          -- if no razor edit
    take = getNotesUnderMouseCursor()
    if take and reaper.TakeIsMIDI(take) then         -- if it's MIDI,
      item = reaper.GetMediaItemTake_Item(take)
      reaper.SetMediaItemSelected(item, 1)  -- select the first item
      reaper.Main_OnCommand(40153, 0)       -- open MIDI editor for selected item
      local activeEditor = reaper.MIDIEditor_GetActive()
      reaper.MIDIEditor_OnCommand(activeEditor, 40010)   -- copy selected notes from inside ME
      reaper.MIDIEditor_OnCommand(activeEditor, 40794 )   -- close the ME
      
          -- note copying is done this way because ME must be open in order for action to be run.
          -- in order to set MIDI clipboard to include MIDI from multiple editable items
          -- this results in an undesirable flicker as the MIDI editor opens and closes.
    end                                 -- if it's MIDI
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

end
 
main()


