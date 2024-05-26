--[[
 * ReaScript Name: Fiddler (arrange screen MIDI editing).lua
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.97
 * Provides: Modules/*.lua
--]]

--[[
 * Changelog: 
 * v1.97 (2024-5-26)
   + cleanup, comments
   + fixed transposing multiple notes (would lose target indicators)
 * v1.96 (2024-5-26)
   + fixed targeted Note indicators being displayed on track under mouse cursor
   + various fixes
   + prevent ReaImGUI indicators from being drawn over REAPER windows
   + fixed flicker if mouseover note data readout window
   + performance upgrades
 * v1.95 (2024-5-24)
   + replaced LICE drawings with ReaImGui
 * v1.94 (2024-5-23)
   + updated dependency
 * v1.93 (2024-5-23)
   + commented out stray debug messages
 * v1.92 (2024-5-22)
   + fixed poorly linked dependency to Razor Edit Control Functions, should now be contained in Razor Edit Functions module
--]]
 
-- discussion thread: https://forum.cockos.com/showthread.php?t=274257 

-- HOW TO USE:
-- run this defer script, then mouse over MIDI in your arrange screen.
-- guidelines and a readout will appear, targeting the MIDI under your mouse.
-- "mccrabney_Fiddler - toggle target-hold note.lua" will create an RE and target notes within
-- use the other Fiddler scripts to edit MIDI from the arrange screen.

-- special thanks to Sexan, cfillion, Meo-Ada-Mespotine, BirdBird, and many others for code/help.

---------------------------------------------------------------------
-- Requires js_ReaScriptAPI extension: https://forum.cockos.com/showthread.php?t=212174

idleTask = 1     -- run idle task or not
cursorSource = 1 -- initialize cursorSource to Mouse, if not already set
reaper.ClearConsole()

--package.path = reaper.GetResourcePath() .. '/Scripts/sockmonkey72 Scripts/MIDI/?.lua'
--local mu = require 'MIDIUtils'
--dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'

if reaper.HasExtState(extName, 8) then            -- get the cursorsource, if previously set
  cursorSource = tonumber(reaper.GetExtState(extName, 8 ))
end

resetCursor = 100  -- how many loopCounts should pass before cursor is reset from Edit to Mouse
                   -- this resets cursor to mouse when idle
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")   -- GET DIRECTORY FOR REQUIRE  -- AREA MOUSE INPUT HANDLING
require("Modules/mccrabney_Razor_Edit_functions")
require("Modules/mccrabney_MIDI_Under_Mouse")
require("Modules/mccrabney_misc")
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}

local main_wnd = reaper.GetMainHwnd()                                -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local ctx = ImGui.CreateContext('MIDI Note Overlay', ImGui.ConfigFlags_NoSavedSettings)

local sans_serif = reaper.ImGui_CreateFont('sans-serif', 13)
reaper.ImGui_Attach(ctx, sans_serif)

if not reaper.APIExists("JS_ReaScriptAPI_Version") then    -- js api check --------------
  reaper.MB( "JS_ReaScriptAPI is required for this script", "Please download it from ReaPack", 0 )
  return reaper.defer(function() end)
 else
  local version = reaper.JS_ReaScriptAPI_Version()
  if version < 1.002 then
    reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
    return reaper.defer(function() end)
  end
end

--]]-----------------------------------------------------------------------------------------
------------LOOP-----------------------------------------------------------------
-- [[-----------------------------------------------------------------
loopCount = 0
idleCount = 0
pop = 0 
elapsed = 0
reset = 0
arrangeTime = 0

lastArrangeTime = 0
editCurPosLast = -1
lastX = 0
lastRE = 0
toggleNoteHold = 0                              -- set notehold off by default
noteHoldNumber = -1                             -- default notehold number to an inapplicable value
mediaAreas = {} 
targetTable = {} 
multiple = 0
targetedNotes = 0  

    --[[------------------------------[[--
          loop and show tooltips, cursor as necessary  
    --]]------------------------------]]--
function loop()
  
  local reaper_vp = ImGui.GetMainViewport(ctx)
  ImGui.SetNextWindowPos(ctx, ImGui.Viewport_GetPos(reaper_vp))
  ImGui.SetNextWindowSize(ctx, ImGui.Viewport_GetSize(reaper_vp))
  loopCount = loopCount+1                                       -- advance loopcount
  idleCount = idleCount+1                                       -- advance idlecount
  editCurPos = reaper.GetCursorPosition()
  local lastMIDI = {}                                          
                                                                -- optimizer to reduce calls to getCursorInfo
  if loopCount >= 3 and info == "arrange" and lastX ~= x and pop == 0  -- if we're in the right place, and on the move
  or editCurPos ~= editCurPosLast then                                 -- or if the edit cursor has moved,
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos, _, numNotes = getCursorInfo() 
    if take ~= nil and reaper.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      idleCount = 0                                             -- reset idlecount
      lastX = x                                                 -- set lastX mouse position
    else lastX = x end
  end    

  extStates()                                                   -- communicate with other scripts
  idleSensor()                                                  -- sense if no mouse movement for a short period
  
  ---------------------------------------------------  get last note hit and feed it into table 
  
  if loopCount < 500 then lastNote, lastVel = getLastNoteHit() end   -- if idle, stop getting lastnotehit                                                        
  x, y = reaper.GetMousePosition()                              -- mousepos
  _, info = reaper.GetThingFromPoint( x, y )                    -- mousedetails
  local skip = 0       
  
  if lastNote == -1 then pop = 0 end                            -- reset pop value (pop = incoming MIDI)
  if lastNote ~= -1 and lastNote ~= nil and take ~= nil and pop == 0 then
    pop = 1                                                     -- MIDI is being received
    local currentVel                                            -- package the pitch/vel info
  
    for i = 1, #showNotes do                                    -- check each note to see if it is already present
      if lastNote == showNotes[i][1] then 
        currentVel = showNotes[i][2]
        skip = 1                                                -- if yes, skip it
      end  
    end    
    
    if skip ~= 1 and toggleNoteHold == 0 then                   -- if incoming note is not present in table,
      lastMIDI[1] = {lastNote, lastVel, 0, 0} 
      table.insert(showNotes, 1, lastMIDI[1])                   -- insert it
      showNotes[1][7] = ""                                      -- blank n/a text readout values
      _, sourceTrName = reaper.GetTrackName( track )            -- get the name of the track where the note originates
      if sourceTrName == "sequencer" then                       -- if it's from a sequencer, 
        local trName = getInstanceTrackName(lastNote)           -- detect trackname of RS5K instance
        trName = "'" .. trName .. "'"                           -- pad with quote
      end
      if trName == nil then trName = "" end                     -- if nil, write empty
      showNotes[1][8] = trName                                  -- put into table
    end    
  
    octaveNote = math.floor(lastNote/12)-1                      -- get symbols for last-received MIDI
    noteSymbol = (lastNote - 12*(octaveNote+1)+1) 
    lastX = -1                                                  -- reset optimzer to update display
  end
  
  -------------------------------------------------------------------------------------------------
  ------------------------------GUI ---------------------------------------------------------------
  
  startTime, endTime = reaper.GetSet_ArrangeView2( 0, 0, 0, 0)      -- get arrangescreen pos
  arrangeTime = startTime + endTime                                 -- sum values to determine change
  noteTable = {}
  dimensions = {}
  local retval, windowList = reaper.JS_Window_ListAllTop()
  local draw_list = ImGui.GetWindowDrawList(ctx)  
  
  if arrangeTime ~= lastArrangeTime then            -- if arrange screen bounds have moved
    elapsed = 0                                     -- timer == 0
    reset = 1
    time_start = reaper.time_precise()              -- start the clock
  else                                              -- if arrange screen bounds haven't changed,
    elapsed = reaper.time_precise() - time_start    -- set elapsed time since arrange hasn't moved
  end
  lastArrangeTime = arrangeTime                     -- get last arrangetime value
  
  if cursorSource == 1 then                         -- set cursor colors
    outlineColor = 0xFF0000FF
    curColor     = 0xFF000031
    curColor2    = 0xFF000060
  else
    outlineColor = 0x0040FFFF
    curColor2    = 0x0040FF31
    curColor     = 0x0040FF91
  end   

  --]]--------------------------------  ----------------------------------
  ----------------multiple target notes in RE --------------------------  
  -- [[-----------------------------------------------------------------
  
  local areas
  local zoom_lvl = reaper.GetHZoomLevel()
  numMediaAreas = 0
  windows = 0
  
  if RazorEditSelectionExists() then
    lastRE = 1                             -- doOnce per RE draw/update
    local areas = GetRazorEdits()          -- get all areas 
    areaNum = #areas                       -- get number of areas
    
    for i = 1, #areas do                   -- for each razor edit area
      local areaData = areas[i]            -- get area data
      if not areaData.isEnvelope then      -- if it's not an envelope area
        numMediaAreas = numMediaAreas + 1  -- count non-envelope areas
        if i == 1 then start_pos = areaData.areaStart end   -- get the first area's start position
        mediaAreas[numMediaAreas] = areaData.areaEnd  -- get the last area's end position
      end                                  -- if it's not an envelope area
    end                                    -- for each area
    end_pos = mediaAreas[#mediaAreas]      -- get the last endpos in the media area table
    
    if mTrack ~= nil  then                 -- if we have a multiple-target track
      multiple = 1                         -- multiple flag
      mtcpHeight = reaper.GetMediaTrackInfo_Value( mTrack, "I_TCPH")  -- get track height
      mtrPos = reaper.GetMediaTrackInfo_Value( mTrack, 'I_TCPY' )     -- y pos of track TCP
      if noteHoldNumber == nil then noteHoldNumber = 128 end
      if lastNoteHoldNumber == nil then lastNoteHoldNumber = 128 end
      
      if noteHoldNumber ~= nil and noteHoldNumber ~= -1 and elapsed > 0 then
        if lastNoteHoldNumber ~= noteHoldNumber then
          debug("noteHoldNumber updated from " .. lastNoteHoldNumber .. " to " .. noteHoldNumber, 1)
          lastNoteHoldNumber = noteHoldNumber
          if trName ~= nil then targetTrack = trName end
          if tcpHeight ~= nil then targetHeight = tcpHeight end
        end 
          
        allAreas = start_pos + end_pos         -- get the full area span
        areaStartPixel = math.floor((start_pos - startTime) * zoom_lvl)   -- get the pixel for area start BM
        areaEndPixel   = math.floor((end_pos   - startTime) * zoom_lvl)   -- get the pixel for area end BM
        areaLengthPixel = areaEndPixel-areaStartPixel                     -- area length in pixels
        if mtcpHeight == nil then mtcpHeight = 0 end
        targetedNotes = 0  
            
        for i = 1, #areas do                               -- for each area
          local areaData = areas[i]                        -- get area data
          if not areaData.isEnvelope then                  -- if it's not an envelope area
            reStart = areaData.areaStart                   -- get local area start
            reEnd = areaData.areaEnd                       -- get local area end
            local items = areaData.items                   -- get local area items
            for j = 1, #items do                           -- for each area item, 
              local item = items[j]                        -- get item from array
              local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")  -- get item start, end
              local itemEnd = itemStart+ reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
              for t = 0, reaper.CountTakes(item)-1 do      -- for each take,
                if trName == targetTrack then 
                  targetTake = reaper.GetTake(item, t)     -- get take
                end
                  
                if reaper.TakeIsMIDI(targetTake) then      -- if it's MIDI, get RE PPQ values
                  razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(targetTake, reStart) 
                  razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(targetTake, reEnd) 
                  notesCount, _, _ = reaper.MIDI_CountEvts(targetTake) -- count notes in current take                    
                  for n = notesCount-1, 0, -1 do           -- for each note, from back to front
                    _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(targetTake, n)  -- get note data           
                    if startppq >= razorStart_ppq_pos and startppq < razorEnd_ppq_pos then  -- if in RE bounds
                      if noteHoldNumber == pitch then      -- if it's the targeted pitch
                        reaper.MIDI_SetNote( targetTake, n, 1, nil, nil, nil, nil, nil, nil)    -- set note selected
                        targetedNotes = targetedNotes + 1                                       -- add to targetedNtotes tally
                        noteStartPos = reaper.MIDI_GetProjTimeFromPPQPos(targetTake, startppq)  -- note pos of note under cursor
                        noteEndPos =   reaper.MIDI_GetProjTimeFromPPQPos(targetTake, endppq)    -- note pos of note under cursor
                        targetNotePixel    = math.floor((noteStartPos -  startTime) * zoom_lvl) -- note start pixel
                        targetNotePixelEnd = math.floor((noteEndPos   -  startTime) * zoom_lvl) -- note end pixel
                        if targetNotePixel    < 0 then targetNotePixel    = 0 end               -- set bounds for target note start
                        if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end               -- set bounds for target note end
                        pixelLength = targetNotePixelEnd-targetNotePixel                        -- pixel length of note
                      
                        if targetNotePixel ~= nil and trPos ~= nil then       -- if track and target, build a table of notes to print
                          sx,    sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel, mtrPos )
                          sxEnd,  _ = reaper.JS_Window_ClientToScreen( track_window, targetNotePixelEnd, mtrPos )
                          noteTable[targetedNotes] = {sx, sxEnd, sy, sy+targetHeight}
                        end  -- if on track/with target
                      end  -- if MIDI note is targeted                 
                    end  -- if MIDI note is within RE bounds
                  end -- for each note
                end -- if take is MIDI
              end -- for each take
            end -- for each item
          end -- if area isn't envelope
        end -- for each area
        
        if tcpHeight == nil then tcpHeight = 0 end    -- zero out tcpHeight
        if trPos == nil then trPos = 0 end            -- zero out trPos
        if noteHoldNumber ~= -1 then                  -- allow undo condition
          reaper.Undo_OnStateChange2(proj, "targeted note " .. noteHoldNumber)
        end
      else  -- if notehold is off
        multiple = 0
      end -- if notehold is on
    end -- if mTrack isn't nil
  end  -- if RE exists
  
  if not RazorEditSelectionExists() and lastRE == 1 then 
    --lastRE = 0
    debug("unlinked: mouseclick, or no RE", 1)
    noteHoldNumber = -1
    multiple = 0
  end
  
 ---]]-----------------------------------------------------------------
 ----------------single target note------------------------------------  
 -- [[----------------------------------------------------------------- 
  
  if targetPitch ~= nil and info == "arrange" and take ~= nil and noteHoldNumber == -1 and elapsed > 0 then 
    targetedNotes = 1
    if targetNotePos then                                   -- if there's a note pos to target,
      local zoom_lvl     = reaper.GetHZoomLevel()           -- get rpr zoom level
      targetNotePixel    = math.floor((targetNotePos - startTime) * zoom_lvl) -- get note start pixel
      targetNotePixelEnd = math.floor((targetEndPos  - startTime) * zoom_lvl) -- get note end pixel
      if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
      if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
      pixelLength = targetNotePixelEnd-targetNotePixel    -- get pixel length of note        
      if targetNotePixel ~= nil then
        local sx, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel, trPos )
        local sxEnd, _= reaper.JS_Window_ClientToScreen( track_window, targetNotePixelEnd, trPos )
        noteTable[1] = {sx, sxEnd, sy, sy+tcpHeight}
      end
    end
  end
  
  -----------------------------------------------
  --- get the dimensions of any open windows  ---
  
  for address in windowList:gmatch('[^,]+') do                -- cycle through the open REAPER window addresses
    local hwnd = reaper.JS_Window_HandleFromAddress(address)  -- get the windows, exclude non-REAPER windows
    if reaper.JS_Window_IsVisible(hwnd) and reaper.JS_Window_GetParent(hwnd) == reaper.GetMainHwnd() then
      hwndID = reaper.JS_Window_GetTitle( hwnd )              -- get their IDs, exclude irrelevant windows
      --debug("hwndID: " .. hwndID, 1)

      if hwndID ~= 'Overlay' and hwndID ~= 'Tooltip' and hwndID ~= 'ReaScript console output' then 
        if hwndID ~= nil then 
          windows = windows + 1                               -- count number of windows
          _, left, top, right, bottom = reaper.JS_Window_GetClientRect(hwnd) -- get their dimensions
          dimensions[windows] = { left, right, top, bottom }
        end  -- if hwndID isn't nil
      end  -- if not certain windows
    end  -- if visible, REAPER window
  end  -- for each window address
  
  --------------------------------------------------------
  --- remove overlap if REAPER window intersects boxes ---
  
  for n = targetedNotes, 1, -1  do        -- for each targeted note, in reverse order
    if noteTable[n] ~= nil then           -- if not nil
      for w = 1, #dimensions do           -- for each open REAPER window
        if dimensions[w]~= nil then       -- if not nil
          if noteTable[n][1] > dimensions[w][1] and noteTable[n][2] < dimensions[w][2]        -- if NS    > left | right > NE
          or noteTable[n][1] < dimensions[w][2] and noteTable[n][2] > dimensions[w][2]        -- if right > NS   | NE    > right
          or noteTable[n][2] < dimensions[w][1] and noteTable[n][2] > dimensions[w][2]        -- if left  > NE   | NE    > right 
          or noteTable[n][2] > dimensions[w][1] and noteTable[n][1] < dimensions[w][1] then   -- if NE    > left | left  > NS
            if noteTable[n][3] > dimensions[w][3]-50 and noteTable[n][3] < dimensions[w][4] and noteTable[n][4] > dimensions[w][4] then -- if nTop below wintop and nBot above window bottom
              noteTable[n][3] = dimensions[w][4]
            end
            if noteTable[n][3] < dimensions[w][3]-50 and noteTable[n][4] < dimensions[w][4] and noteTable[n][4] > dimensions[w][3] then -- if nTop is above wintop and nBot is above window bottom
              noteTable[n][4] = dimensions[w][3]-50
            end
          end
        end
      end
    end
  end
  
  -----------------------
  --- draw the boxes  ---
  
  if ImGui.Begin(ctx, 'Overlay', nil,                              -- open a new ReaImGUI window
    ImGui.WindowFlags_NoInputs | ImGui.WindowFlags_NoFocusOnAppearing | 
    ImGui.WindowFlags_NoDecoration |
    ImGui.WindowFlags_NoMove   | ImGui.WindowFlags_NoBackground) then
    for n = targetedNotes, 1, -1  do                                -- for each targeted note, in reverse order
      if noteTable[n] ~= nil then     -- if not nil
        ImGui.DrawList_AddRect(draw_list, noteTable[n][1], noteTable[n][3], noteTable[n][2]+2, noteTable[n][4], outlineColor, 0)
        if multiple == 1 then
          ImGui.DrawList_AddRectFilledMultiColor(draw_list, noteTable[n][1], noteTable[n][3], noteTable[n][2]+1, noteTable[n][4], curColor2, curColor, curColor2, curColor)
        else
          ImGui.DrawList_AddRectFilledMultiColor(draw_list, noteTable[n][1], noteTable[n][3], noteTable[n][2]+1, noteTable[n][4], curColor, curColor2, curColor, curColor2)
        end
      end  -- if not nil
    end  -- for each targeted note
  end  -- end ReaImGUI window
  ImGui.End(ctx)
     
  --]]------------------------------------------------------------------
  ----------------READOUT: ReaImGUI note data display ------------------
  -- [[-----------------------------------------------------------------
  
  if multiple == 0 and targetPitch ~= nil and info == "arrange" and take ~= nil and elapsed > .2 
  or multiple == 1 and targetPitch ~= nil and info == "arrange" and take ~= nil and mTrack == track then
    if multiple == 0 then                -- if single instance of target note is targeted:
      sx, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, trPos+tcpHeight) 
      reaper.ImGui_SetNextWindowPos(ctx, sx, sy)   -- readout appears at note x position
    else                                 -- if multiple instances of target note are targeted:
      _, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, mtrPos+mtcpHeight) 
      reaper.ImGui_SetNextWindowPos(ctx, x-100, sy)   -- readout follows mouse x position
    end
     
    local rounding                       -- round window for mouse cursor, square for edit
    if cursorSource == 1 then rounding = 12 else rounding = 0 end
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x00000000 | 0xFF)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), rounding)
    if reaper.ImGui_Begin(ctx, 'Tooltip', false,
    reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoDecoration() |
    reaper.ImGui_WindowFlags_NoInputs() |
    reaper.ImGui_WindowFlags_TopMost() |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      local octaveNote                                -- variables for readout
      local noteSymbol                                  
      local color = 0xFFFFFFFF                        -- offwhite for non-target note readouts
      local spacingO = " "
      local spacingN = ""
      local spacingV = ""
      local spacingD = ""
      local spacingCH = " "
      local postNote = "  "
      local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
      posStringSize, noteStringSize = {}
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
          
          octave = math.floor(showNotes[i][1]/12)-1                               -- establish the octave for readout
          cursorNoteSymbol = pitchList[(showNotes[i][1] - 12*(octave+1)+1)]       -- establish the note symbol for readout
     
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
           
          if showNotes[i][1] == targetPitch and showNotes[i][1] ~= lastNote then  -- color if entry matches the target note & no lastNote
            if cursorSource == 1 then color = 0xFF8383FF else color = 0xFFB1FFFF end
            increment = "-" .. reaper.GetExtState(extName, 7 )
          elseif showNotes[i][1] == lastNote and pop == 1 then      -- if note is received from controller
            notePresent = 1
            showNotes[i][2] = lastVel                               -- set incoming velocity
            showNotes[i][3] = ""                                    -- duration
            showNotes[i][4] = "in"
            increment = "" --incr[incrIndex] = ""
            color = 0x00FF45FF                            -- green for incoming
          elseif showNotes[i][1] ~= lastNote then 
            color = 0xFFFFFFFF                            -- white for non-target
            increment = ""
          end
           
          if showNotes[i][6] == "true" then color = 0x7a7a7aFF end
          table.sort(showNotes, function(a, b) return a[1] < b[1] end)
          if i - 1 ~= nil and showNotes[i] ~= showNotes[i + 1] then
          reaper.ImGui_TextColored(ctx, color, showNotes[i][7] .. "n:" .. spacingN .. showNotes[i][1] .. 
            spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  " ..
            "ch:" .. spacingCH .. showNotes[i][4] ..   "  v: " .. spacingV .. showNotes[i][2] .. 
            "  d: " .. spacingD .. showNotes[i][3] .. "  " ..  showNotes[i][8] .. "  " .. increment  )
          end
        end
      end                                               -- for each shown note
              
      if toggleNoteHold == 1 and noteHoldNumber ~= -1 then   -- if notehold is on 
        local trName = getInstanceTrackName(noteHoldNumber)  -- get track name of target note
        trName = "'" .. trName .. "'"                        -- enquotate
        local togPad = ""
        for j = 1, posStringSize[#posStringSize] do togPad = " " .. togPad end
        octave = math.floor(noteHoldNumber/12)-1                    -- establish the octave for readout
        cursorNoteSymbol = pitchList[(noteHoldNumber - 12*(octave+1)+1)]       -- establish the note symbol for readout
        reaper.ImGui_TextColored(ctx, 0x00FF45FF, togPad .. "n: " .. noteHoldNumber ..spacingO .. "(" .. cursorNoteSymbol ..  octave .. ")  (" .. targetedNotes .. " targeted)     " .. trName  ) 
      end
       
      reaper.ImGui_End(ctx)
    end                                                 -- if imgui begin
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopStyleVar(ctx)
  end         
   
  reaper.defer(loop)
  editCurPosLast = reaper.GetCursorPosition()
end
   --------------------------------------------
  
local function Clean()
  reaper.JS_LICE_DestroyBitmap( bitmap )
end

--------------------------------------------
function main()
  reaper.defer(function() xpcall(Main, Clean) end)
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
  Clean()
  reaper.JS_LICE_DestroyBitmap( guideLines)
  reaper.JS_LICE_DestroyBitmap( targetGuideline)
  reaper.JS_LICE_DestroyBitmap( guideLinesShadow)
  reaper.JS_LICE_DestroyBitmap( targetGuideline)

  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
  reaper.RefreshToolbar2( sec, cmd ) 
end
-----------------------------------------------
_, _, sec, cmd = reaper.get_action_context()
SetButtonON()
reaper.atexit(SetButtonOFF)

