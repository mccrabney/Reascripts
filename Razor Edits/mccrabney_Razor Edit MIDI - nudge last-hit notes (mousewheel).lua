--[[
 * ReaScript Name: nudge last-hit notes whose note-ons are contained in Razor Edit (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 (2023-05-26)
   + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts"
 * v1.1 (2023-05-21)
   + bring up to date with other scripts
 * v1.0 (2023-01-01)
   + Initial Release
--]]

 
 for key in pairs(reaper) do _G[key]=reaper[key]  end 
 
 local info = debug.getinfo(1,'S');
 script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]):match('(.*)\\')
 dofile(script_path .. "/mccrabney_Razor Edit Control Functions.lua")    
 ----------------------------  
 
 
function main()
  reaper.PreventUIRefresh(1)
  
  incr = tonumber(reaper.GetExtState(extName, 7 ))
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  
  if mouse_scroll > 0 then 
    incr = incr     
    elseif mouse_scroll < 0 then 
    incr = incr * -1                          -- how many ticks to move noteoff backwards, adjust as desired
  end
  
  SetGlobalParam(1, 13, _, _, incr)

end
  
  main()
