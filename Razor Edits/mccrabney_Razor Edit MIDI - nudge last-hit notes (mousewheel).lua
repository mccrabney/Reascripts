--[[
 * ReaScript Name: nudge last-hit notes whose note-ons are contained in Razor Edit (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
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
  _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
  task = 13
  job = 1

  if mouse_scroll > 0 then 
    incr = 50
  elseif mouse_scroll < 0 then 
    incr = -50
  end
  
  SetGlobalParam(job, task, _, _, incr)

end
  
  main()
