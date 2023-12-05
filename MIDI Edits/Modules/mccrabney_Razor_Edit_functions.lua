-----------------------------------------------------------
    --[[------------------------------[[--
         razor edit functions - thanks, BirdBird
    --]]------------------------------]]--
    

function RazorEditSelectionExists()
 
  for i = 0, reaper.CountTracks(0)-1 do          -- for each track, check if RE is present
    local retval, x = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0,i), "P_RAZOREDITS", "string", false)
    if x ~= "" then return true end              -- if present, return true 
    if x == nil then return false end            -- return that no RE exists
  end
  
end    


function GetRazorEdits()
  local trackCount = reaper.CountTracks(0)
  local areaMap = {}
  for i = 0, trackCount - 1 do
    local track = reaper.GetTrack(0, i)
    local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    if area ~= '' then            --PARSE STRING
      local str = {}
      for j in string.gmatch(area, "%S+") do table.insert(str, j) end
      local j = 1
      while j <= #str do                --area data
        local areaStart = tonumber(str[j])
        local areaEnd = tonumber(str[j+1])
        local GUID = str[j+2]
        local isEnvelope = GUID ~= '""'
        local items = {}            --get item/envelope data
        local envelopeName, envelope
        local envelopePoint
        if not isEnvelope then
          items = GetItemsInRange(track, areaStart, areaEnd)
        else
          --envelope = reaper.GetTrackEnvelopeByChunkName(track, GUID:sub(2, -2))
          --local ret, envName = reaper.GetEnvelopeName(envelope)
          --envelopeName = envName
          --envelopePoints = GetEnvelopePointsInRange(envelope, areaStart, areaEnd)
        end

        local areaData = {
          areaStart = areaStart,  areaEnd = areaEnd,
          track = track,  items = items,
          isEnvelope = isEnvelope,    --envelope data
          envelope = envelope,  envelopeName = envelopeName,
          envelopePoints = envelopePoints,  GUID = GUID:sub(2, -2)
        }

        table.insert(areaMap, areaData)
        j = j + 3
      end
    end
  end

  return areaMap
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          Get Items, envelope points in Range -- thanks, BirdBird and amagalma!          
    --]]------------------------------]]--

local function leq( a, b ) -- a less than or equal to b
  return a < b + 0.00001
end

local function geq( a, b ) -- a greater than or equal to b
  return a + 0.00001 > b 
end

function GetItemsInRange(track, areaStart, areaEnd)
  local items, it = {}, 0
  for k = 0, reaper.CountTrackMediaItems(track) - 1 do 
    local item = reaper.GetTrackMediaItem(track, k)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemEndPos = pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        --check if item is in area bounds
    if geq(pos, areaEnd) or leq(itemEndPos, areaStart) then
      -- outside, do nothing
    else -- inside
      it = it + 1
      items[it] = item
    end
  end
  return items
end

---------------------------------------------------------------------
    --[[------------------------------[[--
          Set Track Razor Edit -- thanks, BirdBird!          
    --]]------------------------------]]--

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
