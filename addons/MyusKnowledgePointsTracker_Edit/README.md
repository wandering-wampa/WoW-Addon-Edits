# Knowledge Point Tracker — native Retail UI

Personal customization of **Myu's Knowledge Points Tracker 0.9.0**, dated
**November 8, 2026**. Custom version: **0.9.0-native.8**. Targets **WoW Retail /
Midnight**, interface **120100 / 120105**, with the upstream Dragonflight, The War
Within, and Midnight profession data. No region or realm restrictions were added.

## Custom changes

- Retail frame with a centered "Knowledge Point Tracker" title and no portrait circle.
- Matching display name in the AddOns list, Blizzard Settings and minimap tooltip.
- Opaque rock-textured outer panel and framed list/detail areas.
- Profession sections use native-height, single-line gold category headers, with
  skill values aligned to the right and labeled knowledge totals beneath the artwork.
- White source names and points, dimmed when requirements are unmet; one leading
  item icon, with source-type icons aligned beside the point values.
- Items share an untiled profession-list background without individual black
  strips. Native hover and tracked-source highlights are mutually exclusive.
- Visible native expansion selector, source filters, Settings button and close button.
- Native expand/collapse markers; professions stay in alphabetical order and
  sources retain upstream ordering.
- Responsive rows and slim Retail scrollbars for the source list and separate
  tracking details. Full source names and requirements are available on hover.
- Automatic height fits shorter lists and caps long lists at a scrollable height.
  Manual resizing switches to saved fixed dimensions; the context menu can restore
  automatic height. Title-bar dragging and existing lock/scale preferences remain.
  Locking prevents both dragging and manual resizing.
- Starts closed on every character login and UI reload, including upgrades with
  an older saved open state. Open it explicitly with the minimap button or `/mkpt`.
- Escape and Close keep it closed during the session. Combat/instance/delve hides
  preserve the session's open/closed choice and restore the window when appropriate.
- Native autohide checkbox; open menus keep the frame visible. Minimap hovering
  can still briefly reveal the window.
- Safer recycled rows and asynchronous item-name refreshes.
- Correct fixed-text initialization for the native Filter button, fixing the
  startup failure in native.6 that prevented the minimap button from opening the window.

Existing knowledge calculations, profession data, requirements, waypoint/TomTom
tracking and SavedVariables remain intact. Background opacity no longer changes
the solid panel. Configurable knowledge colors remain in tooltips and descriptions;
the main list uses native gold/white/disabled text. The old panel/row opacity values
are retained in saved data but are no longer applied.

## Use

- `/mkpt`: toggle the tracker; `/mkpt show` and `/mkpt hide` explicitly open/close.
- The window starts closed after login or `/reload`; it does not restore a
  previous session's open state. Other saved settings are preserved.
- Click a profession to expand it, then a source to track it. Click again to untrack.
- Use the top dropdowns for expansions and filters. Right-click the frame or a row
  for the combined menu, including Lock Window and Auto hide.
- Height fits the displayed contents by default, including on the first load of
  this revision. Drag the bottom-right grip to save a fixed size, or right-click
  and choose **Fit height to contents** to restore automatic sizing. Width and
  position remain saved. Expand/collapse and tracking refreshes respect a fixed size.
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
(requires `lupa`) runs a headless harness covering 76 UI
behavior assertions, including expanded lists, row reuse, tracking, menus, scale,
resize persistence, autohide and visibility transitions, and validates the TOC's
load paths and addon icon. It also checks template-specific dropdown methods and
the actual minimap broker's left/right/Ctrl-click handlers, closed startup for new
and existing characters, and preservation of other saved settings. The release workflow
runs these checks before packaging.
This is not a live-client visual test:
check layout, scrolling and tracking in WoW after reloading.

## Visual reference

The list follows Blizzard's [Professions recipe-list templates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml),
reviewed November 8, 2026: 25-pixel category lines, native-size header end caps,
gold category labels, white recipe labels, shared untiled list artwork and
separate recipe interaction overlays. Knowledge totals sit below the category
artwork rather than stretching it vertically. Selection behavior follows
the [recipe-list mixin](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.lua).
Both scroll panes use [MinimalScrollBar](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml)
and Blizzard's [ScrollFrame adapter](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua).

## Upstream

Original author: **Myu**. [Upstream project](https://github.com/myu-westfall/MyusKnowledgePointsTracker).
The original [README](UPSTREAM-README.md) and [changelog](CHANGELOG.md) are preserved.
These are personal modifications; no additional license is granted for upstream code.
The folder, TOC and ZIP use the repository's `_Edit` suffix; the visible name stays
**Knowledge Point Tracker**. The original author's name and documents are retained.
