--[[
 * ReaScript Name: mccrabney_per track custom swing and grid
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.02
--]]

--[[ instructions: 

  Run this script. 
  at init, script will check to see if the script has been run on this project before.
  if so, project grid/swing settings will be pulled from an extstate and applied.
  if not, project grid/swing settings will be assigned from project settings at init.
  adjust project grid/swing settings as desired using the interface.
  
  to adjust per-track custom swing/grid settings, select only your desired track.
  adjust track grid/swing settings as desired using the interface.
  these params are saved in the track extstate and will be retrieved upon selection
  the "clear" button will remove saved grid settings for the selected track. 
  
--]]

--[[
 * Changelog: 
 * v1.02 (2026-06-01)
  + fixed bug where custom swing/div aren't loaded on track switch
 * v1.01 (2026-01-28)
   + support common triplet values
   + ui and debug improvements
   + store project grid/swing in project extstate
   + update script on project switch
 * v1.00 (2025-03-18)
   + initial release
--]]

---------------------------------------------------------------------------------------    
dbg = false
--dbg = true

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

local function TrackName(track)
  local _, buf = reaper.GetTrackName(track)
  trNum = math.floor(reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER'))
  return trNum .. ", '" .. buf .. "'"
end

----------------------------------------------------------------------
-- VARIABLES --
----------------------------------------------------------------------

local STATE = {}
local GRID = {}
local prGrid = {}
local prTripletGrid = {}
local trTripletGrid = {}
local COLOR = {}
local prjCOLOR = {}
STATE.trswing = -1
STATE.prjswing = -1
buttonOnColor = 0x42ddf5AA
buttonOffColor = 0x00000000
trDiv = nil
prjDiv = nil
lasttrSwing = -1       -- prevent unnecessary extstate writing
noTrSwing = -1

--------------------------------------------------------------------
-- INIT --
---------------------------------------------------------------------
function Init()
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
  ---------------------------------------------------------------------------------------
  projID, _ = reaper.EnumProjects(-1)  -- watch for project/tab change and get prj extstates
  _, _, val = reaper.EnumProjExtState(0, "crabSwingGrid", 0 ) -- check for project extstate
  if projID ~= projIDprev and val then      -- on track change, and if extstate,
    prjSwing = nil                    -- nil values so they are retrieved appropriately:
    prjDiv = nil                            -- get from prj extstate if present or init if not
    _, extPrjSwing = reaper.GetProjExtState(0, "crabSwingGrid", 1)
    _, extPrjDiv   = reaper.GetProjExtState(0, "crabSwingGrid", 2)
    if extPrjSwing and extPrjSwing ~= "" then  
      extPrjSwing = tonumber(extPrjSwing)    
    else                                                      -- if no value to be retrieved,
      _, _, _, initSwing = reaper.GetSetProjectGrid(0, false) -- get swing details at project init
      initSwing = initSwing * 100                             -- normalize to other values
    end
    if extPrjDiv and extPrjDiv ~= "" then 
      extPrjDiv = tonumber(extPrjDiv)    
    else                                                      -- if no value to be retrieved,
      _, initDiv, _, _ = reaper.GetSetProjectGrid(0, false)   -- get grid details at project init
    end
    update = 1                                                -- reset values
    projIDprev = projID                                       -- do once on project change
  end
 
  --------------------------------------------------------------------------------------
  ------------------------------------ STATE CHANGE ------------------------------------
  if STATE.editing_track ~= prevLastTouchedTrack or update == 1 then
    debug("==================================", 1, 1)
    if STATE.editing_track ~= prevLastTouchedTrack then 
      debug("=== selected track is now " .. TrackName(STATE.editing_track) .. " ===", 1)  
    end
    if prjSwing then debug("prjSwing = " .. prjSwing,1) end
    
    if update == 1 then debug("=== update message received ======", 1)  end
    prevLastTouchedTrack = STATE.editing_track    -- run this loop once on track change
    update = 0                                    -- run this loop once on update messag
    clearColor = nil                              -- default clear button color to nil
                        
    if prjSwing == nil then       -- get project swing extstate, set prj swing if absent
      if extPrjSwing ~= "" then         -- if there's a number in extstate
        prjSwing = extPrjSwing    
        debug("prjSwing grabbed from project extstate: " .. prjSwing,1)
      else
        prjSwing = initSwing      -- set prj swing to swing from project init
        debug("prjSwing grabbed from init: " .. initSwing,1)
      end
    end -- if prjSwing nil
    
    if prjDiv == nil then           -- get project division extstate, set prj div if absent
      if extPrjDiv ~= "" then       -- if there is a division in extstate
        prjDiv = extPrjDiv 
        debug("prjDiv grabbed from project extstate",1)
      else
        prjDiv = initDiv      -- set prj swing to swing from project init
        debug("prjDiv grabbed from init",1)
      end
    end -- if prjDiv nil
                                       -- get track swing extstate.
    _, trSwing = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", "", false)
    if trSwing and trSwing ~= "" then  -- if track has custom swing
      debug("swing extstate is present on track change: " .. trSwing,1)
      clearColor = buttonOnColor       -- set CLEAR button color
      trSwing = tonumber(trSwing)      -- get number from swing
      STATE.trswing = trSwing          -- update track swing slider
      reaper.GetSetProjectGrid(0, 1, null, 1, trSwing/100)
    end
    if prjSwing and trSwing == nil or trSwing == "" then
      reaper.GetSetProjectGrid(0, 1, null, 1, prjSwing/100)
      debug("no trSwing. refreshing prj swing instead",1)
    end -- if ext
                                       -- get track grid extstate, set prj grid if absent    
    _, trDiv = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", false)
    if trDiv and trDiv ~= "" then      -- if track has custom grid
      clearColor = buttonOnColor       -- set CLEAR button color
      debug("trDiv extstate is present on track change: " .. trDiv,1) 
      if trDiv ~= "" then trDiv = tonumber(trDiv) end  -- get number from grid
      for i = 1, 8 do               -- cycle through buttons and control their color & statu
        if trDiv == .5^(i-1) then COLOR[i] = buttonOnColor GRID[i] = 1 else COLOR[i] = buttonOffColor GRID[i] = 0 end
      end                           -- triplet button color control below. also corrects tonumb strings -> fractions
      if math.floor(trDiv*1000+.5)/1000 == .167 then trDiv =  1/6 COLOR[3] = buttonOnColor COLOR[9]  = buttonOnColor trTripletGrid[1] = 1 else COLOR[9]  = buttonOffColor trTripletGrid[1] = 0 end
      if math.floor(trDiv*1000+.5)/1000 == .083 then trDiv = 1/12 COLOR[4] = buttonOnColor COLOR[10] = buttonOnColor trTripletGrid[2] = 1 else COLOR[10] = buttonOffColor trTripletGrid[2] = 0 end
      if math.floor(trDiv*1000+.5)/1000 == .042 then trDiv = 1/24 COLOR[5] = buttonOnColor COLOR[11] = buttonOnColor trTripletGrid[3] = 1 else COLOR[11] = buttonOffColor trTripletGrid[3] = 0 end
      if math.floor(trDiv*1000+.5)/1000 == .021 then trDiv = 1/48 COLOR[6] = buttonOnColor COLOR[12] = buttonOnColor trTripletGrid[4] = 1 else COLOR[12] = buttonOffColor trTripletGrid[4] = 0 end
      --if math.floor(trDiv*1000+.5)/1000 == .083 then trDiv = 1/12 end
      reaper.GetSetProjectGrid( 0, 1, trDiv, 1, null)  -- set prj grid to specified division
    else                               -- if no trDiv
      reaper.GetSetProjectGrid( 0, 1, prjDiv, 1, null)  -- set prj grid to specified division
      for i = 1, 12 do                 -- flash grid table/inputs with no input, no color
        GRID[i] = 0
        COLOR[i] = 0x00000000
      end
    end -- if ext
    
    --if noTrSwing == 1 then
    --  reaper.GetSetProjectGrid(0, 1, null, 1, prjSwing/100)    -- set grid swing to slider value
    --  reaper.ShowConsoleMsg("!!!!" .. "\n")
    --  noTrSwing = 0
    --end
    debug("---------end update block---------------------",1)
  end -- if track change or update
  ----------------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------
  ---------------------------  get selected track's grid extstate
  local _, gr = reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", false)
  if gr and gr ~= ""  then          -- if track has custom grid
    gr = tonumber(gr)               -- get number from extstate string
    if gr ~= lastgr then            -- if grid has changed
      lastgr = gr                   -- oneshot for color and button update
      clearColor = buttonOnColor    -- color the button to indicate present grid
      for i = 1, 8 do               -- cycle through buttons and control their color & statu
        if gr == .5^(i-1) then COLOR[i] = buttonOnColor GRID[i] = 1 else COLOR[i] = buttonOffColor GRID[i] = 0 end
      end
      if math.floor(gr*1000+.5)/1000 == .167 then COLOR[3] = buttonOnColor COLOR[9]  = buttonOnColor trTripletGrid[1] = 1 else COLOR[9]  = buttonOffColor trTripletGrid[1] = 0 end
      if math.floor(gr*1000+.5)/1000 == .083 then COLOR[4] = buttonOnColor COLOR[10] = buttonOnColor trTripletGrid[2] = 1 else COLOR[10] = buttonOffColor trTripletGrid[2] = 0 end
      if math.floor(gr*1000+.5)/1000 == .042 then COLOR[5] = buttonOnColor COLOR[11] = buttonOnColor trTripletGrid[3] = 1 else COLOR[11] = buttonOffColor trTripletGrid[3] = 0 end
      if math.floor(gr*1000+.5)/1000 == .021 then COLOR[6] = buttonOnColor COLOR[12] = buttonOnColor trTripletGrid[4] = 1 else COLOR[12] = buttonOffColor trTripletGrid[4] = 0 end
    end
  end

  
  ---]]--------------------------------------------------------------------------------
  ------------- UI objects - tr -----------------------------------------------------
  if trSwing ~= "" then     -- if no custom swing, color setup for sliders, clear button
    prjColor   = 0x00000000  trColor    = 0x42ddf5AA  else 
    prjColor   = 0x42ddf5AA  trColor    = 0x00000000  
  end
  
  if clearColor == nil then clearColor = buttonOffColor end   -- set clear button color to off
  
  ImGui.Text( ctx, "TRACK #" .. TrackName(STATE.editing_track)) -- show track name and number
  ImGui.SameLine(ctx, 294.0, -1.0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), clearColor)  -- button color 
  clear = ImGui.Button(ctx, "CLEAR",  50, 20)                              -- clear button
  
  for i = 1, 8 do                    -- TRACK DIVISION BUTTONS
    if COLOR[i] == nil then COLOR[i] = 0x00000000 end   -- set n/a button color 'off'
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[i])
    local numerator = "1"
    if i == 8 then numerator = "" end
    GRID[i] = ImGui.Button(ctx, numerator .. "/"  .. tostring(math.tointeger(2^(i-1))) .. "##trDiv",  35, 25)
    if i < 8 then ImGui.SameLine(ctx, 0.0, -1.0)end
  end
  
  _ = ImGui.InvisibleButton(ctx, " ",  78, 15) ImGui.SameLine(ctx, 0.0, -1.0) -- dummy spacer button
  for i = 1, 4 do                    -- TRACK DIVISION TRIPLET BUTTONS
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLOR[i+8])
    trTripletGrid[i] = ImGui.Button(ctx, "•##trDiv"..i,  35, 15)
    if i < 4 then ImGui.SameLine(ctx, 0.0, -1.0) end
  end
  
  reaper.ImGui_SetNextItemWidth(ctx, 336)  -- TRACK SWING SLIDER
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), trColor)  -- slider handle color
  local trSliderText                       -- read percent if present, show directions if not.
  if trSwing and trSwing ~= "" then trSliderText = "track swing: " .. "%.0f%%"
  else
    trSliderText = "(click to set track swing " .. "%%" .. ")"
  end
   _, STATE.trswing = reaper.ImGui_SliderDouble(ctx, "##swing", tonumber(STATE.trswing), 0, 100, trSliderText)
  reaper.ImGui_PopStyleColor(ctx, 14)
  -----------------------------------------------------------------------------------

  prjSwing = tonumber(prjSwing)       -- get tonumber prj swing
  if prjSwing ~= lastprjSwing then    -- if prj swing has been updated
    debug("prj swing updated: " .. prjSwing,1)
    reaper.GetSetProjectGrid(0, 1, null, 1, prjSwing/100)    -- set grid swing to slider value
    reaper.SetProjExtState(0, "crabSwingGrid", 1, prjSwing)  -- set project extstate
    lastprjSwing = prjSwing           -- do once
  end
  
  if prjDiv ~= lastprjDiv then    -- if prj swing has been updated
    debug("prj div updated: " .. prjDiv,1)
    reaper.GetSetProjectGrid(0, 1, prjDiv, 1, null)    -- set grid to div value
    reaper.SetProjExtState(0, "crabSwingDiv", 1, prjDiv)  -- set project extstate
    lastprjDiv = prjDiv           -- do once
  end

  if clear then                                   -- if 'clear' button was pressed
    update = 1                                    -- update values, clear extstates
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", "", true)
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", "", true)
  end
    
  --------------------------------------------------------------------------------
                        -- check GRID table for user input
  for i = 1, 8 do 
    if GRID[i] then 
      trDiv = 1/(2^i/2)       -- 1/4, 1/8, 1/16, 1/32, etc
    end 
  end
  for i = 1, 4 do 
    if trTripletGrid[i] then   
      trDiv = (1/6)*.5^(i-1)  -- .1/4T, .1/8T, .1/16T, .1/32T
    end 
  end
  ---------------------------------------------------------------------------------
  
  if trDiv ~= prevtrDiv and trDiv ~= "" then     -- if there's a new trDiv value
    prevtrDiv = trDiv
    if trSwing == "" then
      STATE.trswing = prjSwing    -- update slider
      trSwing = prjSwing          -- update value
    end
    debug("trDiv updated: " .. trDiv,1)
    reaper.GetSetProjectGrid(0, 1, tonumber(trDiv), 1, null) 
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", tostring(trDiv), true)
  end
  
  if STATE.trswing ~= lasttrSwing then   -- if slider value is different from prev slider value, 
    if trDiv == "" then
      trDiv = prjDiv
      reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_grid", tostring(trDiv), true)
      update = 1
    end
    debug("track swing/extstate updated: " .. lasttrSwing .. " to " .. STATE.trswing,1)
    reaper.GetSetProjectGrid( 0, 1, null, 1, STATE.trswing/100 )    -- set grid swing to slider value
    reaper.GetSetMediaTrackInfo_String(STATE.editing_track, "P_EXT:custom_swing", tostring(STATE.trswing), true)
    lasttrSwing = STATE.trswing                                     -- do once
  end
  
  -----------------------------------------------------------------------------------
  ------------- UI objects - project-------------------------------------------------
  -----------------------------------------------------------------------------------
  ImGui.SeparatorText(ctx, "")       
  prjName = reaper.GetProjectName(0)     -- print track whose grid is being customized
  if prjName == "" then prjName = "unsaved project" end  
  ImGui.Text( ctx, "PROJECT: '" .. prjName .. "'") 
  
  ImGui.SameLine(ctx, 301.0, -1.0)       -- debug button
  dbgButton = ImGui.Button(ctx, "debug##dbg",  0.0, 0.0) 
  if dbgButton then          
    if dbg == false then dbg = true 
      debug("mccrabney - Per-track custom swing and grid",1)
      debug("~~~ debug messaging on ~~~",1)
    else 
      if reaper.GetToggleCommandState(42663) == 1 then 
        reaper.Main_OnCommand(42663, 0)
      end
      dbg = false 
    end
  end
  
  for i = 1, 8 do      -- cycle through PROJECT buttons and control their color & status
    if prjDiv == .5^(i-1) then prjCOLOR[i] = buttonOnColor else prjCOLOR[i] = buttonOffColor end 
  end 
  if prjDiv and math.floor(prjDiv*1000+.5)/1000 == .167 then prjCOLOR[3] = buttonOnColor prjCOLOR[9]  = buttonOnColor prTripletGrid[9]  = 1 else prjCOLOR[9]  = buttonOffColor prTripletGrid[9]  = 0 end
  if prjDiv and math.floor(prjDiv*1000+.5)/1000 == .083 then prjCOLOR[4] = buttonOnColor prjCOLOR[10] = buttonOnColor prTripletGrid[10] = 1 else prjCOLOR[10] = buttonOffColor prTripletGrid[10] = 0 end
  if prjDiv and math.floor(prjDiv*1000+.5)/1000 == .042 then prjCOLOR[5] = buttonOnColor prjCOLOR[11] = buttonOnColor prTripletGrid[11] = 1 else prjCOLOR[11] = buttonOffColor prTripletGrid[11] = 0 end
  if prjDiv and math.floor(prjDiv*1000+.5)/1000 == .021 then prjCOLOR[6] = buttonOnColor prjCOLOR[12] = buttonOnColor prTripletGrid[12] = 1 else prjCOLOR[12] = buttonOffColor prTripletGrid[12] = 0 end
  
  ------------------------------------- project settings buttons/slider
  for i = 1, 8 do                    -- transparent if empty table values
    if prjCOLOR[i] == nil then prjCOLOR[i] = 0x00000000 end
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[i])
    local txt = "1"
    if i == 8 then txt = "" end
    prGrid[i] = ImGui.Button(ctx, txt .. "/" .. tostring(math.tointeger(2^(i-1))) .. "##prDiv",  35, 25)
    if i < 8 then ImGui.SameLine(ctx, 0.0, -1.0)end
  end
  
  _ = ImGui.InvisibleButton(ctx, " ",  78, 15) ImGui.SameLine(ctx, 0.0, -1.0)
  
  for i = 1, 4 do
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), prjCOLOR[i+8])
    prTripletGrid[i] = ImGui.Button(ctx, "•##prDiv"..i,  35, 15) 
    if i < 4 then ImGui.SameLine(ctx, 0.0, -1.0) end
  end
  
  reaper.ImGui_SetNextItemWidth( ctx, 336)  -- prj swing slider
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), 0x42ddf5AA)
  _, prjSwing = reaper.ImGui_SliderDouble(ctx, "##prjswing", tonumber(prjSwing), 0, 100, "prj swing: %.0f%%")
  reaper.ImGui_PopStyleColor(ctx, 13)
  
  for i = 1, 8 do           -- check GRID table for user input
    if prGrid[i] then       -- set prj grid to specified division  
      prjDiv = 1/(2^i/2)    -- get sensible grid division from integer
    end
  end
  
  for i = 1, 4 do           -- check GRID table for user input
    if prTripletGrid[i] then       -- set prj grid to specified division  
      if i == 1 then prjDiv = 1/6 return end
      if i == 2 then prjDiv = 1/12 end
      if i == 3 then prjDiv = 1/24 end
      if i == 4 then prjDiv = 1/48 end
    end
  end
end

--


------------------
-- RUN
---------------------
function Run()
  
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


