--[[
 * ReaScript Name: move RE &or edit cursor by visible grid division (forwards)
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2024-10-19)
   + added missing null variable
 * v1.0 (2021-03-22)
   + Initial Release
--]]


  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  
  local info = debug.getinfo(1,'S');
  script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]):match('(.*)\\')
  dofile(script_path .. "/mccrabney_Razor Edit Control Functions.lua")    
  ----------------------------  
  function main()
    incr = 1
    job = 3
    SetGlobalParam(job, _, _, _, incr)
  end
  ----------------------------
  defer(main)

