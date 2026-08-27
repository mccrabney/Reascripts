--[[
 * ReaScript Name: Clicker
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.03
--]]

--[[
 * Changelog:
 * v1.03 (08-27-2026)
   + heartbeat detector for Fiddler (run invisibly if Fiddler is not running)
 * v1.02 (08-22-2026)
   + comment out profiler, added howto comments, cleaned up unused variables
 * v1.01 (08-22-2026)
   + fixed bug where clicking another item doesn't deselect notes on prev selected items
 * v1.00 ()
   + initial release
--]]
 
-- discussion thread: https://forum.cockos.com/showthread.php?t=274257

-- HOW TO USE:
-- run this defer script alongside Fiddler.
-- click on MIDI notes to select them one at a time. ctrl-click to add/subtract notes to selection
-- click empty space to deselect all.
-- you may need to adjust your ctrl-click media item mouse modifier to avoid changing item selection

--local profiler = dofile(reaper.GetResourcePath() ..
--  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
--reaper.defer = profiler.defer

reaper.set_action_options(1)
local extName = 'mccrabney_Fiddler (arrange screen MIDI editing).lua'
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
require("Modules/Sexan_Area_51_mouse_mccrabney_tweak")

  
function getNotesUnderMouseCursor()
  guidString = reaper.GetExtState(extName, 3 )
  take = reaper.SNM_GetMediaItemTakeByGUID( 0, guidString )
  targetNoteIndex = tonumber(reaper.GetExtState(extName, 5 ))
  return take, targetNoteIndex
end  
-------------------------------------------
--local fiddlerStatus = 0
function Main()
  mouse = MouseInfo()
  
  if mouse.l_click then                             -- on click, 
    localTime = reaper.time_precise()               -- check time
    if reaper.HasExtState(extName, 'time') then     -- check Fiddler heartbeat, report status
      heartbeat = tonumber(reaper.GetExtState(extName, 'time', 1))
      if localTime-heartbeat < 1 then fiddlerStatus = 1 else fiddlerStatus = 0 end
    end  
    take, targetNoteIndex = getNotesUnderMouseCursor()
    track, window = reaper.GetThingFromPoint(mouse.x, mouse.y)
    cursorPos = mouse.p
  end
 
  if track and mouse.l_click and fiddlerStatus == 1 and window == "arrange" then    -- if a click event occurs on a track in arrange
    local mouse_keyboard_state = reaper.JS_Mouse_GetState(-1)
    local keyboard_modifiers = mouse_keyboard_state & 60
    local ctrl = keyboard_modifiers == 4
    local CountTrItem = reaper.CountTrackMediaItems(track)   -- count track items
    local tk
    if CountTrItem then                             -- if track has items

      if take ~= lastTake and not ctrl then         -- if clicked on different take and ctrl not held,
        for i = 0, CountTrItem-1 do                 -- for each item,               
          local item = reaper.GetTrackMediaItem(track, i)  -- get each item
          local tk = reaper.GetActiveTake(item)     -- get the take
          if tk and reaper.TakeIsMIDI(tk) then      -- if take not nil and is MIDI
            reaper.MIDI_SelectAll(tk, 0)            -- deselect all notes
          end -- if take not nil
        end -- for each item
        lastTake = take
      end
      
      for i = 0, CountTrItem-1 do                       -- for each item, first to last           
        local item = reaper.GetTrackMediaItem(track,i)  -- get each item start and endpoints
        local itemStart = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
        if itemStart <= cursorPos and itemEnd > cursorPos then  -- if mouse cursor is within item bounds,
          local tk = reaper.GetTake(item, 0)            -- get the take
          if tk and reaper.TakeIsMIDI(tk) then mouseTake = tk end  -- if MIDI, assign mouseTake
        end -- if cursor in item bounds
      end -- for each item
 
      if targetNoteIndex == -1 then                 -- if there's no target note under the mouse cursor,
        for i = 0, CountTrItem-1 do                 -- for each item,               
          local item = reaper.GetTrackMediaItem(track, i)  -- get each item
          local tk = reaper.GetActiveTake(item)     -- get the take
          if tk and reaper.TakeIsMIDI(tk) then      -- if take not nil and is MIDI
            reaper.MIDI_SelectAll(tk, 0)            -- deselect all notes
          end -- if take not nil
        end -- for each item
        reaper.Undo_OnStateChange2(proj, "deselected all MIDI notes")
      end -- if no target note

      if mouseTake and mouseTake == take and targetNoteIndex ~= -1 then   -- if mouseTake = fiddler take and there is a target note
        if reaper.TakeIsMIDI(mouseTake) then                -- and if it's MIDI
          local _, sel, _, _, _, _, pitch = reaper.MIDI_GetNote(mouseTake, targetNoteIndex)  -- get targetnote
          if ctrl then
            if sel == false then                                            -- if targetnote is not selected
              reaper.MIDI_SetNote(mouseTake, targetNoteIndex, true)         -- set it to true
              reaper.Undo_OnStateChange2(proj, "selected note " .. pitch)
            else                                                            -- if not
              reaper.MIDI_SetNote(mouseTake, targetNoteIndex, false)        -- set it to false
              reaper.Undo_OnStateChange2(proj, "deselected note " .. pitch)
            end -- if targetnote selected
          else
            for i = 0, CountTrItem-1 do                         -- for each item,               
              local item = reaper.GetTrackMediaItem(track, i)  -- get each item
              local tk = reaper.GetActiveTake(item)      -- get the take
              if tk ~= mouseTake and reaper.TakeIsMIDI(tk) then -- if take not nil and is MIDI
                if reaper.MIDI_EnumSelNotes(tk, 0) ~= -1 then
                  reaper.MIDI_SelectAll(tk, 0)                  -- deselect all notes
                end
              elseif tk == mouseTake then                       -- if take not nil
                reaper.MIDI_SelectAll(tk, 0)                    -- deselect all notes
              end
            end -- for each item
            reaper.Undo_OnStateChange2(proj, "deselected all MIDI notes")
          end
          if targetNoteIndex ~= -1 and not ctrl then
            reaper.MIDI_SetNote(mouseTake, targetNoteIndex, true)         -- set it to true
            reaper.Undo_OnStateChange2(proj, "selected note " .. pitch)
          end
        end -- if take is MIDI
      end -- if take
    end -- if track has items
  end -- if click event occurs

  reaper.defer(Main)
end

Main()

--profiler.attachToWorld() -- after all functions have been defined
--profiler.run()

