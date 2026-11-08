# Addon editing project brief

Updated **November 8, 2026**. Scope: this collection's **WoW Retail** addons.
The current UI reference client is **Midnight 12.1.5**. Recheck Blizzard APIs and
artwork for the target client before applying this guidance to later patches.

## Intended result

Edited addons should look and behave like a natural part of the game's UI.
That requires coherent typography, spacing, hierarchy, controls and interaction
states as well as native artwork. Start every visual edit with the
[Retail UI style guide](retail-ui-style.md) and the relevant addon's README.

## Established examples

| Addon | Preserve and learn from |
| --- | --- |
| [ConcentrationTracker_Edit](../addons/ConcentrationTracker_Edit/README.md) | Opaque native frame, damage-meter bar artwork, shared table margins, responsive bars, working minimap placement and refresh-safe sorting/layout. Progress bars represent actual progress. |
| [AppearanceGuide_Edit](../addons/AppearanceGuide_Edit/README.md) | Plain opaque reading panels, native inset borders, slim scrollbars, wrapped text and separate scrolling instructions. Keep decorative corners out of reading areas. |
| [KnowledgePointsTracker_Edit](../addons/MyusKnowledgePointsTracker_Edit/README.md) | Portrait-free frame, native-height gold profession headers, summaries below the header artwork, white/dimmed item names, untiled list background, exclusive hover/selection, slim scrollbars and content-fitting height that yields to manual resizing. |

Knowledge Point Tracker **0.9.0-native.7** is the accepted visual baseline from
November 8. Earlier iterations removed useful category structure, stretched
header artwork, or retained excessive text color. Do not restart from those
rejected treatments. The native.6 Filter-template initialization failure is
documented in the style guide so future edits do not repeat it.

## Working approach

1. Inspect the installed addon, Git status and its documentation. Preserve newer
   work, upstream authorship, game data and SavedVariables.
2. Identify a suitable native screen, read its current XML and mixins, and state
   the intended hierarchy before editing. Use screenshots to assess the whole
   layout, not merely individual textures.
3. Implement the layout and behavior together. Check startup, entry points,
   refreshed/recycled rows, scrolling, resize and visibility transitions.
4. Distinguish automated validation from appearance observed in game. Record
   what was actually checked and incorporate visual feedback before describing
   the appearance as accepted.
5. Follow [AGENTS.md](../AGENTS.md) for installation, privacy, commits, publishing
   and release verification. Keep the root README a concise addon/download table.

Use programmatic tools; do not take over the desktop or simulate input. A design
change does not justify changing tracking calculations or character/account data.

## Naming

The GitHub catalog name is **KnowledgePointsTracker_Edit**. Its in-game display
name is **Knowledge Point Tracker**. The existing package identity is
`MyusKnowledgePointsTracker_Edit`; retain upstream author attribution. A catalog
label edit is not a SavedVariables migration. Any future package rename must
follow the closed-client backup and migration procedure in the addon README.
