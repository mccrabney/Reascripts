--[[
 * ReaScript Name: select tiny items in tracks
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2023-03-17)
   + do nothing if no track is selected
 * v1.0 (2023-03-11)
   + Initial Release
--]]


------------------------------------------------------
local function no_undo()reaper.defer(function()end)end
-------------------------------------------------------

local CountTrack =  reaper.CountSelectedTracks(0)
if CountTrack == 0 then no_undo() return end  

local track = reaper.GetSelectedTrack( 0, CountTrack-1 )
if track == 0 then no_undo() return end  

local CountTrItem = reaper.CountTrackMediaItems(track)
if CountTrItems == 0 then no_undo() return end  

local cursorPos = reaper.GetCursorPosition()

local namedCommand = reaper.NamedCommandLookup("_SWS_UNSELONTRACKS")  -- unselect all item
reaper.Main_OnCommand(namedCommand, 0)

reaper.Undo_BeginBlock()

for i = 0, CountTrItem-1 do         -- for each item,               
  local item = reaper.GetTrackMediaItem(track,i)      
  local take = reaper.GetActiveTake(item)
  local isMIDI = reaper.TakeIsMIDI(take)
    
  if isMIDI ~= true then                 -- if take is not MIDI
    local fadeIn = reaper.GetMediaItemInfo_Value( item, 'D_FADEINLEN' )
    local fadeOut = reaper.GetMediaItemInfo_Value( item, 'D_FADEOUTLEN' )
    local autoFadeIn = reaper.GetMediaItemInfo_Value( item, 'D_FADEINLEN_AUTO' )
    local autoFadeOut = reaper.GetMediaItemInfo_Value( item, 'D_FADEOUTLEN_AUTO' )
    
    local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    local itemLength = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    
    if cursorPos < itemStart then       -- if itemstart is later than edit cursor
      if itemLength < 0.005 then 
        reaper.SetMediaItemSelected( item, 1 )
        reaper.Undo_EndBlock('selected tiny items' , -1)
      end     
    end
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock('no problematic items found' , -1)
