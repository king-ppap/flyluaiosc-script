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

-- clock SET knob (keys 13 dec / 15 inc) dims and brightens the whole panel.
-- device full scale is ~200 (the sim profiles use percent * 2)
local BRIGHTNESS_MIN = 10
local BRIGHTNESS_MAX = 200
-- the knob moves through BRIGHTNESS_LEVELS clicks from dim to full. levels are
-- mapped on a squared curve because the eye sees brightness that way: equal
-- raw steps look like big jumps when dim and nothing when bright
-- kept small on purpose: without MSFS flyluaio delivers only ~1 knob click per
-- second (clicks queue up), so fewer levels means less waiting
local BRIGHTNESS_LEVELS = 10
local BRIGHTNESS_GAMMA = 2
-- each knob click is one short press of key 13 (down) or 15 (up), counted by
-- key callbacks like AUTO BRK / TERR (the CfgEncFull counter bounced back and
-- forth while turning). callbacks run as global code strings, so state is global.
_G.agp_brightness_level = math.min(BRIGHTNESS_LEVELS, _G.agp_brightness_level or BRIGHTNESS_LEVELS)

function _G.agp_brightness_step(dir)
	_G.agp_brightness_level = math.min(BRIGHTNESS_LEVELS, math.max(0, _G.agp_brightness_level + dir))
end

-- press only: after a turn flyluaio keeps firing the key's "fast" (auto-repeat)
-- event every 0.5 s as if it were held. callbacks are run one at a time, so a
-- fast/release callback here flooded the queue and delayed every other button
wwagp:CfgFc(13, "_G.agp_brightness_step(-1)")
wwagp:CfgFc(15, "_G.agp_brightness_step(1)")


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
-- A/SKID & N/W STRG is also a maintained switch: key 5 = ON position, key 6 = OFF
local dr_sw_askid_on = iDataRef:New('cpuwolf/flyluaio/WwAgp/keysmap[5]')

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

-- Only write to the device when a value changes. flyluaio blocks ALL writes to
-- the AGP when it sees >=30 writes/s for 10 s ("WriteCache ... block all caches"
-- in flyluaio.log), and re-sending every LED each frame triggered that block,
-- which froze the LEDs and brightness. Everything is re-sent every
-- RESEND_SECONDS anyway, in case a write was dropped.
local RESEND_SECONDS = 2
local sent = {}
local next_resend = 0

local function send_led(id, val)
	if sent[id] ~= val then
		sent[id] = val
		wwagp:SendLedCmd(id, val)
	end
end

GlobalFrameLoopManager:add(function()
	if os.clock() >= next_resend then
		sent = {}
		next_resend = os.clock() + RESEND_SECONDS
	end

	-- all brightness follows the SET knob level counted by the key callbacks
	local brightness = math.floor(BRIGHTNESS_MIN + (BRIGHTNESS_MAX - BRIGHTNESS_MIN)
		* (_G.agp_brightness_level / BRIGHTNESS_LEVELS) ^ BRIGHTNESS_GAMMA + 0.5)
	send_led(wwagp.LED_LCD_BRIGHTNESS, brightness)
	send_led(wwagp.LED_BACKLIGHT, brightness)
	-- drive the LED master brightness explicitly: condbtn[9] (the GetLedBkl source)
	-- is never written in offline mode, so without this the LEDs stay at brightness 0.
	-- same lower clamp of 100 as SetLedBkl, so the LEDs dim less than the rest
	send_led(wwagp.LED_OVERALL_LEDS_BRIGHTNESS, math.max(100, brightness))

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

	-- explicit brightness (100/0) through send_led, which calls SendLedCmd only on
	-- change -- avoids the ilua_bool_ternary path
	send_led(wwagp.LEDS_ULOCKL, unlocked_val)
	send_led(wwagp.LEDS_ULOCKN, unlocked_val)
	send_led(wwagp.LEDS_ULOCKR, unlocked_val)
	send_led(wwagp.LEDS_LOCKL, locked_val)
	send_led(wwagp.LEDS_LOCKN, locked_val)
	send_led(wwagp.LEDS_LOCKR, locked_val)

	-- BRK FAN is a maintained toggle switch: follow its position directly.
	-- AUTO BRK / TERR state comes from the event-driven key callbacks above.
	-- the BRK FAN "HOT" light is lit while the A/SKID & N/W STRG switch is ON
	local brkfan_on = dr_btn_brkfan:Get() > 0
	local askid_on = dr_sw_askid_on:Get() > 0
	local autobrk_sel = _G.agp_autobrk_sel

	send_led(wwagp.LEDS_BRAKEON, brkfan_on and 100 or 0)
	send_led(wwagp.LEDS_BRAKEHOT, askid_on and 100 or 0)
	send_led(wwagp.LEDS_LOW, (autobrk_sel == 1) and 100 or 0)
	send_led(wwagp.LEDS_MED, (autobrk_sel == 2) and 100 or 0)
	send_led(wwagp.LEDS_MAX, (autobrk_sel == 3) and 100 or 0)
	send_led(wwagp.LEDS_TERR, _G.agp_terr_on and 100 or 0)

	-- keep the remaining unused LEDs off (they hold last-sent state on the device)
	send_led(wwagp.LEDS_LOWD, 0)
	send_led(wwagp.LEDS_MEDD, 0)
	send_led(wwagp.LEDS_MAXD, 0)
	send_led(wwagp.LEDS_LEVER, 0)

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