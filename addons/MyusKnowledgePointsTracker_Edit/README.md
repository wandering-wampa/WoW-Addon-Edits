# Knowledge Point Tracker — native Retail UI

Personal customization of **Myu's Knowledge Points Tracker 0.9.0**, dated
**November 8, 2026**. Custom version: **0.9.0-native.3**. Targets **WoW Retail /
Midnight**, interface **120100 / 120105**, with the upstream Dragonflight, The War
Within, and Midnight profession data. No region or realm restrictions were added.

## Custom changes

- Retail frame with a centered "Knowledge Point Tracker" title and no portrait circle.
- Matching display name in the AddOns list, Blizzard Settings and minimap tooltip.
- Opaque rock-textured outer panel and framed list/detail areas.
- Visible native expansion selector, source filters, Settings button and close button.
- Profession headers with skill level, knowledge totals and expand/collapse markers;
  professions stay in alphabetical order and sources retain upstream ordering.
- Responsive rows, a scrolling profession/source list and separately scrolling
  tracking details. Full source names and requirements are available on hover.
- Title-bar dragging, a bottom-right resize grip, saved window dimensions and
  existing lock/scale preferences. Locking prevents both dragging and resizing.
- Escape and Close save the closed state. Combat/instance/delve hides preserve
  the user's preference and restore the window when appropriate.
- Native autohide checkbox; open menus keep the frame visible. Minimap hovering
  can still briefly reveal the window.
- Safer recycled rows and asynchronous item-name refreshes.

Existing knowledge calculations, profession data, requirements, waypoint/TomTom
tracking and SavedVariables remain intact. Background opacity no longer changes
the solid panel; row shading and knowledge colors remain configurable in Blizzard
Settings. The older opacity value is retained in saved data.

## Use

- `/mkpt`: toggle the tracker; `/mkpt show` and `/mkpt hide` explicitly open/close.
- Click a profession to expand it, then a source to track it. Click again to untrack.
- Use the top dropdowns for expansions and filters. Right-click the frame or a row
  for the combined menu, including Lock Window and Auto hide.
- `/mkpt config`: open the existing Blizzard settings integration.
- `/mkpt scale 1.0`: adjust scale (0.5–1.5).
- `/mkpt lock`, `/mkpt unlock`, `/mkpt autohide`, `/mkpt minimap`, and
  `/mkpt compartment` retain their existing functions.

## Installation and maintenance

Extract the ZIP and place the `MyusKnowledgePointsTracker_Edit` folder in your
WoW Retail `Interface/AddOns` directory. The ZIP contains the addon folder at its
root. Restart WoW after installing this new addon and enable **Knowledge Point
Tracker** in the addon list. `/mkpt` opens the window. This is a replacement for
MyusKnowledgePointsTracker, not a companion addon: do not enable both copies,
because they share frame names, commands and the `MKPT_Config` SavedVariables global.

### Replacing an existing installation

1. Exit WoW completely so it saves the latest preferences.
2. Back up the existing addon and
   `WTF/Account/<account>/SavedVariables/MyusKnowledgePointsTracker.lua`.
3. Copy that saved-settings file to `MyusKnowledgePointsTracker_Edit.lua` in the
   same SavedVariables directory, keeping the original backup. The global name
   `MKPT_Config` inside the file stays unchanged. Repeat for each account you use.
   If a destination file already exists, preserve it and compare the settings
   before replacing anything.
4. Move the original `MyusKnowledgePointsTracker` folder outside the active
   `Interface/AddOns` directory, then install the edited folder and restart WoW.

Fresh installations do not need a saved-settings copy. Existing installations of
the `_Edit` version can update that same folder and reload the UI normally.

Requires Blizzard_Professions and the bundled libraries. TomTom remains optional.
Addon-manager updates may overwrite these personal changes; compare upstream
updates before replacing this customized copy.

## Validation

All 27 Lua files compile under Lua 5.1. `python tools/test_knowledge_tracker.py`
(requires `lupa`) runs a headless harness covering 45 UI
behavior assertions, including expanded lists, row reuse, tracking, menus, scale,
resize persistence, autohide and visibility transitions, and validates the TOC's
load paths and addon icon. The release workflow runs these checks before packaging.
This is not a live-client visual test:
check layout, scrolling and tracking in WoW after reloading.

## Upstream

Original author: **Myu**. [Upstream project](https://github.com/myu-westfall/MyusKnowledgePointsTracker).
The original [README](UPSTREAM-README.md) and [changelog](CHANGELOG.md) are preserved.
These are personal modifications; no additional license is granted for upstream code.
The folder, TOC and ZIP use the repository's `_Edit` suffix; the visible name stays
**Knowledge Point Tracker**. The original author's name and documents are retained.
