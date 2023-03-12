--[[
 * ReaScript Name: select and move edit cursor to smallest item in track
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
   
 * v1.0 (2023-01-11)
   + Initial Release
--]]


------------------------------------------------------
local function no_undo()reaper.defer(function()end)end
-------------------------------------------------------
local CountTrack =  reaper.CountSelectedTracks(0)
local track = reaper.GetSelectedTrack( 0, CountTrack-1 )
local CountTrItem = reaper.CountTrackMediaItems(track)
---------------------------------------------------------------------
if CountTrack   == 0 then no_undo() return end  -- if no tracks or items, just give it up and quit
if CountTrItems == 0 then no_undo() return end  

local n = 0                                     --  audio item tally
local itemStartTable = {}
local itemLengthTable = {}
local itemLengthTableSorted = {}
local indexVal

reaper.Undo_BeginBlock()
local namedCommand = reaper.NamedCommandLookup("_SWS_UNSELONTRACKS")  -- unselect all item      
reaper.Main_OnCommand(namedCommand, 0)

for i = 0, CountTrItem-1 do         -- for each item,               
  local item = reaper.GetTrackMediaItem(track,i)      
  n = n + 1 
  local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
  local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
  local itemLength = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
  itemStartTable[n]   = itemStart
  itemLengthTable[n] = itemLength      
  itemLengthTableSorted[n] = itemLength  
end
  
table.sort(itemLengthTableSorted)  -- sort table low to high
for j = 1, #itemLengthTable do     -- for each entry in table
  if itemLengthTableSorted[1] == itemLengthTable[j] then -- if entries are equal
    indexVal = j-1
  end
end

if indexVal ~= nil then
  local itemSmallest = reaper.GetTrackMediaItem(track, indexVal)      
  local itemSmallestStart = reaper.GetMediaItemInfo_Value( itemSmallest, 'D_POSITION' )
  reaper.SetMediaItemSelected(itemSmallest, 1)
  reaper.SetEditCurPos(itemSmallestStart, 1, 0)
end

reaper.UpdateArrange()
reaper.Undo_EndBlock('select/move to smallest item start' , -1)
