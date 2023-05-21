--[[
 * ReaScript Name: pause show notes script
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:

 * v1.0 (2023-01-01)
   + Initial Release
--]]

extName = "mccrabney_MIDI edit - show notes, under mouse and last-received.lua"  

---------------------------------------------------------------------
    --[[------------------------------[[--
          pause show notes script
    --]]------------------------------]]--

function main()

  reaper.SetExtState(extName, 'Pause', '1', false)
  
end
 
main()


