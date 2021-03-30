--[[
 * ReaScript Name: select tracks with razor edits
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2021-03-22)
   + Initial Release
--]]


for t = 0, reaper.CountTracks(0)-1 do
    local track = reaper.GetTrack(0, t)
    local razorOK, razorStr = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
    if razorOK and #razorStr ~= 0 then
    reaper.AnyTrackSolo(track, 1)
        end
end
