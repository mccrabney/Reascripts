--[[
 * ReaScript Name: nudge notes whose note-ons are contained in Razor Edit (mousewheel)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2021-04-02)
   + Initial Release
--]]

 
 for key in pairs(reaper) do _G[key]=reaper[key]  end 
 
 local info = debug.getinfo(1,'S');
 script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]):match('(.*)\\')
 dofile(script_path .. "/mccrabney_Razor Edit Control Functions.lua")    
 ----------------------------  
 
 
  function main()
     _,_,_,_,_,_,mouse_scroll  = reaper.get_action_context() 
    if mouse_scroll > 0 then 
    task = 6
    job = 1
    SetGlobalParam(job, task, _)
    elseif mouse_scroll < 0 then 
    task = 7
    job = 1
    SetGlobalParam(job, task, _)
    end
  end
  
  
  defer(main)
