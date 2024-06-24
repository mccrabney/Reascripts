--[[
 * ReaScript Name: markers and regions from items
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.02
--]]
     
  ---------------------------------------------------------------------------------------    

-- add two tracks, respectively titled "markers" and "regions" to the top of your project
-- running this script will prints markers/regions from items on these tracks 
-- markers/regions will inherit title, color, and length (for regions). regions can overlap.
-- see this post for gif/usage description https://forum.cockos.com/showthread.php?p=2707391#post2707391


local targetTracks = 0

local markerTable = {}
markersAndRegions, markers, _, _= reaper.CountProjectMarkers( 0 )

while markersAndRegions >= 0 do       -- if markers or regions exist, delete all
  reaper.DeleteProjectMarkerByIndex( 0, markersAndRegions )
  markersAndRegions = markersAndRegions - 1
end

for i = 1, reaper.CountTracks(0) do       -- for each track
  track = reaper.GetTrack(0,i-1)          -- get track, name
  _, tr_name = reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', '', 0 )
  
  if tr_name:lower():find("regions") then         -- if track name is "regions"
    targetTracks = targetTracks + 1               -- tally target track
    items = reaper.CountTrackMediaItems(track)    -- count items
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
    items = reaper.CountTrackMediaItems(track)    -- count items
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
  
  if targetTracks > 1 then return end             -- do it once
  
end

--[[
for i = 0, markers do                 -- for each marker, get info
  if markrgnindexnumber ~= 0 then
    retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    markerTable[i] = {retval, isrgn, pos, rgnend, name, markrgnindexnumber, color }
    --reaper.ShowConsoleMsg("------------------\n" .. "marker: " .. retval .. "\nis region? " .. tostring(isrgn) .. "\npos: " .. pos .. "\nend: " .. rgnend .. "\nname: " .. name .. "\nmarkrgnindexnumber: " .. markrgnindexnumber .. "\ncolor: " .. color .. "\n" )
  end
end

--]]
