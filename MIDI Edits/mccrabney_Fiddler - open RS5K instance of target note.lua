--[[
 * ReaScript Name: open RS5K instance of target note
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.2
--]]
 
--[[
 * Changelog:
 * v1.2 (2024-5-21)
   + switch to using local Razor Edit Function module 
 * v1.1 
   + if only 1 instance of rs5k associated with note, open fx chain to index pos 1
 * v1.0 
   + Initial Release
--]]

-- HOW TO USE:
-- run "mccrabney_MIDI edit - show notes, under cursor and last-received.lua"
-- point the mouse at a note associated with an instance of RS5K in the arrange screen
-- run this script. any RS5Ks associated with this note will open, floating if multiple
-- if none exist, nothing will happen.

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Modules/mccrabney_Razor_Edit_functions.lua")   
extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

---------------------------------------------------------------------
    --[[------------------------------[[--
          refer to extstates to get MIDI under mouse
    --]]------------------------------]]--
    
function getNotesUnderMouseCursor()
  
  showNotes = {}
  numVars = tonumber(reaper.GetExtState(extName, 1 ))
  tableSize = tonumber(reaper.GetExtState(extName, 2 ))
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  
  targetNoteNumber = tonumber(reaper.GetExtState(extName, 4 ))
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  
  if tableSize ~= nil then 
    for t = 1, tableSize do
      showNotes[t] = {}
      if reaper.HasExtState(extName, t+numVars) then
        for i in string.gmatch(reaper.GetExtState(extName, t+numVars), "-?%d+,?") do
          table.insert(showNotes[t], tonumber(string.match(i, "-?%d+")))
        end
      end
    end
  end
  
  return take, targetNoteNumber, targetNoteIndex
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          open RS5K instances, if any, of note under target cursor 
    --]]------------------------------]]--

rs5ks = {}
instance = 0
prevTrack = -1

reaper.ClearConsole()

function main()
  reaper.Main_OnCommand( 40297, 0)                                    -- unselect all tracks
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS3"), 0)  -- close all floating fx windows
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS4"), 0)  -- close all fx chain windows
  reaper.PreventUIRefresh(1)
  _, cursorNote, _ = getNotesUnderMouseCursor()
  
  if cursorNote then                                 -- if there's a note under the cursor
    for j = 1, reaper.CountTracks(0) do              -- for each track
      tr = reaper.GetTrack(0, j - 1)                 -- get track
      fxCount = reaper.TrackFX_GetCount(tr)          -- count fx on each instance track
        
      for p = 0, fxCount-1 do                        -- for each fx
        retval, buf = reaper.TrackFX_GetNamedConfigParm( tr, p, "fx_name" ) 
      
        if buf:match("ReaSamplOmatic5000")  then     -- if RS5K
          local _, param = reaper.TrackFX_GetParamName(tr, p, 3)  -- get param name        
          
          if param == "Note range start" then        -- if it's the right one, and if it's rs5k,
            noteStart = reaper.TrackFX_GetParam(tr, p, 3)        -- set/fix math for noteStart value
            noteStart = math.floor(noteStart*128) if noteStart == 128 then noteStart = noteStart - 1 end
            
            if cursorNote == noteStart then          -- if it's the same as our note under cursor,
              instance = instance + 1
              reaper.SetTrackSelected( tr, true )
              reaper.TrackFX_Show(tr, p, 3 )         -- float all RS5Ks
              reaper.TrackFX_Show(tr, 0, 1 )         -- open FX chain window to first fx index
            end
          end
        end                                          -- if RS5K
      end                                            -- for each fx
    end                                              -- for each track
    
    if instance == 1 then                            -- if there's only 1 rs5k instance associated with note,
      reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS5"), 0) -- close floating fx into fx chain window
    end
     
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSTL_SHOWMCPEX"), 0) -- show selected tracks in MCP
    --reaper.Main_OnCommand(41155, 0)                  -- reposition floating windows
  end                                                -- if there's a note under the cursor
    
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
 
main()

