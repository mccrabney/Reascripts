--[[
 * ReaScript Name: mccrabney_anacrustacean - region-based track MIDI 
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.01
--]]
 
--[[
 * Changelog:
 * v1.01 (2026-06-10)
  + fixed bug where last noteoff wasn't being referenced and dangling notes were truncated in some circumstances
 * v1.00 (2025-11-23)
  + initial release  
--]]

--[[
    anacrustacean - region-based track MIDI. 
    an attempt to support anacrusis, note dangle, and to solve the infinite note length overdub bug.
    
    disclaimer: this script will glue MIDI items and change their start and endpoints. 
    it does not currently support stacked takes, fixed lanes, overlapping regions, MIDI CC data, or looped source content.
    
    this script implements MPC-style sequence-based MIDI tracks using project regions.
    
    each "sequence" exists as a region-sized MIDI item containing all MIDI notes that begin in-region.
    notes that begin in one region (A) and end in another (B) are fully contained in sequence/item/region A.
    
    when OVERDUB is engaged, this script glues all track MIDI contained within adjacent regions
     
    for example, this structure:        [intro][verse][chorus][verse][chorus][bridge][chorus][outro] 
    temporarily becomes this structure: [intro  verse  chorus  verse  chorus  bridge  chorus  outro]
    
    this allows notes to be overdubbed without being interrupted/ended by existing item end-bounds:
    anacrusis and strummed chords are preserved when recording notes across items/sequences
    
    when OVERDUB is disengaged, the resulting MIDI item is resplit per region, enclosing MIDI that starts in-region.
    if a note transverses regions, items are smart-split, and the note is allowed to dangle into the next sequence.
--]]

local _, _, sec, cmd = reaper.get_action_context()
local overdub = 0        -- relevant playstate
regionSplitTable = {}    -- ppq values at which to split item

------------------------------------------------------------
-- build a table of region bounds     ----------------------
function getRegionTable(item)             
  local numRegions = 0
  local regions = {}
  local fail = 0
  local mrk_cnt = reaper.CountProjectMarkers(0)   -- how many markers in project
  if mrk_cnt and mrk_cnt ~= 0 then    -- if marker objectss,
    for i = 0, mrk_cnt-1 do           -- for each marker object
      local _, isrgn, pos, rgnend, markerName, index = reaper.EnumProjectMarkers(i) -- get data from each marker
      if isrgn == true then
        numRegions = numRegions + 1
        regions[numRegions] = {pos, rgnend}  -- region start/end pos in seconds
      end
    end
  end
  for i = 1, #regions do
    if i + 1 < #regions and (math.floor(regions[i][2]*1000))/1000 ~= (math.floor(regions[i+1][1]*1000))/1000 then
      fail = 1
    end
  end
  return regions, fail
end

------------------------------------------------------------
---- split table ----------------------------------------------
function split(track)
  countTrItem = reaper.CountTrackMediaItems(track)
  for t = countTrItem-1, 0, -1 do                       -- for each item, last to first
    local item = reaper.GetTrackMediaItem(track, t)      
    local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    if itemPos >= regionTable[1][1] and itemPos < regionTable[#regionTable][2] then  -- if w/in full region bounds
      local take = reaper.GetActiveTake(item)       
      if reaper.TakeIsMIDI(take) then 
        for i = #regionSplitTable, 1, -1 do           -- for each entry in table, last to first
          reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', i, 1)     -- name each MIDI item
          reaper.SplitMediaItem(item, reaper.MIDI_GetProjTimeFromPPQPos(take, regionSplitTable[i])) -- split 
        end                  
      end
    end
  end
end

----------------------------------------------------------
--------------------------------------------------------------
function Main()
  local selTrack = reaper.GetSelectedTrack(0,0);   -- works on first selected track
  local playState = reaper.GetPlayState()          
  if selTrack then
    local _, trName = reaper.GetTrackName(selTrack)
    if string.match(trName, "ch 0") or string.match(trName, "sequencer") then
    -------------------------------------------------------------------
    -- IF OVERDUB ENGAGED ---------------------------------------------
      if playState == 5 then               -- if overdub
        if overdub == 0 then               -- if overdub was off and is turning on
          overdub = 1                      -- overdub engaged
          regionTable, fail = getRegionTable()   -- create a table of region start/ends, to be edited if trans-note
          ogRgnTable = getRegionTable()    -- create a duplicate table of region start/ends as reference
          skipStart = 0
          skipEnd = 0
          reaper.Main_OnCommand(40289, 0)  -- deselect all items
          local countTrItem = reaper.CountTrackMediaItems(selTrack)
          if fail == 0 then  -- if regions are adjacent
            -- [[-------------------------------------------------------------        
            -- split off MIDI items before and after region-sequence block ---
            for p = 0, countTrItem-1 do  -- for each item, first to last
              local item = reaper.GetTrackMediaItem(selTrack, p)
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
            
            --]]------------------------------------------------------------- 
            -- create one big intra-region MIDI item
            countTrItem = reaper.CountTrackMediaItems(selTrack) -- refresh
            for r = 1, #regionTable do       -- for each region
              if r == 1 then                 -- if the first region
                for p = 0, countTrItem-1 do  -- for each item, first to last
                  local item = reaper.GetTrackMediaItem(selTrack, p)
                  local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                  local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                  local itemEnd = itemPos + itemLength
                  if itemPos == regionTable[r][1] then       -- if itempos matches first region startpos
                    skipStart = 1            -- skip new item creation
                  end 
                end -- for each item
                if skipStart == 0 then        -- drop midi item at first region start
                  reaper.CreateNewMIDIItemInProj(selTrack, regionTable[r][1], regionTable[r][1]+1)
                end -- if not skipping dummy item creation
              end -- if first region  
              
              if r == #regionTable then       -- if the last region
                for p = 0, countTrItem-1 do   -- for each item, first to last
                  local item = reaper.GetTrackMediaItem(selTrack, p) 
                  local itemEnd = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH') 
                  if itemEnd == regionTable[r][2] then      -- if itemendpos matches last region endpos
                    skipEnd = 1
                  end
                end -- for each item
                if skipEnd == 0 then          -- drop midi item at last region end
                  reaper.CreateNewMIDIItemInProj(selTrack, regionTable[r][2]-1, regionTable[r][2])
                end -- if not skipping dummy item creation
              end -- if last region
            end -- for each region
            
            countTrItem = reaper.CountTrackMediaItems(selTrack)
            if #regionTable ~= 0 then         -- if there is at least one region
              for i = 0, countTrItem-1 do     -- for each item, first to last
                local item = reaper.GetTrackMediaItem(selTrack, i)      
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
          end -- do once
        end
      -------------------------------------------------------------------
      -- IF OVERDUB DISENGAGED ------------------------------------------
      else                                             -- if not overdub
        if overdub == 1 and fail == 1 then             -- if overdubbing with non-contiguous regions, reset overdub flag
          reaper.ShowConsoleMsg("non-contiguous regions: anacrustacean skipped" .. "\n")
          overdub = 0
        end
        if overdub == 1 and #regionTable ~= 0 and fail ~= 1 then     -- if overdub was on and is turning off
          overdub = 0                                  -- do once
          totalMIDIEvts = 0
          ---------------------------------------------------------------
          -- FLAG EACH REGION'S START POINT and then SPLIT --------------
          countTrItem = reaper.CountTrackMediaItems(selTrack)  -- refresh item count
          for t = 0, countTrItem-1 do         -- for each item, first to last            
            local item = reaper.GetTrackMediaItem(selTrack, t)      
            local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            local itemEnd = itemPos + itemLength
            if itemPos >= regionTable[1][1] and itemPos < regionTable[#regionTable][2] then  -- if within region bounds
              local take = reaper.GetActiveTake(item)       
              if reaper.TakeIsMIDI(take) then 
                local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
                totalMIDIEvts = numNotes + numCCs -- get count of MIDI events 
                for j = #regionTable, 1, -1 do    -- for each region, last to first
                  local lastendppqpos = -1
                  --reaper.ShowConsoleMsg("j: " .. j .. "\n")
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
                      
                      --if p+1 <= numNotes then
                      --  local _, _, _, nextstartppqpos, nextendppqpos = reaper.MIDI_GetNote(take, p+1)
                      --  if endppqpos > nextstartppqpos and endppqpos <= nextendppqpos then 
                      --    endppqpos = nextendppqpos
                      --  end
                      --end
                    end
                  end -- for each note
                  if lastendppqpos ~= -1 then
                    regionTable[j][1] = reaper.MIDI_GetProjTimeFromPPQPos(take, lastendppqpos)   -- change split point to note end
                  end
                  --reaper.ShowConsoleMsg(transNote .. "\n")
                  regionSplitTable[j] = reaper.MIDI_GetPPQPosFromProjTime(take, regionTable[j][1])
                end -- for each region
              local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
              end -- if take is MIDI
            end -- if within region bounds
          end -- for each item
          split(selTrack)  -- split MIDI item at region points (or trans-region note end)

          ----------------------------------------------------------------
          -- [[--- if there is a trans-region note, accommodate dangle -------
          countTrItem = reaper.CountTrackMediaItems(selTrack)  -- refresh item count
          for j = #ogRgnTable, 1, -1 do          -- for each original region, last to first
            for t = countTrItem-1, 0, -1 do      -- for each item, last to first
              local item = reaper.GetTrackMediaItem(selTrack, t)
              local take = reaper.GetActiveTake(item)
              local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', 0)  
              if reaper.TakeIsMIDI(take) then  
                if tonumber(itemName) == j then   -- if MIDI item name matches the region
                  local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                  local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                  local itemEnd = itemPos + itemLength
                                                  -- if there is a trans-region note and thus a changed itemPos
                  --if itemPos ~= ogRgnTable[j][1] then
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
                    itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')     -- new val
                    itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')    -- new val
                    itemEnd = itemPos + itemLength                                  -- new val
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
                        local nextTake = reaper.GetActiveTake(reaper.GetTrackMediaItem(selTrack, t+1))
                        local _, nextItemName = reaper.GetSetMediaItemTakeInfo_String(nextTake, 'P_NAME', '', 0)  
                                                          -- whip that note into the next item where it belongs
                        reaper.MIDI_InsertNote(nextTake, selected, muted, startppqpos-rgnLength, endppqpos-rgnLength, chan, pitch, vel)
                        reaper.MIDI_DeleteNote(take, p)
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
          
          --]]--------------------------------------------------------------------
          ---- if some midi data exists on track, crop empty MIDI items --------
          countTrItem = reaper.CountTrackMediaItems(selTrack)   -- refresh item count
          for j = countTrItem-1, 0, -1 do                       -- for each item, last to first              
            local item = reaper.GetTrackMediaItem(selTrack, j)      
            local itemPos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local itemLength = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            local itemEnd = itemPos + itemLength
            if itemPos >= regionTable[1][1] and itemEnd <= regionTable[#regionTable][2] then  -- if w/in all region bounds
              local take = reaper.GetActiveTake(item)       
              if reaper.TakeIsMIDI(take) then
                local _, numNotes, numCCs = reaper.MIDI_CountEvts(take)
                if totalMIDIEvts ~= 0 and numNotes == 0 and numCCs == 0 then  -- if no notes, no ccs
                  reaper.DeleteTrackMediaItem(selTrack, item)     -- crop empty MIDI items on track
                end -- if empty midi item
              end -- if take is MIDI
            end -- if item is within all region bounds
          end -- for each item
          reaper.UpdateArrange()
          --]]-------------------------------------------------------------
        end -- do once
      end -- if playstate not overdub
    end -- if proper track
  end -- if a track is selected
  reaper.defer(Main)
end -- main function

function Exit()
  reaper.SetToggleCommandState(sec, cmd, 0)
  reaper.RefreshToolbar2(sec, cmd)
end

reaper.SetToggleCommandState(sec, cmd, 1)
reaper.RefreshToolbar2(sec, cmd)
reaper.atexit(Exit)
Main()
