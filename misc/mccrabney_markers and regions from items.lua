--[[
 * ReaScript Name: markers and regions from items
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.01
--]]
     
  ---------------------------------------------------------------------------------------    

-- prints markers and regions from items on tracks titled "markers" / "regions"
-- will inherit title, color, and length (for regions). regions can overlap.
-- see this post for gif/usage description https://forum.cockos.com/showthread.php?p=2707391#post2707391

local markerTable = {}
markersAndRegions, markers, _, _= reaper.CountProjectMarkers( 0 )

while markersAndRegions >= 0 do
  reaper.DeleteProjectMarkerByIndex( 0, markersAndRegions )
  markersAndRegions = markersAndRegions - 1
end

for i = 0, markers do
  if markrgnindexnumber ~= 0 then
    retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    markerTable[i] = {retval, isrgn, pos, rgnend, name, markrgnindexnumber, color }
    --reaper.ShowConsoleMsg("------------------\n" .. "marker: " .. retval .. "\nis region? " .. tostring(isrgn) .. "\npos: " .. pos .. "\nend: " .. rgnend .. "\nname: " .. name .. "\nmarkrgnindexnumber: " .. markrgnindexnumber .. "\ncolor: " .. color .. "\n" )
  end
end

for i = 1, reaper.CountTracks(0) do
  track = reaper.GetTrack(0,i-1)
  _, tr_name = reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', '', 0 )
  
  if tr_name:lower():find("markers") then
    items = reaper.CountTrackMediaItems(track)
    for i = 0, items do
      item = reaper.GetTrackMediaItem( track, i )
      if item then
        take = reaper.GetActiveTake(item)
        takeName = reaper.GetTakeName( take )
        pos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
        name = reaper.GetMediaItemInfo_Value( item, "D_NAME" )
        color = reaper.GetDisplayedMediaItemColor(item)
        reaper.AddProjectMarker2( 0, false, pos, 0, takeName, i+1, color )
      end
    end
  end
  
  if tr_name:lower():find("regions") then
    items = reaper.CountTrackMediaItems(track)
    for i = 0, items do
      item = reaper.GetTrackMediaItem( track, i )
      if item then
        take = reaper.GetActiveTake(item)
        takeName = reaper.GetTakeName( take )
        startPos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
        endPos   = startPos + reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
        name = reaper.GetMediaItemInfo_Value( item, "D_NAME" )
        color = reaper.GetDisplayedMediaItemColor(item)
        reaper.AddProjectMarker2( 0, true, startPos, endPos, takeName, i+1, color )
      end
    end
    return
  end
end
