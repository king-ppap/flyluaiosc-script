-- *****************************************************************
-- created by Wei Shuai <cpuwolf@gmail.com> 2026-04-21
-- *****************************************************************

-- This scripts only runs when MSFS is not running

if uluaFind("(A:CIRCUIT AVIONICS ON,Bool)") ~= nil then
	return
end

-- Do not remove below lines: hardware detection
local wwagp = com.sim.qm.Wwagp:new()
if not wwagp:Init() then
	return
end
-- Do not remove above lines: hardware detection



uluaLog('WinWing AGP offline clock')

local dr_digilight = iDataRef:New('cpuwolf/flyluaio/WwAgp/condbtn[10]')

-- wwagp:CfgEncFull(13, 15, 'cpuwolf/flyluaio/WwAgp/condbtn[10]', 10, 100, 2, 100, 250)


wwagp:GetBkl('cpuwolf/flyluaio/WwAgp/condbtn[9]', 1)
wwagp:GetDigiBkl('cpuwolf/flyluaio/WwAgp/condbtn[10]', 1)
wwagp:GetLedBkl('cpuwolf/flyluaio/WwAgp/condbtn[9]', 1)

local dr_utc_is_date = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[14]')
local dr_is_utc = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[17]')

--================================ Gear lever light emulation (no live sim data, driven by the lever itself)
local dr_gear_lever_up = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[23]')
local dr_gear_lever_down = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[24]')

local GEAR_TRANSIT_SECONDS = 3
local gear_position = "DOWN"
local gear_transitioning = false
local gear_transition_target = nil
local gear_transition_end = 0

--================================ Push-button light emulation
-- inferred key indices from the CfgRpn() numbers in the sim profiles

-- BRK FAN is a maintained toggle switch -> its keysmap holds a steady level, so
-- we read it directly each frame in the loop below
local dr_btn_brkfan = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[0]')

-- AUTO BRK (LO/MED/MAX) and TERR are momentary push buttons. Polling keysmap in
-- the frame loop misses short taps (the pulse is shorter than a frame), so we
-- register real key-press callbacks instead -- event-driven, never missed. The
-- callbacks run as global code strings, so their state must live in globals.
-- AUTO BRK is a mutually-exclusive group (0 none, 1 LO, 2 MED, 3 MAX).
_G.agp_autobrk_sel = _G.agp_autobrk_sel or 0
_G.agp_terr_on = _G.agp_terr_on or false

function _G.agp_press_autobrk_lo() _G.agp_autobrk_sel = (_G.agp_autobrk_sel == 1) and 0 or 1 end
function _G.agp_press_autobrk_med() _G.agp_autobrk_sel = (_G.agp_autobrk_sel == 2) and 0 or 2 end
function _G.agp_press_autobrk_max() _G.agp_autobrk_sel = (_G.agp_autobrk_sel == 3) and 0 or 3 end
function _G.agp_press_terr() _G.agp_terr_on = not _G.agp_terr_on end

wwagp:CfgFc(2, "_G.agp_press_autobrk_lo()")
wwagp:CfgFc(3, "_G.agp_press_autobrk_med()")
wwagp:CfgFc(4, "_G.agp_press_autobrk_max()")
wwagp:CfgFc(22, "_G.agp_press_terr()")

--================================ When MSFS is not runinng, offline lua code
local systemtimestr = os.date("%H:%M:%S")
GlobalFrameLoopManager:add(function()
	dr_digilight:Set(200)
	-- panel text-label backlight at ~70% (device full scale ~200, so 0.7 * 200 = 140)
	wwagp:SetBkl(100)
	wwagp:SetDigiBkl()
	-- drive the LED master brightness explicitly: condbtn[9] (the GetLedBkl source)
	-- is never written in offline mode, so without this the LEDs stay at brightness 0
	wwagp:SetLedBkl(100)

	-- gear lever light emulation, inlined here (calling this through a helper
	-- function was observed not to reach hardware in this sandbox)
	if dr_gear_lever_up:ChangedUpdate() and dr_gear_lever_up:GetOld() == 1 then
		gear_transition_target = "UP"
		gear_transitioning = true
		gear_transition_end = os.clock() + GEAR_TRANSIT_SECONDS
	end
	if dr_gear_lever_down:ChangedUpdate() and dr_gear_lever_down:GetOld() == 1 then
		gear_transition_target = "DOWN"
		gear_transitioning = true
		gear_transition_end = os.clock() + GEAR_TRANSIT_SECONDS
	end
	if gear_transitioning and os.clock() >= gear_transition_end then
		gear_transitioning = false
		gear_position = gear_transition_target
	end

	local unlocked_val = gear_transitioning and 100 or 0
	local locked_val = ((not gear_transitioning) and gear_position == "DOWN") and 100 or 0

	-- call SendLedCmd directly with explicit brightness (100/0), exactly like the
	-- all-LEDs test that was confirmed working -- avoids the ilua_bool_ternary path
	wwagp:SendLedCmd(wwagp.LEDS_ULOCKL, unlocked_val)
	wwagp:SendLedCmd(wwagp.LEDS_ULOCKN, unlocked_val)
	wwagp:SendLedCmd(wwagp.LEDS_ULOCKR, unlocked_val)
	wwagp:SendLedCmd(wwagp.LEDS_LOCKL, locked_val)
	wwagp:SendLedCmd(wwagp.LEDS_LOCKN, locked_val)
	wwagp:SendLedCmd(wwagp.LEDS_LOCKR, locked_val)

	-- BRK FAN is a maintained toggle switch: follow its position directly.
	-- AUTO BRK / TERR state comes from the event-driven key callbacks above.
	local brkfan_on = dr_btn_brkfan:Get() > 0
	local autobrk_sel = _G.agp_autobrk_sel

	wwagp:SendLedCmd(wwagp.LEDS_BRAKEON, brkfan_on and 100 or 0)
	wwagp:SendLedCmd(wwagp.LEDS_LOW, (autobrk_sel == 1) and 100 or 0)
	wwagp:SendLedCmd(wwagp.LEDS_MED, (autobrk_sel == 2) and 100 or 0)
	wwagp:SendLedCmd(wwagp.LEDS_MAX, (autobrk_sel == 3) and 100 or 0)
	wwagp:SendLedCmd(wwagp.LEDS_TERR, _G.agp_terr_on and 100 or 0)

	-- keep the remaining unused LEDs off (they hold last-sent state on the device)
	wwagp:SendLedCmd(wwagp.LEDS_BRAKEHOT, 0)
	wwagp:SendLedCmd(wwagp.LEDS_LOWD, 0)
	wwagp:SendLedCmd(wwagp.LEDS_MEDD, 0)
	wwagp:SendLedCmd(wwagp.LEDS_MAXD, 0)
	wwagp:SendLedCmd(wwagp.LEDS_LEVER, 0)

	local is_utc = dr_is_utc:Get()
	if dr_utc_is_date:Get() > 0 then
		if is_utc > 0 then
			systemtimestr = os.date("!%m.%d.%y")
		else
			systemtimestr = os.date("%m.%d.%y")
		end
	else
		if is_utc > 0 then
			systemtimestr = os.date("!%H:%M:%S")
		else
			systemtimestr = os.date("%H:%M:%S")
		end
	end

	-- Write to hardware
	wwagp:setLcdStr("     ", systemtimestr, "     ")
end)
