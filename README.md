# flyluaiosc-script

Custom [FlyLuaIoSC](https://github.com/cpuwolf/flyluaiosc) scripts for the **WinWing AGP** (gear / autobrake panel).

## `data/z_WWAGP_no_msfs.lua` — offline AGP panel

Runs **only when MSFS is not connected**. Without live sim data, it drives the
AGP's LEDs and LCD directly from the panel's own controls, so the unit still
does something useful on the desktop:

- **Clock / LCD** — shows system time (UTC or local) and date, toggled by the
  panel's DATE / time buttons.
- **Gear lever** — moving the lever plays a ~3 s "in transit" cycle: the red
  gear-unlock lights come on during transit, then the green lock lights show
  when down (all lights off when up).
- **AUTO BRK (LO / MED / MAX)** — momentary push buttons, toggled on press and
  **mutually exclusive** (selecting one clears the others; pressing the lit one
  turns it off). Handled via event-driven key callbacks so quick taps register
  instantly.
- **TERR on ND** — push button, toggles its light on/off.
- **BRK FAN** — maintained toggle switch; its ON light follows the switch position.
- **A/SKID & N/W STRG** — maintained switch; lights the BRK FAN **HOT** light
  while ON.
- **Brightness** — the clock SET knob (keys 13 dim / 15 bright) steps the
  backlight, LCD and LED brightness through 10 levels on a squared curve,
  clamped at both ends (no wrap-around). LEDs never go below 100 so they stay
  visible.

### Notes

- **Close WinWing SimProApp before use.** SimProApp takes an exclusive lock on
  the USB device; while it is open, LED writes from FlyLuaIoSC are silently
  dropped and no lights respond.
- Button/lever indices (`keysmap[...]`) were found with the finder approach and
  inferred from the `CfgRpn()` numbers in the bundled sim profiles. If a control
  doesn't respond, its index is the first thing to re-check.
- **AGP firmware V1.14 or newer.** `Wwagp.lua` expects device ID `0x158040CC`;
  older firmware reports `3AEBEE64` and key callbacks are dropped
  (`REG_KEY dropped` in `flyluaio.log`), so AUTO BRK / TERR / the knob stop working.
- **Writes only on change.** FlyLuaIoSC blocks all writes to the device after
  ≥30 writes/s for 10 s (`block all caches` in the log), so LEDs are sent only
  when their value changes, with a full resend every 2 s.
- **Expect some input delay.** Without MSFS, FlyLuaIoSC handles about one key
  event every 0.5 s, and after a knob turn it keeps firing auto-repeat ("fast")
  events for a while. The knob keys register a press callback only, so the
  repeats don't run Lua, but buttons pressed right after a turn can still lag.
  This is a FlyLuaIoSC limit, not the script.

## Install

Copy `data/z_WWAGP_no_msfs.lua` into your FlyLuaIoSC `data/` folder
(typically `%LOCALAPPDATA%\cpuwolf\flyluaiosc\data\`).

## Repository layout

The Git repository is rooted **one level above** the FlyLuaIoSC `data/` folder
so its `.git` directory stays out of the folder FlyLuaIoSC's file watcher scans.
A strict `.gitignore` tracks only these script files — app binaries, logs, and
`key.data` are never committed.
