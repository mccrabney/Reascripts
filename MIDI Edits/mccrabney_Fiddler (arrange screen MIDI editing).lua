--[[
 * ReaScript Name: Fiddler (arrange screen MIDI editing).lua
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 2.00
 * Provides: Modules/*.lua
--]]

--[[
 * Changelog:
 * v2.00 (2026-08-21)
   + changed core targeting/action behavior to work on selected MIDI notes instead of cursor-aimed MIDI notes
   + performance improvements
--]]
 
-- discussion thread: https://forum.cockos.com/showthread.php?t=274257 

-- HOW TO USE:
-- run this defer script and its companion "Clicker", then mouse over MIDI in your arrange screen.
-- guidelines and a readout will appear, targeting the MIDI under your mouse.
-- use the other Fiddler scripts to edit MIDI from the arrange screen.

---------------------------------------------------------------------
local idleTask = 1     -- run idle task or not

--local profiler = dofile(reaper.GetResourcePath() ..
--  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
--reaper.defer = profiler.defer

reaper.ClearConsole()
reaper.set_action_options(1)

local extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak") 
require("Modules/mccrabney_Razor_Edit_functions")
require("Modules/mccrabney_MIDI_Under_Mouse")
require("Modules/mccrabney_misc")

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'
local main_wnd = reaper.GetMainHwnd()                                -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local ctx = ImGui.CreateContext('MIDI Note Overlay', ImGui.ConfigFlags_NoSavedSettings)
local font = reaper.ImGui_CreateFont('monospace', 35)
reaper.ImGui_Attach(ctx, font)

local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
local lastSysTime


--]]------------------------------------------------------------------
------------LOOP------------------------------------------------------
-- [[-----------------------------------------------------------------
local arrangeTime, lastArrangeTime = 0, 0 -- time that is contained within Arrange
local editCurPosLast = -1   -- ^
local popIn = 0             -- pop in MIDI note from external controller
local selectedNotes = 0     -- how many notes are selected
local noteTrack = nil       -- track that presumeably has notes.
local lastNoteTrack
local lastX = -1            -- previous mouse position initialized to n/a
local prjChangeCount = -1  
local lastprjChangeCount = -1  
reset = 0

if reaper.CountTracks(0) > 0 then
  lastNoteTrack = reaper.GetTrack(0, 0)
end


----------------------------------------------------------------------
--------- loop and show tooltips, cursor as necessary  
-- [[-----------------------------------------------------------------  
local loopCount, idleCount, elapsed = 0, 0, 0                   -- time variables
function loop()
  local sysTime = math.floor(reaper.time_precise())             -- system time rounded to 1s
  
  if sysTime ~= lastSysTime then                                -- heartbeat for other scripts to check
    reaper.SetExtState(extName, 'time', sysTime, true)          -- time extstate
    lastSysTime = sysTime
  end
  
  loopCount, idleCount = loopCount + 1, idleCount + 1           -- advance counts
  local editCurPos = reaper.GetCursorPosition()                 -- where is cursor?
                                                                -- optimizer to reduce calls to getCursorInfo
  if info == "arrange" and lastX ~= x and popIn == 0            -- if we're in the right place, and on the move
  or editCurPos ~= editCurPosLast then                          -- or if the edit cursor has moved,
    local _, windowList = reaper.JS_Window_ListAllTop()           -- reaimgui setup
    
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos,      -- run function to get info of notes under mouse
    targetEndPos, track, trPos, tcpHeight, trName, cursorPos, targetMute, mouseTake, mouseTrPos = getCursorInfo() 
    
    
    if take and reaper.TakeIsMIDI(take) then                    -- if take is MIDI
      loopCount, idleCount = 0, 0                               -- reset counters
      lastX = x                                                 -- set lastX mouse position
    else lastX = x end                                          -- if nonMIDI, set lastX mouse position
  end                                                           -- end optimizer

  local reaper_vp = ImGui.GetMainViewport(ctx)                  -- reaimgui setup
  if reaper_vp and reaper_vp ~= lastvp then 
    ImGui.SetNextWindowPos(ctx, ImGui.Viewport_GetPos(reaper_vp)) 
    ImGui.SetNextWindowSize(ctx, ImGui.Viewport_GetSize(reaper_vp))
    lastvp = reaper_vp
  end

  extStates()                                                   -- communicate with other scripts via extstates
  idleSensor()                                                  -- sense if no mouse movement for a short period
  x, y = reaper.GetMousePosition()                              -- get mousepos
  _, info = reaper.GetThingFromPoint(x, y)                      -- get mousedetails
  

  ------------------------------------------------------------------
  ---------- get last note hit  -----------------------------------
  ------------------------------------------------------------------
  if loopCount < 500 then                                       -- if less than idletime, get lastnotehit
    lastNote, lastVel, inputNote = getLastNoteHit()       
  end                                                           
  
  if lastNote == -1 then popIn = 0 end                            -- when no notes received, reset incoming midi flag 
  if lastNote ~= -1 and lastNote and take and info == 'arrange' and popIn == 0 then  -- when notes are received,
    popIn = 1                                                     -- MIDI is being received
    if track then 
      _, sourceTrName = reaper.GetTrackName( track )            -- get the name of the track where the note originates
      if sourceTrName == "sequencer" then                       -- if it's from a sequencer, 
        local trName = getInstanceTrackName(lastNote)           -- detect trackname of RS5K instance
        trName = "'" .. trName .. "'"                           -- pad with quote
      end
      if trName == nil then trName = "" end                     -- if nil, write empty
    end      
    reaper.SetExtState(extName, 'DoRefresh', 1, false)
    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1)               -- establish note symbol
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  
  --]]-----------------------------------------------------------------------------------------------
  ------------------------------GUI ---------------------------------------------------------------
  -- [[-----------------------------------------------------------------  
  local startTime, endTime = reaper.GetSet_ArrangeView2(0, 0, 0, 0)  -- get arrangescreen pos
  arrangeTime = startTime + endTime                             -- sum values to determine change
  mouseNoteTable = {}                                           -- note table for notes under mouse
  local dimensions = {}                                         -- dimensions table
  local draw_list = ImGui.GetWindowDrawList(ctx)                -- reaimgui setup
  local time_start
  if arrangeTime ~= lastArrangeTime then            -- if arrange screen bounds have moved
    elapsed = 0                                     -- timer == 0
    reset = 1
    time_start = reaper.time_precise()              -- start the clock
  else                                              -- if arrange screen bounds haven't changed,
    --elapsed = reaper.time_precise() - time_start    -- set elapsed time since arrange hasn't moved
    elapsed = reaper.time_precise()                 -- set elapsed time since arrange hasn't moved
  end
  lastArrangeTime = arrangeTime                     -- get last arrangetime value
  
  
  --]]---------------------------------------------------------------------------------------
  --------- build note table when track selected, watch for track changes to deselect MIDI---
  -- [[-----------------------------------------------------------------  
  local trNum = reaper.GetNumTracks()
  local selTracks = reaper.CountSelectedTracks(0)
  if selTracks == 1 then                                -- if one track is selected
    local noteTrack = reaper.GetSelectedTrack(0,0)      -- set notetrack to first selected track
    
    if noteTrack == lastNoteTrack and reset == 1 then   -- rebuild note table if reset
      sNoteDrawTable = buildNoteTable(noteTrack)        -- build table of selected notes
      reset = 0
    end                   
    
    if noteTrack ~= lastNoteTrack then                -- if track selection has changed
      if trNum then                                   -- if there are tracks
        for t = 0, trNum-1, 1 do                          -- for each track
          if reaper.GetTrack(0, t) == lastNoteTrack then  -- make sure lastTrack is in prj (eg if deleted)
            local CountTrItem = reaper.CountTrackMediaItems(lastNoteTrack)
             if CountTrItem then                                -- if track has items
              for i = 0, CountTrItem-1 do                       -- for each item,               
                local item = reaper.GetTrackMediaItem(lastNoteTrack,i)      
                local take = reaper.GetActiveTake(item, 0)      -- get the take
                if take then reaper.MIDI_SelectAll(take, 0) end -- deselect all notes
              end
            end
          end
        end
      end
      lastNoteTrack = noteTrack
      reset = 1
    end
  end
  
  ----------------------------------------------------------------------
  ------------------------if notes are selected and statechanged, dorefresh ---------
  -- [[-----------------------------------------------------------------  
  prjChangeCount = reaper.GetProjectStateChangeCount(0)         -- refresh ui at every change
  if prjChangeCount ~= lastprjChangeCount and selTracks == 1 then
    reaper.SetExtState(extName, 'DoRefresh', 1, false)
    lastprjChangeCount = prjChangeCount
  end
  
  
  ----------------------------------------------------------------------
  ------------------------insert single note at mouse cursor ---------
  -- [[-----------------------------------------------------------------  
  if lastNote ~= prevLastNote then                      -- if note changed and input condition is met
    reaper.SetExtState(extName, 'noteHoldNumber', lastNote, false)    -- focus on the last note from controller
    if lastNote ~= -1 then noteTimer = reaper.time_precise() end      -- start timer to detect note duration
    if lastNote == -1 then noteOffTimer = reaper.time_precise() end   -- stop timer to detect note duration
    if noteTimer and noteOffTimer and noteOffTimer - noteTimer > 0 then -- if a note is pressed and held
      noteDuration = noteOffTimer - noteTimer                          -- calculate note duration
    end
    
    if lastVel == nil then lastVel = -1 end                            -- force nil to n/a value
    if editCurPos and noteDuration and input == 1 and lastNote == -1 and lastVel then -- on noteoff
      local mouseTrackName = 0
      if reaper.CountSelectedTracks(0) == 1 then                      -- if 1 track selected
        inputTrack = reaper.GetSelectedTrack(0, 0)                    -- set input track to sel track
        if track == inputTrack then
          _, mouseTrackName = reaper.GetTrackName(track)
          if mouseTake and not string.find(mouseTrackName, "Master") then    
            local chan = tonumber(string.match(mouseTrackName, "%d+"))  -- check for channel info
            if chan == nil then chan = 1 end
            local noteStartPpq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(mouseTake, editCurPos))
            local noteEndPpq = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, editCurPos + noteDuration)
            if chan <= 16 or chan >= 1 then 
              local _, numNotes = reaper.MIDI_CountEvts(mouseTake)
              if numNotes >= 1 then
                for p = numNotes-1, 0, -1 do
                  local _, _, _, startppqpos, _, _, pitch, _ = reaper.MIDI_GetNote(mouseTake, p)
                  if pitch == prevLastNote and startppqpos == noteStartPpq then    -- if note already exists
                    reaper.MIDI_DeleteNote(mouseTake, p)    -- delete it before inserting new note
                  end -- if note preexists
                end -- for each note
              end -- if 1 or more note
              reaper.MIDI_InsertNote(mouseTake, true, false, noteStartPpq, noteEndPpq, chan-1, prevLastNote, lastVel)
              reaper.MIDI_Sort(mouseTake)
              reaper.Undo_OnStateChange2(proj, "inserted note at edit cursor" )
            else
              -- message to compell users to use a sensible channel integer in track?
            end
          else
            -- message to compell users to put a channel identifier in the track title?
            -- and/or to not use master track?
          end
        end
      end
    end
    prevLastNote = lastNote    -- if noteon is followed by a noteoff
  end
  

  ---]]-----------------------------------------------------------------
  ----------------single target note------------------------------------  
  -- [[-----------------------------------------------------------------  
  if targetPitch and info == "arrange" and take and elapsed > 0  
  or targetPitch and dbg == 1 and take and elapsed > 0 then
    if targetNotePos then                                   -- if there's a note pos to target,
      local zoom_lvl     = reaper.GetHZoomLevel()           -- get arrange zoom level
      targetNotePixel    = math.floor((targetNotePos - startTime) * zoom_lvl) -- get note start pixel
      targetNotePixelEnd = math.floor((targetEndPos  - startTime) * zoom_lvl) -- get note end pixel
      if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
      if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
      local incr = 0
      for i = #showNotes, 1, -1 do
        if showNotes[i][1] > targetPitch then
          incr = incr + 1
        --elseif showNotes[i][1] < targetPitch then
          --fromhigh = fromhigh + 1
        end
      end
      if targetNotePixel then                      -- if we have a target pixel, map to screen
        local sx, sy = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, trPos)
        --local sx, sy = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, trPos+math.floor((tcpHeight/#showNotes)*incr))
        --local _, syHeight = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, math.floor(trPos+(tcpHeight/#showNotes)*incr))
        local _, syHeight = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, trPos+tcpHeight)
        sx, sy = ImGui.PointConvertNative(ctx, sx, sy, false)
        _, syHeight = ImGui.PointConvertNative(ctx, sx, syHeight, false)
        local sxEnd, val = reaper.JS_Window_ClientToScreen(track_window, targetNotePixelEnd, trPos)
        sxEnd, _ = ImGui.PointConvertNative(ctx, sxEnd, val, false)
        selectedNotes = selectedNotes + 1
        mouseNoteTable = {sx, sxEnd, sy, syHeight, targetMute} -- build the note table
      end
    end
  end
  
  
  ---]]-----------------------------------------------------------------
  --- get the dimensions of any open windows  ---
  -- [[-----------------------------------------------------------------  
  windows = 0
  local address
  if windowList then 
    for address in windowList:gmatch('[^,]+') do                -- cycle through the open REAPER window addresses
      local hwnd = reaper.JS_Window_HandleFromAddress(address)  -- get the windows, exclude non-REAPER windows
      if reaper.JS_Window_IsVisible(hwnd) and reaper.JS_Window_GetParent(hwnd) == reaper.GetMainHwnd() then
        local hwndID = reaper.JS_Window_GetTitle( hwnd )              -- get their IDs, exclude irrelevant windows
        if hwndID ~= 'Overlay' and hwndID ~= 'mouseDrawStart' and hwndID ~= 'mouseDrawEnd' and hwndID ~= 'Tooltip' and hwndID ~= 'ReaScript console output' and hwndID ~= 'note' then 
          if hwndID then 
            windows = windows + 1                               -- count number of windows
            local _, left, top, right, bottom = reaper.JS_Window_GetClientRect(hwnd) -- get their dimensions
            dimensions[windows] = { left, right, top, bottom }
          end  -- if hwndID isn't nil
        end  -- if not certain windows
      end  -- if visible, REAPER window
    end  -- for each window address
  end
  
  
  --------------------------------------------------------
  --remove overlap if REAPER window intersects boxes ---
  -- [[-----------------------------------------------------------------  
  local targetedNotes = 0       -- how many notes are targeted
  for n = targetedNotes, 1, -1  do        -- for each targeted note, in reverse order
    if sNoteDrawTable[n] then           -- if not nil
      for w = 1, #dimensions do           -- for each open REAPER window
        if dimensions[w]~= nil then       -- if not nil
          if sNoteDrawTable[n][1] > dimensions[w][1] and sNoteDrawTable[n][2] < dimensions[w][2]        -- if NS    > left | right > NE
          or sNoteDrawTable[n][1] < dimensions[w][2] and sNoteDrawTable[n][2] > dimensions[w][2]        -- if right > NS   | NE    > right
          or sNoteDrawTable[n][2] < dimensions[w][1] and sNoteDrawTable[n][2] > dimensions[w][2]        -- if left  > NE   | NE    > right 
          or sNoteDrawTable[n][2] > dimensions[w][1] and sNoteDrawTable[n][1] < dimensions[w][1] then   -- if NE    > left | left  > NS
            if sNoteDrawTable[n][3] > dimensions[w][3]-50 and sNoteDrawTable[n][3] < dimensions[w][4] and sNoteDrawTable[n][4] > dimensions[w][4] then -- if nTop below wintop and nBot above window bottom
              sNoteDrawTable[n][3] = dimensions[w][4]
            end
            if sNoteDrawTable[n][3] < dimensions[w][3]-50 and sNoteDrawTable[n][4] < dimensions[w][4] and sNoteDrawTable[n][4] > dimensions[w][3] then -- if nTop is above wintop and nBot is above window bottom
              sNoteDrawTable[n][4] = dimensions[w][3]-50
            end
          end
        end
      end
    end
  end
  

  ---]]-------------------------------------------
  --  draw rectangles around selected/hovered notes, and draw increment size indicator
  -- [[-----------------------------------------------------------------  
  local zoom_lvl = reaper.GetHZoomLevel()
  local incr
  if reaper.HasExtState(extName, 7) then
    incr = tostring(reaper.GetExtState(extName, 7))
  end
  
  local alpha = 0
  if dbg == 1 then alpha = .25 end
  --reaper.ImGui_SetNextWindowBgAlpha(ctx, alpha)
  _, _ = ImGui.Begin(ctx, 'Overlay', nil, -- open a new invisible ReaImGUI window that can't be touched, moved
  ImGui.WindowFlags_NoBackground |
  ImGui.WindowFlags_NoDecoration |
  ImGui.WindowFlags_NoMove |
  ImGui.WindowFlags_NoFocusOnAppearing |
  ImGui.WindowFlags_NoInputs)
  
  if not ImGui.ValidatePtr(splitter, 'ImGui_DrawListSplitter*') then
    splitter = ImGui.CreateDrawListSplitter(draw_list)
  end
  ImGui.DrawListSplitter_Split(splitter, 2)
  
  if mouseNoteTable[1] then                         -- if there are notes under the mouse
    local boxTake = 0
    if track then                                   -- if there is a track
      local CountTrItem = reaper.CountTrackMediaItems(track)  
      if CountTrItem then                           -- if track has items
        for i = 0, CountTrItem-1 do                 -- for each item, first to last           
          local item = reaper.GetTrackMediaItem(track,i)  -- get each item start and endpoints
          local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
          local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
          if itemStart <= cursorPos and itemEnd > cursorPos then  -- if edit cursor is within item bounds,
            local take = reaper.GetTake(item, 0)                  -- get the take
            if reaper.TakeIsMIDI(take) then boxTake = take end    -- assign boxTake to current take
          end
        end
      end
    end -- if there is a track
    
    if boxTake ~= 0 then    -- if there is a take under the mouse            
      local sx, sy = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, trPos )        -- get x/y position of notestart and track
      noteTcpHeight = reaper.GetMediaTrackInfo_Value(track, 'I_TCPH')
      local _, syHeight = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel, trPos+noteTcpHeight)   -- get y position of track
      sx, sy = ImGui.PointConvertNative(ctx, sx, sy, false)                                         -- update x/y values to imgui native
      _, syHeight = ImGui.PointConvertNative(ctx, sx, syHeight, false)                              -- update syHeight to imgui native
      local startTime, _ = reaper.GetSet_ArrangeView2( 0, 0, 0, 0)  -- get arrangescreen pos
      local notePpq = reaper.MIDI_GetPPQPosFromProjTime(boxTake, targetNotePos)                     -- ppq of targetnotepos
      local noteIncrPos = reaper.MIDI_GetProjTimeFromPPQPos(boxTake, notePpq + incr)                -- time pos of note ppq + incr
      local noteIncrPixel = math.floor((noteIncrPos - startTime) * zoom_lvl)                       -- pixel pos of note+incr time
      local sxEnd, val = reaper.JS_Window_ClientToScreen(track_window, noteIncrPixel, trPos )      -- x/y pos of pixel and track
      sxEnd, _ = ImGui.PointConvertNative(ctx, sxEnd, val, false)                                   -- update x to imgui native
      local mouseNoteColor = 0xFF0000 .. 255                                                        -- red box for hovered note under mouse
      ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)                                         -- set background
      ImGui.DrawList_AddRect(draw_list, mouseNoteTable[1], mouseNoteTable[3], mouseNoteTable[2]+2, mouseNoteTable[4], mouseNoteColor, 0) -- draw the outline
      ImGui.DrawListSplitter_SetCurrentChannel(splitter, 1)                                         -- set foreground
      if startTime < targetNotePos then 
        ImGui.DrawList_AddRectFilled(draw_list, sx+1, syHeight-5, sxEnd+2, syHeight-0, 0xFFFFFFFF, 0) -- draw INCR indicator
      end
    end
  end

  if sNoteDrawTable then
    for n = selectedNotes, 1, -1  do          -- for each selected note, in reverse order
      if sNoteDrawTable[n] then               -- if not nil
        sNoteDrawTable[n][7] = 0xFF0000FF     -- set outline color
        sNoteDrawTable[n][8] = 0xFF000000     -- set low end of taper color
        local alpha =  tostring(math.floor(59*(sNoteDrawTable[n][6])/127)+40)
        sNoteDrawTable[n][9] = "0xFF0000" .. alpha     -- set high end of taper color
        if sNoteDrawTable[n][9] == "0xFF0000" then sNoteDrawTable[n][9] = 0xFF000000 end
        ImGui.DrawListSplitter_SetCurrentChannel(splitter, 0) -- set background
        ImGui.DrawList_AddRect(draw_list, sNoteDrawTable[n][1], sNoteDrawTable[n][3], sNoteDrawTable[n][2]+2, sNoteDrawTable[n][4], 0x00FF45FF, 0) -- draw the outline
        --ImGui.DrawList_AddRectFilledMultiColor(draw_list, sNoteDrawTable[n][1], sNoteDrawTable[n][3], sNoteDrawTable[n][2]+1, sNoteDrawTable[n][4], sNoteDrawTable[n][8], sNoteDrawTable[n][7], sNoteDrawTable[n][7], sNoteDrawTable[n][8])
        -- last 4: upper left, upper right, bottom left, bottom right
        ImGui.DrawList_AddRectFilledMultiColor(draw_list, sNoteDrawTable[n][1], sNoteDrawTable[n][3], sNoteDrawTable[n][2]+1, sNoteDrawTable[n][4], sNoteDrawTable[n][9], sNoteDrawTable[n][8], sNoteDrawTable[n][8], sNoteDrawTable[n][9])
      end  -- if not nil
    end  -- for each selected note 
  end

  ImGui.DrawListSplitter_Merge(splitter)
  ImGui.End(ctx)
  ImGui.PushFont(ctx, font, 12)


  --]]------------------------------------------------------------------
  --------------------DEBUG HELPER -------------
  -- [[-----------------------------------------------------------------   
  if dbg == 1 then  
    _, _ = ImGui.Begin(ctx, 'Fiddler Debug', nil,  -- open a new invisible ReaImGUI window that can't be touched, moved
    ImGui.WindowFlags_AlwaysAutoResize |
    ImGui.WindowFlags_TopMost |
    reaper.ImGui_WindowFlags_NoCollapse() |
    ImGui.WindowFlags_NoFocusOnAppearing)
    ImGui.TextColored(ctx, 0xFFFFFFFF, "-------------------------------")
    --ImGui.TextColored(ctx, 0xFFFFFFFF, getCursorInfoCount .. " calls since idle")
    --ImGui.TextColored(ctx, 0xFFFFFFFF, getNoteCallCount .. " getnotes per call")
    
    if cursorPixel then ImGui.TextColored(ctx, 0xFFFFFFFF, "cursorPixel: " .. cursorPixel) end
    if cursorPos then ImGui.TextColored(ctx, 0xFFFFFFFF, "cursorPos: " .. cursorPos) end
    if trPos then ImGui.TextColored(ctx, 0xFFFFFFFF, "trPos: " .. trPos)
    else ImGui.TextColored(ctx, 0xFFFFFFFF, "trPos: nil") end
    
    if targetNotePixel then ImGui.TextColored(ctx, 0xFFFFFFFF, "targetNotePixel: " .. targetNotePixel) end
    if targetPitch then ImGui.TextColored(ctx, 0xFFFFFFFF, "targetPitch: " .. targetPitch )
    else ImGui.TextColored(ctx, 0xFFFFFFFF, "targetPitch: nil") end
    
    if targetNoteIndex then ImGui.TextColored(ctx, 0xFFFFFFFF, "targetNoteIndex: " .. targetNoteIndex )
    else ImGui.TextColored(ctx, 0xFFFFFFFF, "targetNoteIndex: nil")end
    
    if showNotes ~= nil then
      for n = 1, #showNotes, 1 do
        ImGui.TextColored(ctx, 0xFFFFFFFF, " " )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "--showNotes---------------" )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "showNotes: " .. n)
        ImGui.TextColored(ctx, 0xFFFFFFFF, "pitch: " .. showNotes[n][1] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "velocity: " .. showNotes[n][2] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "targetnotepixel: " .. showNotes[n][3] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "channel: " .. showNotes[n][4] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "index: " .. showNotes[n][5] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "mute: " .. showNotes[n][6] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "position: " .. showNotes[n][7] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "track: " .. showNotes[n][8] )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "selected: " .. showNotes[n][9] )
      end
    end
    
    if sNoteDrawTable ~= nil then
      for n = 1, #sNoteDrawTable, 1 do
        ImGui.TextColored(ctx, 0xFFFFFFFF, " " )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "--sNoteDrawTable---------------" )
        ImGui.TextColored(ctx, 0xFFFFFFFF, "drawtable: " .. n)
        ImGui.TextColored(ctx, 0xFFFFFFFF, "x1: " .. sNoteDrawTable[n][1] .. " x2: " .. sNoteDrawTable[n][2])
        ImGui.TextColored(ctx, 0xFFFFFFFF, "y1: " .. sNoteDrawTable[n][3] .. " y2: " .. sNoteDrawTable[n][4])
        --ImGui.TextColored(ctx, 0xFFFFFFFF, "mute: " .. sNoteDrawTable[n][5])
        ImGui.TextColored(ctx, 0xFFFFFFFF, "vel: " .. sNoteDrawTable[n][6])
        ImGui.TextColored(ctx, 0xFFFFFFFF, sNoteDrawTable[n][7])
        ImGui.TextColored(ctx, 0xFFFFFFFF, sNoteDrawTable[n][8])
        ImGui.TextColored(ctx, 0xFFFFFFFF, "color: " .. sNoteDrawTable[n][9])
        ImGui.TextColored(ctx, 0xFFFFFFFF, "-------------------------------")
      end
    end
    ImGui.End(ctx)
  end
  
  
  
  --]]------------------------------------------------------------------
  -------------------interface-------------
  --[[-----------------------------------------------------------------   
  knob = 1
  if knob == 1 then  
    _, _ = ImGui.Begin(ctx, 'slider', nil,  -- open a new invisible ReaImGUI window that can't be touched, moved
    ImGui.WindowFlags_AlwaysAutoResize |
    ImGui.WindowFlags_TopMost |
    --ImGui.WindowFlags_NoBackground |
    ImGui.WindowFlags_NoDecoration |
    ImGui.WindowFlags_NoFocusOnAppearing)
    --ImGui.TextColored(ctx, 0xFFFFFFFF, "-------------------------------")
    
    --_, v = reaper.ImGui_SliderInt(ctx, "##slider", v, 0, 127, v)
    reaper.ImGui_SetNextItemWidth(ctx, 50)
    _, e = reaper.ImGui_InputInt(ctx, "##input", e, 0)
    if reaper.ImGui_IsKeyPressed(ctx, 525, 0) then
      e = 0
    end
    
    --end
      
    
    ImGui.End(ctx)
  end
  

  --]]------------------------------------------------------------------
  ---------------- Mouse Position / Incoming Note display -------------
  -- [[-----------------------------------------------------------------
  if cursorPos then cursorPixel = math.floor((cursorPos - startTime) * zoom_lvl) end  -- get pixel position of cursor
  if info == "arrange" and reaper.GetPlayState() ~= 5 and mouseTake and mouseTrPos and cursorPos and elapsed > 0 then  
    local color
    local posX, posY
    local mouseStepEditPos
    mouseStepEditPos = cursorPos                  -- display ppq pos = mouseppqpos
    
    if input == 1 then                            -- red if input, grey else
      color = 0xFF0000FF 
      mouseStepEditPos = editCurPos                                       
      local editCurPix = math.floor((editCurPos - startTime) * zoom_lvl)
      posX, posY = reaper.JS_Window_ClientToScreen( track_window, editCurPix, mouseTrPos-42)
    else 
      color = 0xFFFFFFFF 
      posX, posY = reaper.JS_Window_ClientToScreen( track_window, cursorPixel, mouseTrPos-42)
    end   
    
    posX, posY = ImGui.PointConvertNative(ctx, posX, posY, false)
    ImGui.SetNextWindowPos(ctx, posX, posY)   -- readout appears at positions determined above
    
    local bpi                                                             -- get time position
    if startMarkerPos ~= -1 and mouseStepEditPos >= startMarkerPos then   -- if after "start" marker
      local ptidx = reaper.CountTempoTimeSigMarkers(proj)
      if ptidx == 0 then 
        _, bpi = reaper.GetProjectTimeSignature2(proj)
      elseif ptidx ~= 0 then 
        lastTempoMarker = reaper.FindTempoTimeSigMarker(proj , mouseStepEditPos)
        _, _, _, _, _, bpi, _, _ = reaper.GetTempoTimeSigMarker(proj, lastTempoMarker)
        if bpi == -1 then bpi = 4 end                                     -- bpi sanitizer
      end
      
      local cursorQN = reaper.TimeMap_timeToQN(mouseStepEditPos)   -- math preparing time display
      cursorQN = cursorQN - firstMarkerQN                     
      local _, remainder = math.modf(cursorQN)                    
      local cursorMeasure = (math.floor(cursorQN / bpi )) + 1
      local cursorPosReadout = math.floor((remainder * 960) + .5)
    
      if cursorPosReadout == 960 then                              -- math preparing time display
        cursorMeasure = cursorMeasure + 1
        cursorPosReadout = 0 
      end
      
      while cursorQN > bpi do cursorQN = cursorQN - bpi end        -- math, text preparing time display
      cursorQN = math.floor((cursorQN + 1) +.000005)
      if cursorQN > bpi then cursorQN = 1 end
      local stringCursorPPQ = tostring(cursorPosReadout)
      while string.len(stringCursorPPQ) < 3 do stringCursorPPQ = "0" .. stringCursorPPQ end 
      local cursorPosString = ""
      cursorPosString = cursorMeasure .. "." .. cursorQN .. "." .. stringCursorPPQ
      local noteInfo = ""

      if lastNote ~= -1 and noteTimer then
        local octave = math.floor(lastNote/12)-1                               -- establish the octave for readout
        local cursorNoteSymbol = pitchList[(lastNote - 12*(octave+1)+1)]       -- establish the note symbol for readout
        local nowPPQ = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, reaper.time_precise())
        local thenPPQ = reaper.MIDI_GetPPQPosFromProjTime(mouseTake, noteTimer)
        noteInfo = " n: " .. lastNote .. " (" .. cursorNoteSymbol .. octave ..  ") v: " .. lastVel .. " d: " .. math.floor(nowPPQ - thenPPQ)
      end
      
      if inputNote and inputNote ~= -1 and reaper.time_precise()-noteOffTimer < 1.75 then
        local octave = math.floor(inputNote/12)-1                               -- establish the octave for readout
        local cursorNoteSymbol = pitchList[(inputNote - 12*(octave+1)+1)]       -- establish the note symbol for readout
        if not lastVel then lastVel = "" end
        if not inputNote then inputNote = "" end
        noteInfo = " n: " .. inputNote .. " (" .. cursorNoteSymbol .. octave ..  ") v: " .. lastVel         
      end
      
      local displayString = cursorPosString .. noteInfo     -- prepare displaystring for mouse position readout
      if ImGui.Begin(ctx, 'cursorPos', false,
        ImGui.WindowFlags_NoFocusOnAppearing |
        ImGui.WindowFlags_NoDecoration |
        ImGui.WindowFlags_NoInputs |
        ImGui.WindowFlags_NoInputs |
        ImGui.WindowFlags_AlwaysAutoResize) then
        ImGui.TextColored(ctx, color, displayString)
      end
      ImGui.End(ctx)
    end
  end
 
  --]]------------------------------------------------------------------
  ----------------Step Edit Display ------------------------------------
  -- [[-----------------------------------------------------------------
  local alpha = 0
  if info == "arrange" and take and elapsed > 0 and showNotes then
    local stepTime = reaper.time_precise() 
    local sx, sy
    if targetPitch and trPos then             -- if there's a note and track under cursor
      sx, sy = reaper.JS_Window_ClientToScreen(track_window, targetNotePixel-60, trPos+tcpHeight) 
    end
    
    if targetPitch then
      sx, sy = ImGui.PointConvertNative(ctx, sx, sy, false)
      ImGui.SetNextWindowPos(ctx, sx, sy)   -- readout appears at note x position
      --reaper.ImGui_SetNextWindowBgAlpha(ctx, alpha)
      ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x00000000 | 0xFF)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 0)
      if ImGui.Begin(ctx, 'Tooltip', false,
        ImGui.WindowFlags_NoFocusOnAppearing |
        ImGui.WindowFlags_NoDecoration |
        ImGui.WindowFlags_NoInputs |
        ImGui.WindowFlags_TopMost |
        ImGui.WindowFlags_AlwaysAutoResize) then
        local spacingO = " "
        local spacingN = ""
        local spacingV = ""
        local spacingD = ""
        local spacingCH = " "
        local postNote = "  "
        local posStringSize = {}
        
        for i = 1, #showNotes do
          posStringSize[i] = string.len(showNotes[i][7])
        end
        table.sort(posStringSize)
        
        for i = #showNotes, 1, -1 do                    -- for each top-level entry in the showNotes table,
          if showNotes[1] and targetPitch then
            if showNotes[i][7] == "" then 
              for j = 1, posStringSize[#posStringSize] do 
                showNotes[i][7] = " " .. showNotes[i][7]
              end
            end
            
            local octave = math.floor(showNotes[i][1]/12)-1                               -- establish the octave for readout
            local cursorNoteSymbol = pitchList[(showNotes[i][1] - 12*(octave+1)+1)]       -- establish the note symbol for readout
       
            if     showNotes[i][1] > -1  and showNotes[i][1] <  10 then spacingN = "  "     -- spacingN for the note readout
            elseif showNotes[i][1] > 9   and showNotes[i][1] < 100 then spacingN = " " 
            elseif showNotes[i][1] > 99                            then spacingN = "" 
            end
             
            if octave < 0 then spacingO = "" postNote = postNote:gsub(' ', '') end  -- spacing for octave readout 
            if showNotes[i][4] ~= "in" then                                         -- spacingCH for channel readout
              if showNotes[i][4] < 10 then spacingCH = "  " else spacingCH = " " end
            else spacingCH = " " end
            
            if     showNotes[i][2] > 0  and showNotes[i][2] <  10 then spacingV = "  "         -- spacingV for the velocity readout
            elseif showNotes[i][2] > 9  and showNotes[i][2] < 100 then spacingV = " " 
            elseif showNotes[i][2] > 99                           then spacingV = "" 
            end
   
            if type(showNotes[i][3]) == "number" then
              if     showNotes[i][3] > 0    and showNotes[i][3] <    10 then spacingD = "    "   -- spacing for the duration readout
              elseif showNotes[i][3] > 9    and showNotes[i][3] <   100 then spacingD = "   " 
              elseif showNotes[i][3] > 99   and showNotes[i][3] <  1000 then spacingD = "  " 
              elseif showNotes[i][3] > 999  and showNotes[i][3] < 10000 then spacingD = " " 
              elseif showNotes[i][3] > 9999                             then spacingD = ""
              end
            end
             
            if showNotes[i][6] == "true" then color = 0x7a7a7aFF   -- muted
            elseif showNotes[i][9] == "true" then color = 0x00FF45FF       -- selected
            elseif showNotes[i][1] == targetPitch then color = 0xFFFFFFFF  -- targeted
            else color = 0xadadadFF           -- white for non-target note readouts
            end
            
            table.sort(showNotes, function(a, b) return a[1] < b[1] end)
            if i - 1 and showNotes[i] ~= showNotes[i + 1] then
            ImGui.TextColored(ctx, color, showNotes[i][7] .. "n:" .. spacingN .. showNotes[i][1] .. 
              spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " ..
              "ch:" .. spacingCH .. showNotes[i][4] ..   "  v: " .. spacingV .. showNotes[i][2] .. 
              "  d: " .. spacingD .. showNotes[i][3] .. "  " ..  showNotes[i][8])
            end
          end
        end                                               -- for each shown note
        ImGui.End(ctx)
      end                                                 -- if imgui begin
    ImGui.PopStyleColor(ctx)
    ImGui.PopStyleVar(ctx)
    end
  end         
  ImGui.PopFont(ctx)
  reaper.defer(loop)
  editCurPosLast = reaper.GetCursorPosition()
end -- end Fiddler loop

-------------------------------------------
--local function Clean()
--end
-------------------------------------------

  
-- [[-----------------------------------------------------------------
---------------- build note table for selected notes   -------------------------------  
-- [[-----------------------------------------------------------------  
function buildNoteTable(selectedNoteTrack)  
  local zoom_lvl = reaper.GetHZoomLevel()
  local startTime, endTime = reaper.GetSet_ArrangeView2( 0, 0, 0, 0)  -- get arrangescreen pos
  local selNotePixelTable = {}
  if selectedNoteTrack then        -- if there is at least one track selected
    local CountTrItem = reaper.CountTrackMediaItems(selectedNoteTrack)
    if CountTrItem then            -- if track has items
      local noteTrPos = reaper.GetMediaTrackInfo_Value( selectedNoteTrack, 'I_TCPY' ) -- y pos of track TCP
      local negative = 0           -- get value above ruler
      if noteTrPos < 1 then        -- if tr is above ruler
        negative = noteTrPos       -- store neg value for height
        noteTrPos = 1              -- set min position
      end
      noteTcpHeight = reaper.GetMediaTrackInfo_Value( selectedNoteTrack, 'I_TCPH')
      noteTcpHeight = noteTcpHeight + negative              -- sum height to keep below ruler
      if noteTcpHeight < 1 then noteTcpHeight = 1 end       -- ^^
      local arrangeSize = (endTime - startTime) * zoom_lvl  -- pixel size of arrange view
      selectedNotes = 0           
      
      for i = 0, CountTrItem - 1 do                         -- for each item,               
        local item = reaper.GetTrackMediaItem(selectedNoteTrack, i) -- get each item
        local take = reaper.GetTake( item, 0 )              -- get the take
        
        if take and reaper.TakeIsMIDI(take) then            -- if take and if midi
          local notesCount, _, _ = reaper.MIDI_CountEvts(take)  -- count notes in current take                    
          local _, notesCount = reaper.MIDI_CountEvts(take)  -- notes counted in take
          local i = -1                  -- in order to assess selection status of idx 0
          while i < notesCount-1 do     -- 
            local nextSel = reaper.MIDI_EnumSelNotes(take, i)  -- get idx of next selected note
            if nextSel ~= -1 then       -- if there is a next selected note
              selectedNotes = selectedNotes+1 
              i = nextSel               -- set i to next selected note idx 
              local _, _, _, startppq, endppq, _, _, vel = reaper.MIDI_GetNote(take, i)  -- get note data             
              noteStartPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)        -- note pos of note under cursor
              local noteEndPos   = reaper.MIDI_GetProjTimeFromPPQPos(take, endppq)    -- note pos of note under cursor
              targetNotePixel    = math.floor((noteStartPos -  startTime) * zoom_lvl) -- note start pixel
              targetNotePixelEnd = math.floor((noteEndPos   -  startTime) * zoom_lvl) -- note end pixel
              if targetNotePixel    < 0    then targetNotePixel    = 0    end         -- set bounds for target note start
              if targetNotePixelEnd < 0    then targetNotePixelEnd = 0    end         -- set bounds for target note end
              if targetNotePixel    > arrangeSize then targetNotePixel    = arrangeSize end    
              if targetNotePixelEnd > arrangeSize then targetNotePixelEnd = arrangeSize end 
              targetNotePixel    = math.floor(targetNotePixel)
              targetNotePixelEnd = math.floor(targetNotePixelEnd)
              if targetNotePixel and noteTrPos then       -- if track and target, build a table of notes to print
                local sx, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel, noteTrPos  )
                sx, sy = ImGui.PointConvertNative(ctx, sx, sy, false)   -- convert to native imgui 
                local sxEnd, syHeight = reaper.JS_Window_ClientToScreen( track_window, targetNotePixelEnd, noteTrPos+noteTcpHeight)
                sxEnd, syHeight = ImGui.PointConvertNative(ctx, sxEnd, syHeight, false)
                if sy < 1 then sy = 1 end 
                selNotePixelTable[selectedNotes] = {sx, sxEnd, sy, syHeight, muteState, vel}
              end -- if on track/with target
            else -- if no next selected note
              break -- quit
            end -- if next selected notes
          end -- while notes
        end -- if take not nil, if take midi
      end -- for each item
    end -- if track has items
  end -- if track
  return selNotePixelTable
end -- end function


--]]------------------------------------------------------------------
----------------idle sensor ------------------------------------
-- [[-----------------------------------------------------------------
local getCursorInfoCount
function idleSensor()
  if idleTask == 1 then
    local undo
    while idleCount > 100 do
      getCursorInfoCount = 0
      if idleCount > 101 then break end                 -- just do it once
      for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0,i-1)
        local item_num = reaper.CountTrackMediaItems(tr)
        for j = 0, item_num-1 do
          local itm = reaper.GetTrackMediaItem(tr, j)
          for t = 0, reaper.CountTakes(itm)-1 do        -- for each take,
            local tk = reaper.GetTake(itm, t)           -- get take
            if tk and reaper.TakeIsMIDI(tk) then        -- if it's MIDI, get RE PPQ values
              local _, ccCount, _ = reaper.MIDI_CountEvts(tk) -- count notes in current take 
              for n = 0, ccCount do
                local _, _, _, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC( tk, n )
                if chan == 15 and msg2 == 119 and msg3 == 1 then 
                  reaper.MIDI_DeleteCC( tk, n )
                  undo = 1
                end
              end
            end
          end
        end
      end -- end cc cleanup
      if undo == 1 then 
        reaper.Undo_OnStateChange2(proj, "idle cleanup" ) 
      end    
      break
    end
  end 
end

---]]-----------------------------------------
function main()
  --reaper.defer(function() xpcall(Main, Clean) end)
  reaper.defer(loop)
end
-----------------------------------------------
function SetButtonON()
  reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
  reaper.RefreshToolbar2( sec, cmd )
  main()
end
-----------------------------------------------
function SetButtonOFF()
  --Clean()
  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  reaper.RefreshToolbar2( sec, cmd ) 
end
-----------------------------------------------
_, _, sec, cmd = reaper.get_action_context()
SetButtonON()
reaper.atexit(SetButtonOFF)

--profiler.attachToWorld() -- after all functions have been defined
--profiler.run()

