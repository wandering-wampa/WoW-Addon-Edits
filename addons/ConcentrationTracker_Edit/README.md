# ConcentrationTracker_Edit

The `addons/ConcentrationTracker_Edit` directory contains the customized addon packaged for WoW Retail, based on Concentration Tracker 3.9.58 by IceDNicco.

Upstream: https://www.curseforge.com/wow/addons/concentration-tracker

## Custom changes

- Retail portrait frame, centered title, textured outer panel, framed content area, and matching settings window.
- Fully opaque backgrounds.
- Native damage-meter bar artwork and responsive concentration bars that stretch as the window resizes.
- Name A-Z/Z-A and class A-Z/Z-A sorting by clicking the Character header. Names remain A-Z within each class.
- Local refill date/time and a compact footer with details on hover.
- Automatic login concentration discovery using known profession/currency mappings, with short retries while data loads.
- Explicit missing-data labels instead of misleading meters on Moxie-only rows.
- Minimap positioning based on actual map dimensions and shape, plus a compact tooltip.
- Shared table margins that remain stable when the weekly banner refreshes; dedicated character-marker padding.

## Install

1. Exit WoW, or reload after replacing an already installed addon.
2. Copy this `ConcentrationTracker_Edit` folder into your WoW Retail `Interface/AddOns` directory.
3. Enable Concentration Tracker and run `/conc` in-game.

Commands:

- `/conc`: open the tracker.
- `/conclanguage`: open settings.
- `/conc refresh`: refresh current-character data.
- `/conc logincheck`: print login-scan diagnostics.

Characters still need to be logged in for live readings. Other characters' regeneration is estimated from saved data. New profession types may need an initial profession-window scan if no usable mapping is available yet.

## Validation

Lua 5.1 compilation and targeted local checks cover login discovery, four sorting modes, responsive column sizing, minimap geometry, recycled Moxie-only rows, and weekly-banner anchor updates. The layout has been iterated against in-game screenshots; live client behavior remains the final check after changes.

## Attribution and rights

The upstream addon identifies IceDNicco as its author and is listed as **All Rights Reserved** on CurseForge. Original authorship and upstream documentation are retained. This repository stores personal customizations; it does not grant a license to redistribute upstream code. No new license is applied to the upstream addon.

## Maintenance

Addon-manager updates can overwrite these changes. Compare future upstream updates before replacing this customized copy. Account data, SavedVariables, logs, and credentials do not belong in this repository.

## Upstream documentation

See [the original upstream README](UPSTREAM-README.md) for the original feature documentation.

## Replacing an existing installation

This is a replacement for ConcentrationTracker, not a companion addon. Do not enable both copies together: they share frame names, commands, and SavedVariables globals.

For existing settings and alt data: completely exit WoW first. Back up `WTF/Account/<account>/SavedVariables/ConcentrationTracker.lua`, then copy it to `ConcentrationTracker_Edit.lua` in that same directory. Keep the original as a backup. Repeat for each account you use. SavedVariables global names remain unchanged inside the file.

Remove the original `ConcentrationTracker` folder from the active AddOns directory (or move it outside AddOns as a backup), extract `ConcentrationTracker_Edit` into AddOns, then restart WoW. New installations do not need the SavedVariables copy.
