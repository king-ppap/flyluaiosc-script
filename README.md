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
- **BRK FAN** — maintained toggle switch; its light follows the switch position.
- **Backlight** — panel text-label backlight and LED master brightness driven at
  a fixed level (the live-sim brightness datarefs aren't available offline).

### Notes

- **Close WinWing SimProApp before use.** SimProApp takes an exclusive lock on
  the USB device; while it is open, LED writes from FlyLuaIoSC are silently
  dropped and no lights respond.
- Button/lever indices (`keysmap[...]`) were found with the finder approach and
  inferred from the `CfgRpn()` numbers in the bundled sim profiles. If a control
  doesn't respond, its index is the first thing to re-check.

## Install

Copy `data/z_WWAGP_no_msfs.lua` into your FlyLuaIoSC `data/` folder
(typically `%LOCALAPPDATA%\cpuwolf\flyluaiosc\data\`).

## Repository layout

The Git repository is rooted **one level above** the FlyLuaIoSC `data/` folder
so its `.git` directory stays out of the folder FlyLuaIoSC's file watcher scans.
A strict `.gitignore` tracks only these script files — app binaries, logs, and
`key.data` are never committed.
