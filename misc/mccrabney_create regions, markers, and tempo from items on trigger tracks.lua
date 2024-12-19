--[[
 * ReaScript Name: create regions, markers, and tempo from items on trigger tracks
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]
     
---------------------------------------------------------------------------------------    
-- add three tracks, respectively titled "markers" and "regions" and "tempo/time" to the top of your project. 
-- running this script will prints markers/regions/bpm markers from items on these tracks. 
-- markers/regions will inherit title, color, and length (for regions). regions can overlap.
-- does not support mid-project time signature changes (eg 4/4 -> 3/4)

extName = 'mccrabney_create regions, markers, tempo, and time signature from items on trigger tracks'

function deleteMarkers(objects)
  while objects >= 0 do       -- if markers or regions exist, delete all
    reaper.DeleteProjectMarkerByIndex( 0, objects )
    objects = objects - 1
  end
end

function deleteTempoMarkers(objects)
  while objects >= 0 do       -- if markers or regions exist, delete all
    reaper.DeleteTempoTimeSigMarker( 0, objects )
    objects = objects - 1
  end
end

targetTracks = 0
local markerTable = {}
markersAndRegions, markers, _, _= reaper.CountProjectMarkers( 0 )
ts = reaper.CountTempoTimeSigMarkers( 0 ) -- count timesig markers
bpm, numerator = reaper.GetProjectTimeSignature()
denominator = reaper.SNM_GetIntConfigVar( projtsdenom, 0 )

deleteMarkers(markersAndRegions)
deleteTempoMarkers(ts)
tsTable = {}

for i = 1, reaper.CountTracks(0) do               -- for each track
  if targetTracks > 2 then return end             -- quit when target tracks exhausted
  track = reaper.GetTrack(0,i-1)                  -- get track, name
  _, tr_name = reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', '', 0 ) -- get trackname

  if tr_name:lower():find("tempo/time") then      -- if track name is "markers"
    targetTracks = targetTracks + 1               -- tally target track
    local items = reaper.CountTrackMediaItems(track)    -- count items
    tsTable = {}                                  -- create a local table for the item
    for p = items, 0, -1 do                       -- for each item, last to first
      item = reaper.GetTrackMediaItem( track, p ) -- get item
      if item then                                -- if it's an item
        take = reaper.GetActiveTake(item)         -- get take
        takeName = reaper.GetTakeName( take )     -- get take details, add marker
        pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
        length = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
        if reaper.GetMediaItemInfo_Value( item, "B_MUTE") ~= 1 then -- if not muted
          local j = 0
          for param in string.gmatch(takeName, '([^,/%s]+)') do  -- get a table from string
            j = j + 1
            if tonumber(param) ~= nil then tsTable[j] = tonumber(param) end
          end
          if #tsTable == 2 then 
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], numerator, denominator, true)
          elseif #tsTable == 1 then 
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], numerator, denominator, false)
          end -- tsTable conditions
        end -- if item is not muted
      end -- if it's an item
    end -- for each item
    reaper.UpdateTimeline()
  end -- if correct track
  
  if tr_name:lower():find("regions") then         -- if track name is "regions"
    targetTracks = targetTracks + 1               -- tally target track
    local items = reaper.CountTrackMediaItems(track)    -- count items
    for i = 0, items do                           -- for each item
      item = reaper.GetTrackMediaItem( track, i ) -- get item
      if item then                                -- if it's an item
        take = reaper.GetActiveTake(item)         -- get take
        takeName = reaper.GetTakeName( take )     -- get take details, add region
        startPos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
        endPos   = startPos + reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
        name = reaper.GetMediaItemInfo_Value( item, "D_NAME" )
        color = reaper.GetDisplayedMediaItemColor(item)
        reaper.AddProjectMarker2( 0, true, startPos, endPos, takeName, i+1, color )
      end -- if it's an item
    end -- for each item
  end -- if correct track
  
  if tr_name:lower():find("markers") then         -- if track name is "markers"
    targetTracks = targetTracks + 1               -- tally target track
    local items = reaper.CountTrackMediaItems(track)    -- count items
    for i = 0, items do                           -- for each item
      item = reaper.GetTrackMediaItem( track, i ) -- get item
      if item then                                -- if it's an item
        take = reaper.GetActiveTake(item)         -- get take
        takeName = reaper.GetTakeName( take )     -- get take details, add marker
        pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
        name = reaper.GetMediaItemInfo_Value( item, "D_NAME" )
        color = reaper.GetDisplayedMediaItemColor(item)
        reaper.AddProjectMarker2( 0, false, pos, 0, takeName, i+1, color )
      end -- if it's an item
    end -- for each item
  end -- if correct track
end -- for each track
reaper.Undo_OnStateChange2(proj, "updated markers, regions, and tempo")

--[[  an attempt to handle time signature changes - issue is that changing ts

          if #tsTable == 4 then
            if tsTable[2] ~= nil then tsTable[2] = true else tsTable[2] = false end
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], tsTable[3], tsTable[4], tsTable[2])
          elseif #tsTable == 3 then 
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], tsTable[2], tsTable[3], false)
          elseif #tsTable == 2 then 
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], numerator, denominator, true)
          elseif #tsTable == 1 then 
            reaper.AddTempoTimeSigMarker(0, pos, tsTable[1], numerator, denominator, false)
          end -- tsTable conditions
--]]
