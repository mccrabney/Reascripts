--[[
 * ReaScript Name: delete last-hit notes in Razor Edit
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
  dofile(script_path .. "/mccrabney_razor edits_Razor Edit Control Functions.lua")    
  ----------------------------  
  function main()
  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.
    task = 0
    job = 1
    SetGlobalParam(job, task, _)
  reaper.Undo_EndBlock("Delete Last-Hit Notes from Razer Edits", 0) -- End of the undo block. Leave it at the bottom of your main function.
  end
  ----------------------------
  defer(main)

