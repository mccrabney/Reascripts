--[[
 * ReaScript Name: open RS5K instance of note under cursor
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.00
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-09-02)
   + Initial Release
--]]

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_folder = string.gsub(script_folder, "MIDI Edits\\", "")
for key in pairs(reaper) do _G[key]=reaper[key]  end 
local info = debug.getinfo(1,'S');
dofile(script_folder .. "Razor Edits/mccrabney_Razor Edit Control Functions.lua")   
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")

extName = 'mccrabney_MIDI edit - show notes, under cursor and last-received.lua'

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
          open RS5K instance, if any, of note under target cursor 
    --]]------------------------------]]--

function main()
  reaper.PreventUIRefresh(1)
  _, cursorNote, _ = getNotesUnderMouseCursor()
  
  for j = 1, reaper.CountTracks(0) do
    tr = reaper.GetTrack(0,j-1)
    local _, chunk = reaper.GetTrackStateChunk( tr, '', false )
    
    for line in chunk:gmatch('[^\r\n]+') do
      
      if line:find('reasamplomatic.dll') then 
        local _, name = reaper.GetTrackName(tr, "") 
        
        for count = 0, reaper.TrackFX_GetCount(tr)-1 do
          local _, param = reaper.TrackFX_GetParamName(tr, count, 3, "")              
  
          if param == "Note range start" then
            nstart = reaper.TrackFX_GetParam(tr, count, 3)
            nstart = math.floor(nstart*128) if nstart == 128 then nstart = nstart-1 end
            
            if cursorNote == nstart then
              reaper.SetOnlyTrackSelected( tr, true )
              reaper.TrackFX_Show(tr, count, 1)
              reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSTL_SHOWMCPEX"), 0)
            end
          end
        end  
      end
    end
  end 
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  
end
 
main()

