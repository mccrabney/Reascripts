--[[
 * ReaScript Name: delete notes under mouse cursor (and higher) in Razor Edits
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
    task = 15
    job = 1
    SetGlobalParam(job, task, _, _)
  end
  ----------------------------
  main()
