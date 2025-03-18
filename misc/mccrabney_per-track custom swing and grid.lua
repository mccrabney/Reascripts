--[[
 * ReaScript Name: mccrabney_per track custom swing and grid
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]

--[[ instructions: 

  Run this script 
  at init, script will interpret the current grid/swing settings as "project" settings
  select only your desired track and adjust the track swing and grid parameters
  these params are saved in the track extstate and will be retrieved upon selection
  the "clear" button will remove saved grid settings for the selected track
  
  TODO: 
  * undo support on manual, gui-triggered grid changes (NOT undo for grid changes on track change)?
  * handle triplet grids
    
--]]

--[[
 * Changelog: 
 * v1.0 (2025-03-18)
   + initial release
--]]

---------------------------------------------------------------------------------------    
dbg = false

local _, script_filename, _, _, _, _, _ = reaper.get_action_context()
local SCRIPT_DIRECTORY = script_filename:match('(.*)[%\\/]') .. "\\"
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3'
reaper.set_action_options(1)

SCRIPT_TITLE = "Per-track custom swing and grid"

local ctx = reaper.ImGui_CreateContext(SCRIPT_TITLE, ImGui.ConfigFlags_NoSavedSettings)

if not reaper.ImGui_CreateContext then
  reaper.MB("Download ReaImGui extension via Reapack ReaTeam extension repository.", "Error", 0)
  return false
end

function SetButtonState(set) -- Set ToolBar Button State
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

function Exit() SetButtonState() end

function debug(statement, newLine, clear)
  if clear then reaper.ClearConsole() end
  if dbg == true then reaper.ShowConsoleMsg(statement)
    if newLine == 1 then reaper.ShowConsoleMsg("\n") end
  end
end

----------------------------------------------------------------------
-- VARIABLES --
----------------------------------------------------------------------

local function TrackName(track)
  local _, buf = reaper.GetTrackName(track)
  trNum = math.floor(reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER'))
  return "tr " .. trNum .. " '" .. buf .. "'"
end

local STATE = {}
local GRID = {}
local prGRID = {}
local COLOR = {}
local prjCOLOR = {}
STATE.swing = 0
STATE.prjswing = 0

--------------------------------------------------------------------
-- INIT --
---------------------------------------------------------------------
function Init()
  timeStart = reaper.time_precise()                              -- systime at script start
  _, initDiv, _, initSwing = reaper.GetSetProjectGrid(0, false)  -- grid/swing details at init
  initSwing = initSwing * 100                                    -- normalize to other values
  x, y = reaper.GetMousePosition()                               -- mouse pos at script start
  sx, sy = reaper.ImGui_PointConvertNative(ctx, x, y, false)     -- convert to native imgui 
  
  SetButtonState(1)
  reaper.atexit(Exit)
  reaper.defer(Run)
end

----------------------------------------------------------------------
-- body --------------------------------------------------------------
----------------------------------------------------------------------
function gridManager()
  if STATE.editing_track ~= prevLastTouchedTrack or update == 1 then  -- on init, track change, and 'update'
    prevLastTouchedTrack = STATE.editing_track    -- do this once
    update = 0                                    
    debug("==== init, track change, or update =====", 1, 1)
    debug(TrackName(STATE.editing_track), 1)
    clearColor = nil
    STATE.swing = 0     -- reset track swing, will be populated by extstate if present
    lastSwing = 0       -- prevent unnecessary extstate writing
                        
    if prjSwingAmount == nil then       -- get track swing extstate, set prj swing if absent
      debug("prjSwing grabbed from initSwing",1)
      prjSwingAmount = initSwing        -- set prj swing to swing from init
    end
    
    _, trSwing = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", "", false)
    if trSwing and trSwing ~= "" then  -- if track has custom swing
      debug("swing extstate is present on track change:" .. trSwing,1)
      clearColor = 0x42ddf5AA          -- set CLEAR button color
      trSwing = tonumber(trSwing)      -- get number from swing
      STATE.swing = trSwing            -- update track swing slider
      lastSwing = -1                   -- force update with n/a value
    else                               -- if no trSwing
      reaper.GetSetProjectGrid(0, 1, null, 1, prjSwingAmount/100)   -- set swing to slider value
      debug("prjSwing set to: " .. prjSwingAmount, 1)
    end -- if ext
                        -- get track grid extstate, set prj grid if absent    
    _, trGrid = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", false)
    if trGrid and trGrid ~= "" then    -- if track has custom grid
      debug("grid extstate present:" .. trGrid,1)
      clearColor = 0x42ddf5AA          -- set CLEAR button color
      trGrid = tonumber(trGrid)        -- get number from grid
      debug("trgrid extstate is present on track change: " .. trGrid,1) 
      if trGrid == 1 then COLOR[1] = 0x42ddf5AA GRID[1] = 1 else COLOR[1] = 0x00000000 GRID[1] = 0 end
      if trGrid == .5 then COLOR[2] = 0x42ddf5AA GRID[2] = 1 else COLOR[2] = 0x00000000 GRID[2] = 0 end
      if trGrid == .25 then COLOR[3] = 0x42ddf5AA GRID[3] = 1 else COLOR[3] = 0x00000000 GRID[3] = 0 end
      if trGrid == .125 then COLOR[4] = 0x42ddf5AA GRID[4] = 1 else COLOR[4] = 0x00000000 GRID[4] = 0 end
      if trGrid == .0625 then COLOR[5] = 0x42ddf5AA GRID[5] = 1 else COLOR[5] = 0x00000000 GRID[5] = 0 end
      if trGrid == .03125 then COLOR[6] = 0x42ddf5AA GRID[6] = 1 else COLOR[6] = 0x00000000 GRID[6] = 0 end
      if trGrid == .015625 then COLOR[7] = 0x42ddf5AA GRID[7] = 1 else COLOR[7] = 0x00000000 GRID[7] = 0 end
      if trGrid == .0078125 then COLOR[8] = 0x42ddf5AA GRID[8] = 1 else COLOR[8] = 0x00000000 GRID[8] = 0 end
      reaper.GetSetProjectGrid( 0, 1, trGrid, 1, null)  -- set prj grid to specified division
      lastGrid = -1                    -- force update with n/a value
    else                               -- if no trGrid
      debug("no trGrid",1)
      for i = 1, 8 do                  -- flash grid table/inputs with no input, no color
        GRID[i] = 0
        COLOR[i] = 0x00000000
      end
      
      if prjDiv == nil then            -- if there is no project grid after all that,
        debug("prjDiv grabbed from initGrid",1)
        prjDiv = initDiv               -- get it from init
      end
      
      reaper.GetSetProjectGrid(0, 1, prjDiv, 1, null)   -- set swing to slider value
      debug("prjDiv set to: " .. prjDiv,1)
    end -- if ext
    
    debug("--------------------",1)
  end -- if init, track change or update

  ------------------------------------------------------------------------------------
  --------------------------- continuously get selected track's swing extstate
  local _, sw = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", "", false)
  if sw and sw ~= "" then            -- if track has custom swing
    sw = tonumber(sw)                -- get number from extstate string
    if sw ~= lastsw then             -- if different from last
      if sw ~= 0 then clearColor = 0x42ddf5AA end   -- set CLEAR button color
      lastsw = sw                    -- do once
      if sw ~= STATE.swing then      -- if extstate is different from the slider input,
        STATE.swing = sw             -- change reaimgui slider input to extstate swing value
      end                            -- if different from swing slider
    end                              -- if different from last extstate value
  end                                -- if no custom grid
  ------------------------------------------------------------------------------------
  --------------------------- continuously get selected track's grid extstate
  local _, gr = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", false)
  if gr and gr ~= ""  then          -- if track has custom grid
    gr = tonumber(gr)               -- get number from extstate string
    if gr ~= lastgr then            -- if grid has changed
      lastgr = gr                   -- oneshot for color and button update
      clearColor = 0x42ddf5AA       -- color the button to indicate present grid
      debug("gr extstate: " .. gr,1) 
      if gr == 1 then COLOR[1] = 0x42ddf5AA GRID[1] = 1 else COLOR[1] = 0x00000000 GRID[1] = 0 end
      if gr == .5 then COLOR[2] = 0x42ddf5AA GRID[2] = 1 else COLOR[2] = 0x00000000 GRID[2] = 0 end
      if gr == .25 then COLOR[3] = 0x42ddf5AA GRID[3] = 1 else COLOR[3] = 0x00000000 GRID[3] = 0 end
      if gr == .125 then COLOR[4] = 0x42ddf5AA GRID[4] = 1 else COLOR[4] = 0x00000000 GRID[4] = 0 end
      if gr == .0625 then COLOR[5] = 0x42ddf5AA GRID[5] = 1 else COLOR[5] = 0x00000000 GRID[5] = 0 end
      if gr == .03125 then COLOR[6] = 0x42ddf5AA GRID[6] = 1 else COLOR[6] = 0x00000000 GRID[6] = 0 end
      if gr == .015625 then COLOR[7] = 0x42ddf5AA GRID[7] = 1 else COLOR[7] = 0x00000000 GRID[7] = 0 end
      if gr == .0078125 then COLOR[8] = 0x42ddf5AA GRID[8] = 1 else COLOR[8] = 0x00000000 GRID[8] = 0 end
    end
  end

  -----------------------------------------------------------------------------------
  ------------- UI objects - project-------------------------------------------------
  -----------------------------------------------------------------------------------
  
  prjName = reaper.GetProjectName(0)
  if prjName == "" then prjName = "unsaved project" end  
  
  ImGui.Text( ctx, "project grid/swing: (" .. prjName .. ")") ImGui.SameLine(ctx, 0.0, -1.0)  
  dbgButton = ImGui.Button(ctx, "?##dbg",  0.0, 0.0) 
  if dbgButton then					
    if dbg == false then dbg = true 
      debug("debug on",1)
    else 
      debug("debug off",1)
      dbg = false end
  end
  
                        -- color buttons based on what grid division is selected
  if prjDiv == 1 then prjCOLOR[1] = 0x42ddf5AA else prjCOLOR[1] = 0x00000000 end
  if prjDiv == .5 then prjCOLOR[2] = 0x42ddf5AA else prjCOLOR[2] = 0x00000000 end
  if prjDiv == .25 then prjCOLOR[3] = 0x42ddf5AA else prjCOLOR[3] = 0x00000000 end
  if prjDiv == .125 then prjCOLOR[4] = 0x42ddf5AA else prjCOLOR[4] = 0x00000000 end
  if prjDiv == .0625 then prjCOLOR[5] = 0x42ddf5AA else prjCOLOR[5] = 0x00000000 end
  if prjDiv == .03125 then prjCOLOR[6] = 0x42ddf5AA else prjCOLOR[6] = 0x00000000 end
  if prjDiv == .015625 then prjCOLOR[7] = 0x42ddf5AA else prjCOLOR[7] = 0x00000000 end
  if prjDiv == .0078125 then prjCOLOR[8] = 0x42ddf5AA else prjCOLOR[8] = 0x00000000 end
  
                        -- project grid buttons
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[1])
  prGRID[1] = ImGui.Button(ctx, " 1 ##prjGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[2])
  prGRID[2] = ImGui.Button(ctx, "1/2##prjGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[3])
  prGRID[3] = ImGui.Button(ctx, "1/4##prjGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[4])
  prGRID[4] = ImGui.Button(ctx, "1/8##prjGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[5])
  prGRID[5] = ImGui.Button(ctx, "1/16##prjGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[6])
  prGRID[6] = ImGui.Button(ctx, "1/32##prjGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[7])
  prGRID[7] = ImGui.Button(ctx, "1/64##prjGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[8])
  prGRID[8] = ImGui.Button(ctx, "/128##prjGrid", 35, 25) --ImGui.SameLine(ctx, 0.0, -1.0)
  
  reaper.ImGui_SetNextItemWidth( ctx, 336)  -- prj swing slider
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), 0x42ddf5AA)
  _, prjSwingAmount = reaper.ImGui_SliderDouble(ctx, "##prjswing", tonumber(prjSwingAmount), 0, 100, "prj swing: %.0f%%")
  
  reaper.ImGui_PopStyleColor(ctx, 9)

  for i = 1, 8 do           -- check GRID table for user input
    if prGRID[i] then       -- set prj grid to specified division  
      reaper.GetSetProjectGrid( 0, 1, 1/(2^i/2), 1, null)  
      prjDiv = 1/(2^i/2)    -- get sensible grid division from integer
      debug(prjDiv,1)
    end
  end
                          
  -----------------------------------------------------------------------------------
  ------------- UI objects - tr -----------------------------------------------------
  -----------------------------------------------------------------------------------

  if sw ~= nil and sw ~= "" then     -- if no custom swing, color setup for sliders, clear button
    prjColor   = 0x00000000 
    trColor    = 0x42ddf5AA 
  else 
    prjColor   = 0x42ddf5AA 
    trColor    = 0x00000000 
  end
  
  if clearColor == nil then clearColor = 0x00000000 end 
  
  ImGui.SeparatorText(ctx, "")       -- print track whose grid is being customized
  ImGui.Text( ctx, "track grid/swing: (" .. TrackName(STATE.editing_track) .. ")")  
  
  for i = 1, 8 do                    -- transparent if empty table values
    if COLOR[i] == nil then COLOR[i] = 0x00000000 end
  end
  
                                     -- track grid buttons
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[1])
  GRID[1] = ImGui.Button(ctx, " 1 ##trGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[2])
  GRID[2] = ImGui.Button(ctx, "1/2##trGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[3])
  GRID[3] = ImGui.Button(ctx, "1/4##trGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[4])
  GRID[4] = ImGui.Button(ctx, "1/8##trGrid",  35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[5])
  GRID[5] = ImGui.Button(ctx, "1/16##trGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[6])
  GRID[6] = ImGui.Button(ctx, "1/32##trGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[7])
  GRID[7] = ImGui.Button(ctx, "1/64##trGrid", 35, 25) ImGui.SameLine(ctx, 0.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[8])
  GRID[8] = ImGui.Button(ctx, "/128##trGrid", 35, 25) --ImGui.SameLine(ctx, 0.0, -1.0)
  
  reaper.ImGui_SetNextItemWidth(ctx, 280)  -- track swing slider
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), trColor)
   _, STATE.swing = reaper.ImGui_SliderDouble(ctx, "##swing", tonumber(STATE.swing), 0, 100, "track swing: %.0f%%")
  
  ImGui.SameLine(ctx, 0.0, -1.0)           -- button to clear custom grid/swing values
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), clearColor)
  clear = ImGui.Button(ctx, "CLEAR", 0.0, 0.0)
  
  reaper.ImGui_PopStyleColor(ctx, 10)
  -----------------------------------------------------------------------------------

  prjSwingAmount = tonumber(prjSwingAmount)       -- get tonumber prj swing
  if prjSwingAmount ~= lastPrjSwingAmount then    -- if prj swing has been updated
    if sw == nil or sw == "" then                 -- if nothing in track extstate
      reaper.GetSetProjectGrid( 0, 1, division, 1, prjSwingAmount/100 )   -- set grid swing to slider value
    end
    lastPrjSwingAmount = prjSwingAmount           -- do once
  end
  
  if clear then                                   -- if 'clear' button was pressed
    update = 1                                    -- update values, clear extstates
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", "", true)
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", true)
  end

  if timeRun - timeStart < 1 then lastSwing = STATE.swing end -- prevent script init from triggering custom swing
  
  if STATE.swing ~= lastSwing then                -- if slider value is different from prev slider value, 
    debug("swing updated" .. STATE.swing .. " " .. lastSwing,1)
    reaper.GetSetProjectGrid( 0, 1, division, 1, STATE.swing/100 )    -- set grid swing to slider value
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", tostring(STATE.swing), true)
    lastSwing = STATE.swing                                           -- do once
  end
    
  --------------------------------------------------------------------------------
  for i = 1, 8 do           -- check GRID table for user input
    if GRID[i] then         -- if present,
      reaper.GetSetProjectGrid( 0, 1, 1/(2^i/2), 1, swingamt )  -- set tr grid to specified division
      reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", tostring(1/(2^i/2)), true)
    end
  end
end

------------------
-- RUN
---------------------
function Run()
  timeRun = reaper.time_precise()       -- systime while running
  STATE.editing_track = reaper.GetLastTouchedTrack() or reaper.GetTrack(0,0) -- get track
  if STATE.editing_track ~= lastTouchedTrack then lastTouchedTrack = STATE.editing_track end
  
  if set_dock_id then
    reaper.ImGui_SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end
  
  reaper.ImGui_SetNextWindowPos(ctx, sx, sy, 2, .5, 1.75) -- set pos based on mouse coordinates
  reaper.ImGui_SetNextWindowSize(ctx, 0.0, 0.0)
  
  local imgui_visible, imgui_open = reaper.ImGui_Begin(ctx, SCRIPT_TITLE, true, 
    ImGui.WindowFlags_NoResize |
    ImGui.WindowFlags_NoScrollbar |
    ImGui.WindowFlags_NoFocusOnAppearing )

  if imgui_visible then   -- if window is visible, run Main()
    gridManager()
    reaper.ImGui_End(ctx)
  end

  if imgui_open and not exit then  -- if closed, close imgui window
    reaper.defer(Run)
  end
end -- END DEFER

----------------------------------------------------------------------
-- script --
----------------------------------------------------------------------

Init()

-------------


