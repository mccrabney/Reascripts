--[[
 * ReaScript Name: toggle-enclose item under mouse cursor in RE
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


function RazorEditSelectionExists()

    for i=0, reaper.CountTracks(0)-1 do

        local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)

        if x ~= "" then return true end

    end--for
    
    return false

end--RazorEditSelectionExists()

if RazorEditSelectionExists() then
    reaper.Main_OnCommand(42406, 0)  -- clear RE
    reaper.Main_OnCommand(40528, 0)  -- select item under mouse cursor
    reaper.Main_OnCommand(42409, 0)  -- enclose selected item
    
else
    reaper.Main_OnCommand(40528, 0)  -- select item under mouse cursor
    reaper.Main_OnCommand(42409, 0)  -- enclose selected item
end  

reaper.UpdateArrange()
    
