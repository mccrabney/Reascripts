--[[
 * ReaScript Name: Fiddler (arrange screen MIDI editing).lua
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.88
 * Provides: Modules/*.lua
--]]
 
-- discussion thread: https://forum.cockos.com/showthread.php?t=274257 

-- HOW TO USE:
-- run this defer script, then mouse over MIDI in your arrange screen.
-- guidelines and a readout will appear, targeting the MIDI under your mouse.
-- "mccrabney_Fiddler - toggle target-hold note.lua" will create an RE and target notes within
-- use the other Fiddler scripts to edit MIDI from the arrange screen.
-- 

-- special thanks to Sexan, cfillion, Meo-Ada-Mespotine, BirdBird, and others for code/help

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
local main_wnd = reaper.GetMainHwnd()                                -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local pitchList = {"C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "}
local ctx = reaper.ImGui_CreateContext('shownotes')                  -- create imgui context

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
lastX = 0
elapsed = 0
arrangeTime = 0
lastArrangeTime = 0
pop = 0 
editCurPosLast = -1
toggleNoteHold = 0                              -- set notehold off by default
noteHoldNumber = -1                             -- default notehold number to an inapplicable value
local elapsed 
mediaAreas = {} 
targetTable = {} 
multiple = 0
reset = 0

    --[[------------------------------[[--
          loop and show tooltips, cursor as necessary  
    --]]------------------------------]]--
function loop()
  --mouse = MouseInfo()
  --if mouse.l_down == true then reaper.ShowConsoleMsg("click" .. "\n") end
  loopCount = loopCount+1                                       -- advance loopcount
  idleCount = idleCount+1                                       -- advance idlecount
  editCurPos = reaper.GetCursorPosition()
  local lastMIDI = {}                                          
  reaper.ImGui_GetFrameCount(ctx)                               -- "a fast & inoffensive function"
                                                                -- optimizer to reduce calls to getCursorInfo
  if loopCount >= 3 and info == "arrange" and lastX ~= x and pop == 0   -- if we're in the right place, and on the move
  or editCurPos ~= editCurPosLast then                                 -- or if the edit cursor has moved,
    take, targetPitch, showNotes, targetNoteIndex, targetNotePos, targetEndPos, track, trPos, tcpHeight, trName, cursorPos = getCursorInfo() 
    if take ~= nil and reaper.TakeIsMIDI(take) then             -- if take is MIDI
      loopCount = 0                                             -- reset loopcount
      idleCount = 0                                             -- reset idlecount
      lastX = x                                                 -- set lastX mouse position
    else lastX = x end
  end    

  extStates()                                                   -- communicate with other scripts
  idleSensor()                      
  
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
  
  if arrangeTime ~= lastArrangeTime then            -- if arrange screen bounds have moved
    elapsed = 0                                     -- timer == 0
    time_start = reaper.time_precise()              -- start the clock
    lastPixelLength = -1
    lastAllAreas = -1
  else                                              -- if arrange screen bounds haven't changed,
    elapsed = reaper.time_precise() - time_start    -- set elapsed time since arrange hasn't moved
  end
  lastArrangeTime = arrangeTime                     -- get last arrangetime value
  if cursorSource == 1 then curColor = 0xFFFF0000 else curColor = 0xFF0033FF end   -- set cursor colors

  --]]------------------------------------------------------------------
  ----------------multiple target notes in RE --------------------------  
  -- [[-----------------------------------------------------------------
  if noteHoldNumber == -1 then lastAllAreas = -1 end   -- if noteHold is off, trick areas into moving
  local areas
  local zoom_lvl = reaper.GetHZoomLevel()
  numMediaAreas = 0
  
  if RazorEditSelectionExists() then
    lastRE = 1
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
    
    if lastTCPheight ~= tcpHeight then     -- if height changed
      debug("tcpHeight updated", 1)
      lastTCPheight = tcpHeight
      lastAllAreas = -1
      reset = 1
    end
     
    if lasttrPos ~= trPos then             -- if track position has changed
      debug("trPos updated", 1)
      lasttrPos = trPos
      lastAllAreas = -1
      reset = 1 
    end
    --]]
    
    if lastAreaNum ~= areaNum then         -- if number of areas changed,
      debug("areaNum updated", 1)
      lastAreaNum = areaNum
      lastAllAreas = -1                  -- reset print
    end
    
    if lastNoteHoldNumber ~= noteHoldNumber then
      debug("noteHoldNumber updated", 1)
      lastNoteHoldNumber = noteHoldNumber
      lastAllAreas = -1
    end 
    
    if mTrack ~= nil  then                  -- if we have a multiple-target track
      unlinked = 0                          -- turnoff flag
      multiple = 1                          -- multiple flag
      mtcpHeight = reaper.GetMediaTrackInfo_Value( mTrack, "I_TCPH")  -- get track height
      mtrPos = reaper.GetMediaTrackInfo_Value( mTrack, 'I_TCPY' )     -- y pos of track TCP

      if noteHoldNumber ~= nil and noteHoldNumber ~= -1 and elapsed > .2 then
        allAreas = start_pos + end_pos         -- get the full area span
        if lastAllAreas ~= allAreas then       -- if area size changed (or other triggers above)
          if cursorSource == 1 then curColor = 0xFFFF0000 else curColor = 0xFF0033FF end   -- set cursor colors
          doOnce = 1
          debug("area reset", 1)
          lastAllAreas = allAreas              -- do once
          areaStartPixel = math.floor((start_pos - startTime) * zoom_lvl)   -- get the pixel for area start BM
          areaEndPixel   = math.floor((end_pos   - startTime) * zoom_lvl)   -- get the pixel for area end BM
          areaLengthPixel = areaEndPixel-areaStartPixel                     -- area length in pixels
          reaper.JS_Composite_Unlink(track_window, guideLines, true)        -- unlink previous BM
          reaper.JS_LICE_DestroyBitmap(guideLines)                          -- destroy prev BM
          
          if mtcpHeight == nil then mtcpHeight = 0 end
          guideLines = reaper.JS_LICE_CreateBitmap(true, areaLengthPixel+3, mtcpHeight)  -- create the BMM
          reaper.JS_LICE_Clear(guideLines, 0 )                              -- clear the BM
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
                for t = 0, reaper.CountTakes(item)-1 do       -- for each take,
                  take = reaper.GetTake(item, t)              -- get take
                  if reaper.TakeIsMIDI(take) then             -- if it's MIDI, get RE PPQ values
                    razorStart_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reStart) 
                    razorEnd_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reEnd) 
                    notesCount, _, _ = reaper.MIDI_CountEvts(take) -- count notes in current take                    
                    for n = notesCount-1, 0, -1 do          -- for each note, from back to front
                      --_, _, _, startppq, endppq, _, pitch, _ = mu.MIDI_GetNote(take, n)  -- get note data           
                      _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)  -- get note data           
                      if startppq >= razorStart_ppq_pos and startppq < razorEnd_ppq_pos then  -- if in RE bounds
                        if noteHoldNumber == pitch then     -- if it's the targeted pitch
                          reaper.MIDI_SetNote( take, n, 1, nil, nil, nil, nil, nil, nil)
                          targetedNotes = targetedNotes + 1
                          noteStartPos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)  -- note pos of note under cursor
                          noteEndPos =   reaper.MIDI_GetProjTimeFromPPQPos(take, endppq)      -- note pos of note under cursor
                          targetTable[targetedNotes] = noteStartPos 
                          targetNotePixel    = math.floor((noteStartPos -  start_pos) * zoom_lvl)  -- note start pixel
                          targetNotePixelEnd = math.floor((noteEndPos   -  start_pos) * zoom_lvl)  -- note end pixel
                          if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
                          if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
                          pixelLength = targetNotePixelEnd-targetNotePixel    -- pixel length of note
                          reaper.JS_LICE_Line( guideLines, targetNotePixel,   0, targetNotePixelEnd+1 ,         0,            curColor, .25,       "COPY", true )  -- red guidelines
                          reaper.JS_LICE_Line( guideLines, targetNotePixel+1, 0, targetNotePixel+1, mtcpHeight,  0xFF000000, .1, "COPY", true )
                          reaper.JS_LICE_Line( guideLines, targetNotePixelEnd+2, 0, targetNotePixelEnd+2, mtcpHeight,  0xFF000000, .1, "COPY", true )
                        end  -- if MIDI note is targeted                 
                      end  -- if MIDI note is within RE bounds
                    end -- for each note
                  end -- if take is MIDI
                end -- for each take
              end -- for each item
            end -- if area isn't envelope
          end -- for each area
                    
          if targetedNotes == 0 then noteHoldNumber = -1 end   -- if there aren't any of the targeted notes, exit notehold
          if tcpHeight == nil then tcpHeight = 0 end
          if trPos == nil then trPos = 0 end
          
          debug("print composite", 1)
          reaper.JS_Composite(track_window, areaStartPixel, mtrPos, areaLengthPixel+3, mtcpHeight - 3, guideLines, 0, 0, areaLengthPixel+3, 1, true) -- DRAW          
          reaper.Undo_OnStateChange2(proj, "targeted note " .. noteHoldNumber)
        end -- if area moved
      else  -- if notehold is off
        multiple = 0
        if unlinked == 0 and doOnce == 1 then 
          reaper.Undo_BeginBlock()
          debug("unlinked, noteHold is off", 1)
          reaper.JS_Composite_Unlink(track_window, guideLines, true)
          reaper.JS_LICE_DestroyBitmap(guideLines)                          -- destroy prev BM
          reaper.Undo_EndBlock( "released note target", -1 )
          --reaper.Undo_OnStateChange2(proj, "released note target")
          unlinked = 1
          doOnce   = 0
        end
      end -- if notehold is on
    end -- if mTrack isn't nil
  end  -- if RE exists
  
  if not RazorEditSelectionExists() and lastRE == 1 then 
    lastRE = 0
    debug("unlinked: mouseclick, or no RE", 1)
    noteHoldNumber = -1
    reaper.JS_Composite_Unlink(track_window, guideLines, true)
    reaper.JS_LICE_DestroyBitmap(guideLines)                          -- destroy prev BM
    multiple = 0
  end
  

 ---]]-----------------------------------------------------------------
 ----------------single target note------------------------------------  
 -- [[-----------------------------------------------------------------
  if targetPitch == nil then 
    lastPixelLength = -1 
    lastTargetPitch = -1
  end  -- if no note is under cursor, set lastval to n/a
  
  if targetPitch ~= nil and info == "arrange" and take ~= nil and noteHoldNumber == -1 and elapsed > .2 then 
    if targetNotePos then                           -- if there's a note pos to target,
      local zoom_lvl     = reaper.GetHZoomLevel()       -- get rpr zoom level
      targetNotePixel    = math.floor((targetNotePos - startTime) * zoom_lvl) -- get note start pixel
      targetNotePixelEnd = math.floor((targetEndPos  - startTime) * zoom_lvl) -- get note end pixel
      if targetNotePixel    < 0 then targetNotePixel    = 0 end   -- set bounds for target note
      if targetNotePixelEnd < 0 then targetNotePixelEnd = 0 end   
      pixelLength = targetNotePixelEnd-targetNotePixel    -- get pixel length of note
      alpha = .25
                        -- draw conditions --
      if targetNotePos ~= lastTargetNotePos and elapsed > .2 -- then -- and lastPixelLength ~= pixelLength   -- if the last pixel length is different than this one,
      or lastTargetPitch ~= targetPitch 
      or reset == 1 and multiple == 0 then             

        lastTargetNotePos = targetNotePos 
        lastTargetPitch = targetPitch
        if cursorSource == 1 then curColor = 0xFFFF0000 else curColor = 0xFF0033FF end   -- set cursor colors
        lastAlpha = alpha
        lastPixelLength = pixelLength
        reaper.JS_Composite_Unlink(track_window, targetGuideline, true)   -- LICE: destroy prev BM, set up new one, 
        reaper.JS_LICE_DestroyBitmap(targetGuideline)                     -- and draw colored guidelines.    
        targetGuideline = reaper.JS_LICE_CreateBitmap(true, pixelLength+3, tcpHeight)
        reaper.JS_LICE_Clear(targetGuideline, 0 )   -- clear
        --reaper.JS_LICE_Line( bitmap,          x1, y1,             x2,          y2,          color,    alpha,    mode,  antialias )
        reaper.JS_LICE_Line( targetGuideline, 0,  0,              0,           tcpHeight,   curColor, 1,       "COPY", true )  -- red guidelines
        reaper.JS_LICE_Line( targetGuideline, 0, 0, pixelLength, 0, curColor, alpha, "COPY", true )  -- red guidelines
        reaper.JS_LICE_Line( targetGuideline, pixelLength+1, 0, pixelLength+1, tcpHeight,  curColor, 1, "COPY", true )
        --reaper.JS_LICE_Line( targetGuideline, 0, 0, 0, tcpHeight,  0xFF000000, .1, "COPY", true ) -- black guidelines
        --reaper.JS_LICE_Line( targetGuideline, pixelLength, 0, pixelLength, tcpHeight,  0xFF000000, .1, "COPY", true )
        --debug("printed single target note: " .. targetPitch, 1)
        reaper.JS_Composite(track_window, targetNotePixel, trPos, pixelLength+3, tcpHeight - 3, targetGuideline, 0, 0, pixelLength+3, 1, true) -- DRAW          redraw = nil
        reset = 0
      end
                       -- bmp,          dstx,           dsty,   dstw,           dsyh,         sysbm,     srcx, srcy, srcw,        srch, autoupdate
    end
  else  -- if single target note conditions not met,
    reaper.JS_Composite_Unlink(track_window, targetGuideline, true)
    reaper.JS_LICE_DestroyBitmap(targetGuideline)
  end
     
  --]]------------------------------------------------------------------
  ----------------READOUT: ReaImGUI note data display ------------------
  -- [[-----------------------------------------------------------------
  if multiple == 0 and targetPitch ~= nil and info == "arrange" and take ~= nil and elapsed > .2 
  or multiple == 1 and targetPitch ~= nil and info == "arrange" and take ~= nil and mTrack == track then
    --_, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, trPos+tcpHeight)
    if multiple == 0 then                -- if single instance of target note is targeted:
      sx, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, trPos+tcpHeight) 
      reaper.ImGui_SetNextWindowPos(ctx, sx, sy)   -- readout appears at note x position
    else                                -- if multiple instances of target note are targeted:
      _, sy = reaper.JS_Window_ClientToScreen( track_window, targetNotePixel-60, mtrPos+mtcpHeight) 
      reaper.ImGui_SetNextWindowPos(ctx, x-100, sy)   -- readout follows mouse x position
    end
     
    local rounding                          -- round window for mouse cursor, square for edit
    if cursorSource == 1 then rounding = 12 else rounding = 0 end
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x00000000 | 0xFF)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), rounding)
    if reaper.ImGui_Begin(ctx, 'Tooltip', false,
    reaper.ImGui_WindowFlags_NoFocusOnAppearing() |
    reaper.ImGui_WindowFlags_NoDecoration() |
    reaper.ImGui_WindowFlags_TopMost() |
    reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
      local octaveNote                                  -- variables for readout
      local noteSymbol                                  
      local color = 0xFFFFFFFF                          -- offwhite for non-target note readouts
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
     
      for i = #showNotes, 1, -1 do                   -- for each top-level entry in the showNotes table,
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
  --elapsed = 1
  --lastArrangeTime = arrangeTime
  --elapsed = 0
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

--[[
 * Changelog:
* v1.88 (2023-12-08)
  + more drawing improvements
* v1.87 (2023-12-07)
  + fixed blue guideline not reprinting on mouse moving to/from another track
* v1.86 (2023-12-07)
  + fixed "nudge" blue guideline getting de-synced
* v1.85 (2023-12-07)
  + improved note/track name readout logic
* v1.84 (2023-12-06)
  + print track name in readout, if note is not named. verbose, but worth it. 
  + optimized single indicator block readout to only print once, instead of multiple times
* v1.83 (2023-12-06)
  + indicator block drawing improvements: edges, reduced calls to JS_Composite
* v1.82 (2023-12-05)
  + initialize cursorSource to Mouse at first run
* v1.81 (2023-12-05)
  + "Fiddler v1" but higher version numbers have more gravitas so i'm keeping it up
  + renamed a bunch of these scripts to be more accurate, sorry for any shortcut chaos caused.
* v1.80 (2023-12-??) 
  + importing Sexan's area51 mouse functions
  + organized functions into their own files in Modules folder
  + better debug messaging system
  + tons of fixes, refactoring, and optimizations
* v1.79 (2023-11-20)
  + changed placement of readout to below track (y) , and a little before the note (x) for less eye flicker
  + replaced note on/off guidelines with note duration blocks: easier on the eyes and better at conveying targeted notes
  + added an alpha gradient to redraw alpha of indicator block to be less if further away from note start
  + added idleTask section. for now, it just cleans up a dummy CC that I use in my "copy MIDI in REs" script. 
    + in the future, this could be a general sanitizer to clean up audio items without fades, etc
    + i'll try to leave this off by default for public use but may occasionally (edit, always) forget
  + added elapsed optimzer to prevent multi-guideline redrawing on arrange view change
  + fixed tracks looking for other tracks' RS5K links for naming note instances
    + now, only tracks named "sequencer" will do this. a coarse fix, mostly for me.
* v1.78 (2023-11-16)
  + for "note hold" RE multi-targeting, improve text readout explaining what is happening
  + added multiple guidelines for when multiple notes are targeted in REs
  + changed shift increment readout to show "t" for "tick"
* v1.77 (2023-11-5)
  + reverted mouse clearing in 1.75, and instead attempted blanking displays while screen scrolling via reaper.BR_GetArrangeView()
* v1.76 (2023-11-9)
  + lost version, see next
* v1.75 (2023-11-5)
  + when middle mouse scrolling (hand scroll in my setup), don't print ghost lines
* v1.74 (2023-10-22)
  + print named note or RS5K instance trackname to MIDI readout
* v1.73 (2023-7-20)
  + if loopcount passes resetCursor value, then cursor resets to "under mouse"
  + remove padding for guideliness
* v1.72a (2023-7-20)
  + clearing REs turns off RE-last-hit focus
* v1.72 (2023-7-20)
  + transposing last-hit notes in RE now updates the last-hit note
* v1.71 (2023-7-19)
  + added ability to toggle holding of last hit note using script: mccrabney_MIDI edit - toggle hold input note for 'show notes'
    * running this action sets RE target note to note under cursor
    * inputting notes from controller will change target note.
    * running the script again again releases the note.
* v1.70 (2023-6-9)
  + guideliness drop shadows
* v1.69 (2023-6-9)
  + added ability to step through the notes/change target note currently under the cursor
    * use Script: mccrabney_MIDI edit - step through notes under cursor in 'show notes'.lua
    * targetNote will step through notes under cursor, closest to farthest.
* v1.68 (2023-6-9)
  + fixed bug where n.1.000 displayed as (n-1).1.000
* v1.67a (2023-6-8)
  + reverted 1.66 guidelines disable on middle click, bc it was suppressing middle clicks down w/out middle drag.
* v1.67 (2023-6-8)
  + added guidelines to show the noteOFF position
* v1.66 (2023-6-7)
  + time display: add support for time signatures other than 4/4
  + disable guidelines and text readout while left or middle clicking mouse
* v1.65 (2023-6-3)
  + fixed samedistance bug preventing closest note from being targeted
* v1.64 (2023-5-31)
  + added guidelines that indicates the target note: blue for edit cursor, red for mouse cursor
* v1.63 (2023-5-27)
  + updated name of script, extstate 
  + changed display for edit cursor mode: blue, vs red, and non-rounded tooltip corners
* v1.63 (2023-5-27)
  + updated name of script, extstate 
  + changed display for edit cursor mode: blue, vs red, and non-rounded tooltip corners
+ v1.62 (2023-5-26)
  + added "edit cursor mode" where edit cursor provides note data rather than mouse cursor
+ v1.61 (2023-5-25)
  + implemented variable nudge increment controlled by "mccrabney_MIDI edit - adjust ppq increment for edit scripts"
  + added note position readout, where time 1.1.000 begins at a marker named "start"
     if no marker named "start" is present, or if notes begin before "start" marker,
     then no time readout is displayed.
+ v1.6 (2023-5-23)
   + removed pause function, chasing an index as one note is nudged past another proved too difficult
+ v1.511 (2023-5-22)
   + minor typo fix
+ v1.51 (2023-5-21)
   + now reports toolbar button toggle state
 + v1.50 (2023-5-20)
   + added secondary script "pause show notes" to "hold" a target note in yellow
   + issue, mouse must still be over target Take, fix eventually? 
 + v1.45 (2023-5-09)
   + added muted note coloration
 + v1.44 (2023-5-07)
   + added extstates to output notes under mouse to other scripts
 + v1.43 (2023-5-05)
   + fixed error message, improved spacing on readout
 + v1.42 (2023-5-04)
   + added note duration display, changed readout to conform to conventional MPC step edit screen
 * v1.41 (2023-5-04)
   + fixed show last-hit MIDI note, appears in green, replacing existing readout if present
 * v1.4 (2023-5-04)
   + added velocity readout for all notes
* v1.3 (2023-5-03)
   + added velocity readout for target note only
 * v1.2 (2023-5-01)
   + fixed error message on MIDI item glue
 * v1.1 (2023-03-12)
   + fixed retriggering upon new MIDI notes
 * v1.0 (2023-03-12)
   + Initial Release -- "Crab Vision" (combined previous scripts)
--]]
