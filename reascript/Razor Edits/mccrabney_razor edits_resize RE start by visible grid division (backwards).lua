--[[
 * ReaScript Name: resize RE start by visible grid division (backwards)
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


  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  
  local info = debug.getinfo(1,'S');
  script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]):match('(.*)\\')
  dofile(script_path .. "/mccrabney_razor edits_Razor Edit Control Functions.lua")  
  ----------------------------  
  function main()
    incr = -1
    param = 1
    SetGlobalParam(_, param, incr )
  end
  ----------------------------
  defer(main)

