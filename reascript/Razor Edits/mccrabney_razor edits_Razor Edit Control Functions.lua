--[[
 * ReaScript Name: Razor Edit Control Functions
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2021-03-22)
   + Initial Release
--]]


    --[[------------------------------[[--
     Event trigger params from child scripts          
    --]]------------------------------]]--


function SetGlobalParam(val, param, incr)
    reaper.ClearConsole()
    if param  < 2 then resizeREbyVisibleGrid(param, incr) end
    if param == 2 then moveREbyVisibleGrid(incr) end
    if param == 3 then resizeREvertically(incr) end
    if param == 4 then moveREwithcursor(incr) end
    
end

---------------------------------------------------------------------

    
    --[[------------------------------[[--
          FTC Razor Edit functions       --thanks, FTC!   
    --]]------------------------------]]--

function literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

function GetGUIDFromEnvelope(envelope)
    local ret2, envelopeChunk = reaper.GetEnvelopeStateChunk(envelope, "")
    local GUID = "{" ..  string.match(envelopeChunk, "GUID {(%S+)}") .. "}"
    return GUID
end

---------------------------------------------------------------------

function GetItemsInRange(track, areaStart, areaEnd)
    local items = {}
    local itemCount = reaper.CountTrackMediaItems(track)
    for k = 0, itemCount - 1 do 
        local item = reaper.GetTrackMediaItem(track, k)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEndPos = pos+length

        --check if item is in area bounds
        if (itemEndPos > areaStart and itemEndPos <= areaEnd) or
            (pos >= areaStart and pos < areaEnd) or
            (pos <= areaStart and itemEndPos >= areaEnd) then
                table.insert(items,item)
        end
    end

    return items
end

---------------------------------------------------------------------

function GetEnvelopePointsInRange(envelopeTrack, areaStart, areaEnd)
    local envelopePoints = {}

    for i = 1, reaper.CountEnvelopePoints(envelopeTrack) do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelopeTrack, i - 1)

        if time >= areaStart and time <= areaEnd then --point is in range
            envelopePoints[#envelopePoints + 1] = {
                id = i-1 ,
                time = time,
                value = value,
                shape = shape,
                tension = tension,
                selected = selected
            }
        end
    end

    return envelopePoints
end

---------------------------------------------------------------------

function SetTrackRazorEdit(track, areaStart, areaEnd, clearSelection)
    if clearSelection == nil then clearSelection = false end
    
    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string, all this string stuff could probably be written better
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the track
        local j = 1
        while j <= #str do
            local GUID = str[j+2]
            if GUID == '""' then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit 
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ""'
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. '  ""'
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
end

---------------------------------------------------------------------

function SetEnvelopeRazorEdit(envelope, areaStart, areaEnd, clearSelection, GUID)
    local GUID = GUID == nil and GetGUIDFromEnvelope(envelope) or GUID
    local track = reaper.Envelope_GetParentTrack(envelope)

    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the envelope
        local j = 1
        while j <= #str do
            local envGUID = str[j+2]
            if GUID ~= '""' and envGUID:sub(2,-2) == GUID then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ' .. GUID
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)

        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ' .. GUID
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
end

---------------------------------------------------------------------

function GetRazorEdits()
    local trackCount = reaper.CountTracks(0)
    local areaMap = {}
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        if area ~= '' then
            --PARSE STRING
            local str = {}
            for j in string.gmatch(area, "%S+") do
                table.insert(str, j)  
            end
        
            --FILL AREA DATA
            local j = 1
            while j <= #str do
                --area data
                local areaStart = tonumber(str[j])
                local areaEnd = tonumber(str[j+1])
                local GUID = str[j+2]
                local isEnvelope = GUID ~= '""'

                --get item/envelope data
                local items = {}
                local envelopeName, envelope
                local envelopePoints
                
                if not isEnvelope then
                    items = GetItemsInRange(track, areaStart, areaEnd)
                else
                    envelope = reaper.GetTrackEnvelopeByChunkName(track, GUID:sub(2, -2))
                    local ret, envName = reaper.GetEnvelopeName(envelope)

                    envelopeName = envName
                    envelopePoints = GetEnvelopePointsInRange(envelope, areaStart, areaEnd)
                end

                local areaData = {
                    areaStart = areaStart,
                    areaEnd = areaEnd,
                    
                    track = track,
                    items = items,
                    
                    --envelope data
                    isEnvelope = isEnvelope,
                    envelope = envelope,
                    envelopeName = envelopeName,
                    envelopePoints = envelopePoints,
                    GUID = GUID:sub(2, -2)
                }

                table.insert(areaMap, areaData)

                j = j + 3
            end
        end
    end

    return areaMap
end

---------------------------------------------------------------------

function SplitRazorEdits(razorEdits)
    local areaItems = {}
    local tracks = {}
    reaper.PreventUIRefresh(1)
    for i = 1, #razorEdits do
        local areaData = razorEdits[i]
        if not areaData.isEnvelope then
            local items = areaData.items
            
            --recalculate item data for tracks with previous splits
            if tracks[areaData.track] ~= nil then 
                items = GetItemsInRange(areaData.track, areaData.areaStart, areaData.areaEnd)
            end
            
            for j = 1, #items do 
                local item = items[j]
                --split items 
                local newItem = reaper.SplitMediaItem(item, areaData.areaStart)
                if newItem == nil then
                    reaper.SplitMediaItem(item, areaData.areaEnd)
                    table.insert(areaItems, item)
                else
                    reaper.SplitMediaItem(newItem, areaData.areaEnd)
                    table.insert(areaItems, newItem)
                end
            end

            tracks[areaData.track] = 1
        end
    end
    reaper.PreventUIRefresh(-1)
    
    return areaItems
end

---------------------------------------------------------------------

    
    --[[------------------------------[[--
          Does a Razor Edit exist? thanks, sonictim!          
    --]]------------------------------]]--

function RazorEditSelectionExists()

    for i=0, reaper.CountTracks(0)-1 do

        local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)

        if x ~= "" then return true end

    end--for
    
    return false

end--RazorEditSelectionExists()

---------------------------------------------------------------------


    --[[------------------------------[[--
         Get Visible Grid Division - thanks, amagalma!          
    --]]------------------------------]]--

function GetVisibleGridDivision()  ---- 
    reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
    reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
    local cursorpos = reaper.GetCursorPosition()
    local firstcursorpos = cursorpos
    local grid_duration
    
    if reaper.GetToggleCommandState( 41885 ) == 1 then -- Toggle framerate grid
        grid_duration = 0.4/reaper.TimeMap_curFrameRate( 0 )
    else
        local _, division = reaper.GetSetProjectGrid( 0, 0, 0, 0, 0 )
        local tmsgn_cnt = reaper.CountTempoTimeSigMarkers( 0 )
        local _, tempo
      
        if tmsgn_cnt == 0 then
            tempo = reaper.Master_GetTempo()
        else
            local active_tmsgn = reaper.FindTempoTimeSigMarker( 0, cursorpos )
            _, _, _, _, tempo = reaper.GetTempoTimeSigMarker( 0, active_tmsgn )
        end
        grid_duration = 60/tempo * division
    end
    
    local grid = cursorpos
    
    while (grid <= cursorpos) do
        cursorpos = cursorpos + grid_duration
        grid = reaper.SnapToGrid(0, cursorpos)
    end
    
    grid = grid-firstcursorpos
    reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
    --  reaper.defer(function() end)
    return grid

end -- GetVisibleGridDivision()  

---------------------------------------------------------------------


    --[[------------------------------[[--
     In/Decrement Razor Edit Start/End by Visible Grid     --mccrabney      
    --]]------------------------------]]--
    
function resizeREbyVisibleGrid(param, incr)    -- where param informs direction of movement
    gridval = GetVisibleGridDivision()
    
    if RazorEditSelectionExists() then
        local areas = GetRazorEdits()

        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart
            local aEnd = area.areaEnd

            if param == 0 then ---- if we are incrementing/decrementing RE end
                aEnd =  reaper.SnapToGrid(0, aEnd+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end
                end
            end    
            
            if param == 1 then ---- if we are incrementing/decrementing RE start
                aStart =  reaper.SnapToGrid(0, aStart+gridval*incr) --increment/decrement by grid
                if aEnd > aStart then
                    if area.isEnvelope then
                        SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
                    else
                        SetTrackRazorEdit(area.track, aStart, aEnd, true) 
                    end    
                end                                
            end --if param = 0
        end -- for
    else  -- RazorEditSelectionExists() -- create if not present  
         
        for i = 0, reaper.CountSelectedTracks(0)-1 do
            track = reaper.GetSelectedTrack(0, i)
            reaper.Main_OnCommand(40755, 0) -- Snapping: Save snap state
            reaper.Main_OnCommand(40754, 0) -- Snapping: Enable snap
            local cursorpos = reaper.GetCursorPosition()
            
            if param == 0 then 
                if incr == 1 then SetTrackRazorEdit(track, cursorpos, cursorpos+gridval, true) end 
            else
                if incr == -1 then SetTrackRazorEdit(track, cursorpos-gridval, cursorpos, true) end 
            end    
            
            reaper.Main_OnCommand(40756, 0) -- Snapping: Restore snap state
            -- reaper.defer(function() end)
        end
    end  -- RazorEditSelectionExists()
    --reaper.UpdateArrange() 
   -- reaper.defer(resizeREbyVisibleGrid)
end

---------------------------------------------------------------------


    --[[------------------------------[[--
        Move Razor Edit (and/or edit cursor) End by Visible Grid           
    --]]------------------------------]]--

function moveREbyVisibleGrid(incr)

    local direction = incr
    gridval = GetVisibleGridDivision()
    
    if RazorEditSelectionExists() then
        local test, position = GetRazorEdits()
        local areas = GetRazorEdits()
        
        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart 
            local aEnd = area.areaEnd
            local aLength = aEnd - aStart
            local cursorpos = reaper.GetCursorPosition()
            local grid=cursorpos
            aStart = reaper.SnapToGrid(0, aStart+gridval*incr)
            aEnd =  reaper.SnapToGrid(0, aEnd+gridval*incr)
            
            if area.isEnvelope then
                SetEnvelopeRazorEdit(area.envelope, aStart, aEnd, true)
            else
                SetTrackRazorEdit(area.track, aStart, aEnd, true)
                reaper.SetEditCurPos( aStart, true, false)
            end -- if area.isEnvelope
        end -- for
    else -- RazorEditSelectionExists( NO ):
        local cursorpos = reaper.GetCursorPosition()
        local grid = reaper.SnapToGrid(0, cursorpos+gridval*incr)
        reaper.SetEditCurPos(grid,1,1)
    end  
    reaper.UpdateArrange()
    
end
---------------------------------------------------------------------   


    --[[------------------------------[[--
        move RE and edit cursor forwards without contents 
    --]]------------------------------]]--


function moveREwithcursor(incr)

    local direction = incr
    if RazorEditSelectionExists() then
        if incr == 1 then reaper.Main_OnCommand(42399, 0) end -- move RE forwards without content
        if incr == -1 then reaper.Main_OnCommand(42400, 0) end -- backwards
                    
        
         
        local test, position = GetRazorEdits()
        local areas = GetRazorEdits()
        
        for i=1, #areas do
            local area = areas[i];
            local aStart = area.areaStart 
            reaper.SetEditCurPos(aStart,1,1)
        end -- for
        
    else -- RazorEditSelectionExists( NO ):
        --local cursorpos = reaper.GetCursorPosition()
        --local grid = reaper.SnapToGrid(0, cursorpos+gridval*incr)
        
    end  
    reaper.UpdateArrange()
    
end


---------------------------------------------------------------------   


    --[[------------------------------[[--
        move RE and edit cursor backwards without contents 
    --]]------------------------------]]--



---------------------------------------------------------------------   


    --[[------------------------------[[--
        resize RE vertically
    --]]------------------------------]]--




---------------------------------------------------------------------
    



   
    --[[------------------------------[[--
                MAIN
    --]]------------------------------]]--
    
function Main()
 -- reaper.defer(Main)
end

---------------------------------------------------------------------


    --[[------------------------------[[--
                loop
    --]]------------------------------]]--
    

Main()
