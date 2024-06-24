--[[
 * ReaScript Name: swing grid automation
 * Author: mccrabney
 * Licence: GPL v3
 * REAPER: 7.0
 * Extensions: None
 * Version: 1.00
--]]

--[[ instructions: 
  
  run this script. a track called "swing grid" will be created. 
  use the envelope on this track to automate the swing grid amount.
  the swing grid will update upon *edit cursor* movement.
  tip: use automation items with the background envelope disabled
  it's better functionality, both for this script and in general
  
  NOTES: 
  * if you want to only utilize the positive swing grid values (0-100%)
    change positiveOnly variable to "true"
  * hint: use this script in conjunction with:
      "FTC_apply Arrange editor grid changes to input quantize.lua"
    in order to apply the swing grid to your input quantize settings!
    
--]]

--[[
 * Changelog: 
 * v1.0 (2024-06-23)
   + initial release
--]]
---------------------------------------------------------------------------------------    
--positiveOnly = false

jsfx={}
jsfx.name="swing grid automator"
jsfx.fn="swing grid automator"

if positiveOnly == false then 
  jsfx.body = [[
desc:swing grid automator
slider1:0<-100,100,1>swing grid amount
@init
@block
]]
else
  jsfx.body = [[
desc:swing grid automator
slider1:0<0,100,1>swing grid amount
@init
@block
]]
end

local file=io.open(reaper.GetResourcePath().."/Effects/"..jsfx.fn, "w")
file:write(jsfx.body)           -- create the JSfx
file:close()
envBypass = reaper.SNM_GetIntConfigVar( "pooledenvattach", -1 ) -- check env style

function trackHack()            -- check swing grid track for instructions
  local tr, retval, env
  numTracks = reaper.CountTracks(0)
  curPos = reaper.GetCursorPosition()
  
  for i = 1, numTracks do                         -- look for grid track
    local track = reaper.GetTrack(0,i-1)
    local _, tr_name = reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', '', 0 )
    
    if tr_name:lower():find("swing grid") then    -- if swing track available
      tr = track                                  -- assign track
      retval = reaper.TrackFX_GetParam( tr, 0, 0 )  -- get swing param val
    end -- if grid track available
  end -- for each track
            
  if not tr then                                  -- if swing track unavailable
    reaper.InsertTrackAtIndex( numTracks, false ) -- insert track at end of project
    tr = reaper.GetTrack( 0, numTracks)     -- get the new track
    _, _ = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "swing grid", true)
    reaper.SetMediaTrackInfo_Value( tr, "D_VOL", 0 )      -- volume off
  end
  
  fxCount = reaper.TrackFX_GetCount( tr )
  if fxCount == 0 then 
    reaper.TrackFX_AddByName( tr,jsfx.fn, false, 1 )      -- add js
  end
    
  _, _, swingMode, swingAmount = reaper.GetSetProjectGrid(0, false)
    
  if swingMode == 1 then                        -- if swing grid is on
    reaper.TrackFX_SetParam( tr, 0, 0, swingAmount*100 ) -- set swing
    env = reaper.GetFXEnvelope( tr, 0, 0, true)  -- create envelope
  end -- if swing grid is on
    
  
  
  
  envCount = reaper.CountTrackEnvelopes( tr )             -- count envelopes
  if envCount == 0 then                                   -- if no envelopes
    _, _, swingMode, swingAmount = reaper.GetSetProjectGrid(0, false)
    reaper.TrackFX_SetParam( tr, 0, 0, swingAmount*100 )  -- set js swing value to grid swing
    env = reaper.GetFXEnvelope( tr, 0, 0, true)         -- create envelope
    if envBypass == 4 then                              -- if using detached envelopes
      reaper.InsertAutomationItem( env, 1, curPos, 0)   -- insert an automation item at curPos
    end
  else -- if envelopes exist, get it by name
    env = reaper.GetTrackEnvelopeByName( tr, "swing grid amount / swing grid automator" )
  end -- if envelopes present
  
  return tr, retval, env
end

function main()
  playPos = reaper.GetPlayPosition()
  gridTrack, swingParam, env = trackHack()
  
  if curPos ~= lastCurPos or swingParam ~= lastSwingParam then   -- update on edit cursor/swing param change
    if gridTrack then       -- if target track, set swing grid amount using track envelope
      _, division, swingMode, swingAmount = reaper.GetSetProjectGrid(0, false)  -- get current grid details
      
      automationItemCount = reaper.CountAutomationItems( env )  -- how many AI on relevant envelope
      if automationItemCount ~= 0 and envBypass == 4 then       -- if there's an AI and underlying env bypassed
        for j = automationItemCount-1, 0, -1 do                 -- for each AI, get details
          automationItemStart = reaper.GetSetAutomationItemInfo( env, j, "D_POSITION", 0, 0)
          length   = reaper.GetSetAutomationItemInfo( env, j, "D_LENGTH" , 0, 0)
          automationItemEnd = automationItemStart + length
          
          if curPos >= automationItemStart and curPos < automationItemEnd then  -- if cursor is within AI bounds
            _, value = reaper.Envelope_Evaluate( env, curPos, 0, 0)             -- get envelope value at curPos
            reaper.GetSetProjectGrid( 0, 1, division, swingmode, value/100 )    -- set grid swing to env value
          end -- if cursor is in AI
        end -- for each AI
      else -- if no AI, or if background envelopes not bypassed
        _, value = reaper.Envelope_Evaluate( envelope, curPos, 0, 0)        -- get envelope value at curPos
        reaper.GetSetProjectGrid( 0, 1, division, swingmode, value/100 )    -- set grid swing to env value
      end -- if there's automation items
    end -- if gridTrack is present
  end -- if edit cursor or swing value changed
  
  lastCurPos = curPos
  lastSwingParam = swingParam
  reaper.defer(main)
end -- main

main()


