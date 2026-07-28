--[[
 * ReaScript Name: mccrabney_anacrustacean - region-based track MIDI 
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.02
--]]
 
--[[
 * Changelog:
 * v1.02 (2026-07-28)
  + fixed bug with crash if glued item is selected before overdub is disengaged
  + improve behavior when track is switched while overdub is engaged
  + consolidated undo points
  + eliminate trackname check, script now works on all tracks armed to a MIDI input
 * v1.01 (2026-06-10)
  + fixed bug where last noteoff wasn't being referenced and dangling notes were truncated in some circumstances
 * v1.00 (2025-11-23)
  + initial release  
--]]

--[[
    anacrustacean - region-based track MIDI. 
    an attempt to support anacrusis, note dangle, and to solve the infinite note length overdub bug.
    
  * disclaimer: this will modify track MIDI items and change their start and endpoints. 
    it does not currently support stacked takes, fixed lanes, overlapping regions, or looped source content.
  
    this script implements MPC-style sequence-based MIDI tracks using project regions.    
    each "sequence" exists as a region-sized MIDI item containing all MIDI notes that begin in-region.
    notes that begin in one region (A) and end in another (B) are fully contained in sequence/item/region A.
    
    when OVERDUB is engaged, this script glues all track MIDI contained within adjacent regions
     
    for example, this structure:        [intro][verse][chorus][verse][chorus][bridge][chorus][outro] 
    temporarily becomes this structure: [intro  verse  chorus  verse  chorus  bridge  chorus  outro]
    
    this allows notes to be overdubbed without being interrupted/ended by existing item end-bounds.
    
    when OVERDUB is disengaged, the resulting MIDI item is resplit per region, enclosing notes that starts in-region.
    if a note transverses a region end, items are smart-split, and the note is dangled into the next sequence.
--]]


--local profiler = dofile(reaper.GetResourcePath() ..
--  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
--reaper.defer = profiler.defer

reaper.set_action_options(1)
local _, _, sec, cmd = reaper.get_action_context()

------------------------------------------------------------
-- build a table of region bounds --------------------------
function getRegionTable(item)             
  reaper.ClearConsole()
  local numRegions = 0
  local regions = {}
  local mrk_cnt = reaper.CountProjectMarkers(0)   -- how many markers in project
  if mrk_cnt and mrk_cnt ~= 0 then    -- if marker objects,
    for i = 0, mrk_cnt-1 do           -- for each marker object
      local _, isrgn, pos, rgnend, markerName, index = reaper.EnumProjectMarkers(i) -- get data from each marker
      if isrgn == true then
        numRegions = numRegions + 1
        regions[numRegions] = {pos, rgnend}  -- region start/end pos in seconds
      end
    end 
  end
  return regions
end

--------------------------------------------------------------- 
-- create one big intra-region MIDI item ------------------------
function trackMidi(track)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)       -- is this doing anything??
  local _, trName = reaper.GetTrackName(track)
  regionTable = getRegionTable()   -- create a global table of region start/ends, to be edited if trans-note
  ogRgnTable = getRegionTable()    -- create a duplicate global table of region start/ends as reference
  local skipStart = 0
  local skipEnd = 0
  local countTrItem = reaper.CountTrackMediaItems(track)
  reaper.Main_OnCommand(40289, 0)  -- deselect all items
    -- [[-------------------------------------------------------------        
    -- split off MIDI items before and after region-sequence block ---
  for p = 0, countTrItem-1 do  -- for each item, first to last
    local item = reaper.GetTrackMediaItem(track, p)
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local itemEnd = itemPos + itemLength
    local take = reaper.GetActiveTake(item)
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', 1)         -- strip names from items
    if itemPos < regionTable[1][1] and itemEnd > regionTable[1][1] then  -- if item reaches into 1st reg
      reaper.SplitMediaItem(item, regionTable[1][1])
    end                                                          
    if itemPos >= regionTable[1][1] and itemEnd > regionTable[#regionTable][2] then
      reaper.SplitMediaItem(item, regionTable[#regionTable][2])  -- split at last rgn end             
    end
  end -- for each item
  
  for r = 1, #regionTable do       -- for each region
    if r == 1 then                 -- if the first region
      for p = 0, countTrItem-1 do  -- for each item, first to last
        local item = reaper.GetTrackMediaItem(track, p)
        local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        local itemEnd = itemPos + itemLength
        if itemPos == regionTable[r][1] then       -- if itempos matches first region startpos
          skipStart = 1            -- skip new item creation
        end 
      end -- for each item
      if skipStart == 0 then        -- drop midi item at first region start
        reaper.CreateNewMIDIItemInProj(track, regionTable[r][1], regionTable[r][1]+1)
      end -- if not skipping dummy item creation
    end -- if first region  
    
    if r == #regionTable then       -- if the last region
      for p = 0, countTrItem-1 do   -- for each item, first to last
        local item = reaper.GetTrackMediaItem(track, p) 
        local itemEnd = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH') 
        if itemEnd == regionTable[r][2] then      -- if itemendpos matches last region endpos
          skipEnd = 1
        end
      end -- for each item
      if skipEnd == 0 then          -- drop midi item at last region end
        reaper.CreateNewMIDIItemInProj(track, regionTable[r][2]-1, regionTable[r][2])
      end -- if not skipping dummy item creation
    end -- if last region
  end -- for each region
  ---------------------------------------------------------------  
  countTrItem = reaper.CountTrackMediaItems(track)  -- refresh item count
  if #regionTable ~= 0 then         -- if there is at least one region
    for i = 0, countTrItem-1 do     -- for each item, first to last
      local item = reaper.GetTrackMediaItem(track, i)      
      local take = reaper.GetActiveTake(item)          
      if reaper.TakeIsMIDI(take) then 
        local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        if itemPos >= regionTable[1][1] and itemPos < regionTable[#regionTable][2] then  -- if within region bounds
          reaper.SetMediaItemSelected(item, true)  -- select items for gluing
        end -- if item is within marker bounds
      end -- if take midi 
    end  -- for each item
  end -- if there's at least one region
  ----------------------------------------------------------------
  if skipStart and skipEnd == 0 or countTrItem > 1  then -- if multiple items
    reaper.Main_OnCommand(40362, 0) -- glue all selected items
  end
  reaper.Main_OnCommand(40289, 0) -- deselect all items
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock( "glued MIDI on '" .. trName .. "'", 0 )
end

------------------------------------------------------------
---- split table  ---------------------------
function split(track)
  countTrItem = reaper.CountTrackMediaItems(track)
  for t = countTrItem-1, 0, -1 do                     -- for each item, last to first
    local item = reaper.GetTrackMediaItem(track, t)      
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    if itemPos >= regionTable[1][1] and itemPos < regionTable[#regionTable][2] then  -- if w/in full region bounds
      local take = reaper.GetActiveTake(item)       
      if reaper.TakeIsMIDI(take) then 
        for i = #regionSplitTable, 1, -1 do           -- for each entry in table, last to first
          reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', i, 1)     -- name each MIDI item
          reaper.SplitMediaItem(item, reaper.MIDI_GetProjTimeFromPPQPos(take, regionSplitTable[i])) -- split 
        end -- for each region in table
      end -- if take is midi
    end --if item is w/in region
  end -- for each item
end -- split table

--------------------------------------------------------------
-------- split at region divisions, accommodating anacrusis --
function sequence(track)
  reaper.SetOnlyTrackSelected(track)
  reaper.Main_OnCommand(40289, 0) -- deselect all items
  local countTrItem = reaper.CountTrackMediaItems(track)  -- refresh item count
  for t = 0, countTrItem-1 do         -- for each item, first to last            
    local item = reaper.GetTrackMediaItem(track, t)      
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local itemEnd = itemPos + itemLength
    if itemPos >= regionTable[1][1] and itemPos < regionTable[#regionTable][2] then  -- if within region bounds
      local take = reaper.GetActiveTake(item)       
      if reaper.TakeIsMIDI(take) then 
        local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
        for j = #regionTable, 1, -1 do    -- for each region, last to first
          local lastendppqpos = -1
          local transNote = 0
          rgnStartppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, regionTable[j][1]))
          rgnEndppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, regionTable[j][2]))
          for p = 0, numNotes, 1 do       -- for each note, first to last
            --reaper.ShowConsoleMsg("p: " .. p .. "\n")
            local _, _, _, startppqpos, endppqpos = reaper.MIDI_GetNote(take, p)
            startppqpos =  math.floor(startppqpos)
            endppqpos =  math.floor(endppqpos)
            local regionPosPpq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, regionTable[j][1]))
            if startppqpos < regionPosPpq and endppqpos > regionPosPpq then  -- if note trans region
              if endppqpos > lastendppqpos then 
                lastendppqpos = endppqpos 
              end -- get last noteoff pos
            end
          end -- for each note
          if lastendppqpos ~= -1 then
            regionTable[j][1] = reaper.MIDI_GetProjTimeFromPPQPos(take, lastendppqpos)   -- change split point to note end
          end
          regionSplitTable[j] = reaper.MIDI_GetPPQPosFromProjTime(take, regionTable[j][1])
        end -- for each region
      local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
      end -- if take is MIDI
    end -- if within region bounds
  end -- for each item
  split(track)  -- split MIDI item at region points
end
  
------------------------------------------------------------------
----- if there is a trans-region note, accommodate anacrusis -------
function dangle(track)
  local countTrItem = reaper.CountTrackMediaItems(track)  -- refresh item count
  for j = #ogRgnTable, 1, -1 do          -- for each original region, last to first
    for t = countTrItem-1, 0, -1 do      -- for each item, last to first
      local item = reaper.GetTrackMediaItem(track, t)
      local take = reaper.GetActiveTake(item)
      local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', 0)  
      if reaper.TakeIsMIDI(take) then  
        if tonumber(itemName) == j then   -- if MIDI item name matches the region
          local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
          local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
          local itemEnd = itemPos + itemLength
                                          -- if there is a trans-region note and thus a changed itemPos
          if math.floor(itemPos*1000) ~= math.floor(ogRgnTable[j][1]*1000) then
            reaper.SetMediaItemInfo_Value(item, 'D_POSITION', ogRgnTable[j][1])  -- move item to region start
            local comp = itemPos-ogRgnTable[j][1]                 -- calculate makeup distance
            reaper.SetMediaItemInfo_Value(item, 'B_LOOPSRC', 0)   -- force loop off for source
            reaper.SetMediaItemTakeInfo_Value(take, 'D_STARTOFFS', 0-comp)  -- makeup offset
            reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', itemLength+comp)    -- makeup length
            reaper.SetMediaItemSelected(item, true)  -- select items for gluing
            reaper.Main_OnCommand(40362, 0)          -- glue all selected items
            item = reaper.GetSelectedMediaItem(0, 0) -- get new item
            take = reaper.GetActiveTake(item)        -- get new take
            itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')     -- update val
            itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')    -- update val
            itemEnd = itemPos + itemLength                                  -- update val
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', j, 1)     -- name each MIDI item
            reaper.Main_OnCommand(40289, 0)          -- deselect all items
          end
          
          if itemEnd > ogRgnTable[j][2] then         -- if itemEnd is further than region end
            local lastendppqpos = -1
            local rgnStartppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, ogRgnTable[j][1]))
            local rgnEndppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, ogRgnTable[j][2]))
            local rgnLength = rgnStartppq + rgnEndppq
            local _, numNotes, _ = reaper.MIDI_CountEvts(take)
            local startppqpos, endppqpos = -1
            for p = numNotes, 0, -1 do      -- for each note, last to first
              local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, p)
              if startppqpos >= rgnEndppq and t+1 <= countTrItem then     -- if note starts after region end
                local nextTake = reaper.GetActiveTake(reaper.GetTrackMediaItem(track, t+1))
                local _, nextItemName = reaper.GetSetMediaItemTakeInfo_String(nextTake, 'P_NAME', '', 0)  
                reaper.MIDI_InsertNote(nextTake, selected, muted, startppqpos-rgnLength, endppqpos-rgnLength, chan, pitch, vel)
                reaper.MIDI_DeleteNote(take, p)       -- whip that note into the next item where it belongs, delete OG
              end -- if note starts after rgn end
              if endppqpos > lastendppqpos then 
                lastendppqpos = endppqpos 
              end -- get last noteoff pos
            end -- for each note
            
            if startppqpos < rgnEndppq and lastendppqpos > rgnEndppq then
              local newEndPos = reaper.MIDI_GetProjTimeFromPPQPos(take, lastendppqpos)
              local comp = newEndPos - ogRgnTable[j][2]
              reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', ogRgnTable[j][2]-itemPos+comp)    -- makeup length
            end
          end -- if itemEnd > rgn end
        end -- if item matches region
      end -- if take is MIDI
    end -- for each item
  end -- for each region
end

------------------------------------------------------
--- crop empty MIDI items ---------------------------
function crop(track)
  local countTrItem = reaper.CountTrackMediaItems(track)   -- refresh item count
  for j = countTrItem-1, 0, -1 do       -- for each item, last to first              
    local item = reaper.GetTrackMediaItem(track, j)      
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local itemEnd = itemPos + itemLength
    if itemPos >= regionTable[1][1] and itemEnd <= regionTable[#regionTable][2] then  -- if w/in all region bounds
      local take = reaper.GetActiveTake(item)       
      if reaper.TakeIsMIDI(take) then
        local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
        if numNotes == 0 and numCCs == 0 then  -- if no notes, no ccs
          reaper.DeleteTrackMediaItem(track, item)     -- crop empty MIDI items on track
        end -- if empty midi item
      end -- if take is MIDI
    end -- if item is within all region bounds
  end -- for each item
end

----------------------------------------------------------
------MAIN------------------------------------------------
local overdub = 0        -- initialize overdub flag
regionSplitTable = {}    -- ppq values at which to split item
function Main()
  local playState = reaper.GetPlayState()          
  local trName = ""
  if playState == 5 then               -- if overdub,
    if overdub == 0 then               -- if overdub flag was off and is turning on (do once)
      overdub = 1                      -- set overdub flag on
      local selTrack = reaper.GetSelectedTrack(0,0)
      local recInput = reaper.GetMediaTrackInfo_Value(selTrack, 'I_RECINPUT')
      local recArm = reaper.GetMediaTrackInfo_Value(selTrack, 'I_RECARM')
      _, trName = reaper.GetTrackName(selTrack)
      if recInput >= 4096 and recArm == 1 then    -- if selTrack rec input is MIDI track records MIDI  
        crabTrack = selTrack           -- identify track being prepared for when overdub disengages
        trackMidi(selTrack)            -- create one big intra-region MIDI item
      end -- if track is armed to a MIDI input
    end -- if overdub was off and is turning on
  else                                 -- if overdub disengaged
    if overdub == 1 and #regionTable ~= 0 then    -- if overdub was on and is turning off
      overdub = 0                      -- set overdub flag off
      reaper.PreventUIRefresh(1)
      reaper.Undo_BeginBlock()
      sequence(crabTrack)              -- split region-sized MIDI items
      dangle(crabTrack)                -- accommodate anacrusis
      crop(crabTrack)                  -- remove empty MIDI items
      reaper.Undo_EndBlock("split MIDI on '" .. trName .. "'", 0 )
      reaper.PreventUIRefresh(-1)
    end -- do once
  end -- if playstate not overdub
  reaper.defer(Main)
end -- main function
-------------------------------------------------------------

function Exit()
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(Exit)
Main()

--profiler.attachToWorld() -- after all functions have been defined
--profiler.run()

