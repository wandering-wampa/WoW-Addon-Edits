# Retail addon UI style guide

Recorded **November 8, 2026**, for **WoW Retail / Midnight 12.1.5**. These are this
project's design and maintenance rules, informed by native UI source and the
accepted Knowledge Point Tracker native.7 layout. They are not a universal
Blizzard specification. Revalidate API details for future clients.

## Choose a coherent native reference

Before editing, identify the closest in-game component by function. A grouped
knowledge-source list fits the Professions recipe list; concentration values fit
progress bars; quest instructions need a reading panel. Read both the reference
XML and its Lua mixins. Record the chosen files in the addon's documentation.

Compare the full composition: category hierarchy, text emphasis, density,
background, icon placement, controls, scrolling and selected/disabled states.
Using native textures alone does not make a layout native. Do not combine the
Achievements parchment, Character-panel ornaments and profession-list controls
without a functional reason. Screenshots are visual evidence; identify a
reference's provenance before assuming another addon's screen exposes a Blizzard
template.

## Visual hierarchy

| Element | Project treatment |
| --- | --- |
| Window | Opaque content surfaces, native border and title placement, consistent margins. Use a portrait only when it has a purpose. |
| Category | Gold heading, compact native category artwork, clear expand/collapse affordance. Preserve useful section structure. |
| Summary | Explicit labels and readable values outside single-line header artwork. Use gold labels and white values for neutral knowledge totals. |
| Ordinary entry | White name/value text on the shared list surface. Use indentation and alignment to show its relationship to the category. |
| Unmet requirement | Dimmed text with a tooltip explaining the requirement. Preserve the entry's actual tracking behavior. |
| Hover / selection | Distinct native interaction treatments; selection replaces hover rather than stacking both overlays. |
| Color | Reserve strong color for meaningful states, progress and icons. Category colors may remain in explanatory tooltips; avoid rainbow-colored names throughout the list. |

Do not remove category backgrounds merely because individual item backgrounds
look wrong. The rejected Knowledge Point Tracker changes demonstrate both
failure modes: permanent black strips behind every item looked foreign, while
removing all category treatment made the list look empty and unstructured.

## Geometry and artwork

The [Professions category template](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml)
uses a 25-unit category line and native-size end caps. Stretch the middle
horizontally; preserve the caps' vertical proportions. Additional metrics belong
below that line. Its ordinary recipe rows are 20 units high. These are logical UI
units, not screenshot pixels after UI scaling.

For the accepted knowledge tracker, the implementation uses an 18-unit leading
icon, a separate 20-unit summary line, compact source rows, and a right-aligned
point column. Source-type icons sit beside the point values. These are specific
layout choices, not mandatory dimensions for every addon. Allow for long names,
localized labels and large values; keep full information available on hover.

Keep a shared margin across initial creation, refreshes, empty rows and special
row types. Avoid fitting artwork around arbitrary padding first and trying to
repair text alignment afterward. Native damage-meter/progress artwork remains
appropriate for actual progress values, as in ConcentrationTracker_Edit.

The [native inset template](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml)
supplies a tiled marble background. For a full-panel recipe atlas, use a separate
untiled texture and hide the inherited marble; do not assume changing its atlas
also changes inherited texture behavior. Retain an opaque base. For a window
without a portrait, use the native portrait-hiding helper so border and title
anchors change together; hiding the circular texture alone leaves the wrong frame.

## Controls, size and behavior

Use the current slim [MinimalScrollBar](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml)
for lists that follow the modern Professions design. Connect it through the
appropriate [ScrollUtil adapter](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua):
the ScrollFrame adapter for existing scroll children, or the ScrollBox adapter
for data-provider lists. Preserve native callbacks when adding clamps. Check
wheel, arrows, thumb dragging, range changes and the no-scroll state.

Compact trackers should not leave a large empty panel merely because an earlier
layout saved a tall window. Content fitting can be useful, with a bounded height
and scrolling for long lists. Manual resizing must switch to persistent fixed
dimensions; provide an explicit way to restore fitting. Do not impose automatic
height on every addon regardless of its purpose.

Keep long details independently scrollable. Drag from the title bar, keep row
clicks for their action, and respect movement/resize locks. Close and Escape
should retain the user's choice. Temporary combat/instance hiding should not
erase that preference. Autohide must leave open menus usable.

## Verify template contracts, not just names

Similar-looking controls can have different methods. In the
[Blizzard menu mixins](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Menu/MenuTemplates.lua):

| Template | Text behavior |
| --- | --- |
| `WowStyle1DropdownTemplate` | Uses `DropdownSelectionTextMixin`; selection text supports `SetDefaultText` and `OverrideText`. |
| `WowStyle1FilterDropdownTemplate` | Uses `DropdownTextMixin`; fixed filter labels use `SetText`. The selection-only methods are absent. |

Knowledge tracker native.6 changed templates but retained the selection-only
calls. Window creation stopped before initialization finished, leaving the
minimap button apparently unresponsive. Native.7 removed those calls. Its tests
now reject the wrong template methods and invoke the real minimap broker's
callbacks. A permissive mock that adds every method to every frame can conceal
exactly this kind of failure.

When switching a template, inspect inherited mixins, OnLoad/OnShow behavior,
parent keys and required children as well as its appearance. Test the entire
startup-to-open path, not only a manually constructed row.

## Refresh and validation

Pooled rows must restore anchors, widths, font colors, artwork visibility,
selection/hover state, callbacks and event registrations on every reuse. Exercise
category-to-item and item-to-category reuse, trainers, currencies and uncached
names. Initial anchors alone are insufficient: refresh code can overwrite them.

Run checks appropriate to the change. UI changes need compilation and behavior
coverage for the affected initialization/refresh/entry-point paths. For a known
regression, demonstrate that the new check fails before the fix and passes after.
The knowledge tracker suite is `python tools/test_knowledge_tracker.py` with
`lupa` available; its methods are explicit stubs, not a Blizzard renderer.

Compare the result in game at the actual UI scale: collapsed and expanded
sections, short and long content, hover/selection, disabled entries and resizing.
Do not equate passing Lua tests with visual approval or claim a live check that
was not performed. The native.7 appearance was accepted on November 8, 2026;
that acceptance does not prove every future modification. Use subsequent feedback
to update this guide and the addon's documentation rather than repeating local
texture adjustments without reviewing the whole composition.
