# AppearanceGuide_Edit

A focused quest guide opened directly from the Retail Appearances collection.
Version 0.5.1 includes **Tyr's Guard Bulwark** (item 208198), its introductory
quest and Tyr reward chain, plus a live campaign prerequisite inspector.
ATT and BtWQuests are not required. A complete, verified walkthrough from every
possible character starting state is still a work in progress.

## Installation and use

Extract the ZIP and manually place `AppearanceGuide_Edit` in `Interface/AddOns`.
Restart WoW after installing this new addon, and enable it in the addon list.

1. Open Collections > Appearances and show uncollected appearances.
2. Right-click an appearance and select **How to obtain**.
3. If the appearance has several item sources, choose the source to inspect.
4. Read the next quest step and use **Show on map** for its location.
5. Click the coordinate button in the instructions to set a **TomTom arrow**.
   TomTom is optional; without it, this button uses the built-in map.
6. Use **Prerequisites** to see campaign requirements and individual campaign
   quests, with your character's completion and active-quest status.
7. Click **Track this item** to make the displayed item your active target.
   `/ag` and the minimap button open that item directly.

Restart WoW once when upgrading to 0.5.1 so it loads the character-specific
saved-setting declaration. Existing quest and other addon data are untouched.

Normal preview clicks and Blizzard's collected-appearance menu are preserved.
The panel uses a Retail portrait frame, plain opaque reading panels with native
inset borders, and slim scrollbars. Decorative corners stay out of the text areas. The quest list stays above a separately scrolling
instruction panel. Long quest names wrap. Drag the frame to reposition it.

## Commands

- `/ag` or `/appearanceguide`: open your active item.
- `/ag 208198`: preview a specific item ID without changing your active target.
- `/ag <item link>`: preview the linked item.
- `/ag track`: make the currently displayed item active.
- `/ag track <item ID or link>`: set and open an active item directly.

## Active item and minimap button

**Track this item** saves a separate active item for each character, across
sessions. Changing one character's target never changes another's. Its button
reads **Active item** when you are viewing that
target. While previewing a different appearance, **Open active item** returns to
it. Opening other appearances does not change what you track. Quest progress is
always read from the logged-in character. The initial target is Tyr's Guard
Bulwark; items without a guide can still be tracked and retain their explicit
**Guide not available** message.

The minimap button shows the active item's icon, with a cloak fallback while the
item is loading. Its tooltip names the target. Left-click opens it, even if the
guide window is already displaying another item. Drag the button around the map
to reposition it; placement adapts to map size, scale, and supported map shapes.
The minimap angle remains shared in `AppearanceGuideEditDB`. Each character's
active item is saved separately in `AppearanceGuideEditCharDB` using WoW's
per-character storage. When upgrading from 0.5.0, the previous shared target is
imported once for the first character that loads the update, preserving any
existing character-specific selection. Other characters start with the default
guide until you choose their targets.

## Quest progress and navigation

The guide reads the logged-in character's quest flags and active objectives.
Later active/completed steps take precedence over earlier missing flags, which
can occur after campaign skips. Such earlier steps are marked **Earlier step
(inferred)**, not **Completed**. Other characters' completion flags are not substituted.

The header shows the current character's confirmed completion count and current
step. Green check icons mark **Completed** quests. Active quests use a quest
marker and **Current quest** or **Ready to turn in**. Inferred earlier steps have
their own label and are not added to the completed count. All prior steps remain
in the list; opening a guide or selecting **Current quest** brings the current step
into view with its preceding steps. If no progress is found, the header says so.

Progress refreshes on quest events and entering the world while the panel is open. **Current quest** follows
the next unfinished step; selecting a row lets you inspect that step until you
select Current quest again. The appearance's collected status is checked separately
from character quest completion. The Current quest button is disabled when that
step is already selected or the reward chain is finished. Select any row to
preview another step; this never marks quests complete or skips requirements.

For unaccepted quests, map pins show the quest giver. For active quests, the
guide prefers the game's current objective waypoint, falling back to quest
tracking/details when a coordinate is unavailable. It does not use an old giver
location as an active objective. Clicking Show on map changes your tracked map
destination. No automatic movement, quest acceptance, or turn-in is performed.
Extra unlock advice and the copyable quest URL are under **Help & reference**.

## Prerequisites

The reward chain now begins with **Ally of Dragons**, offered by Herald Flaps.
Alexstrasza is that introduction's turn-in NPC. Flaps's pin is labeled as a search
area because he can move or appear as a messenger. **The Gift of Silver** follows
the introduction; being unfinished does not establish that it is available.

The addon checks quest completion, accepted quests, level, available quest-start
pins, and the client's campaign failure reasons. An explicit external quest
blocker opens the prerequisite view automatically when the reward chain has not
started and no reward-chain quest is reported available. You can also open that
view manually at any point and return with **Back to reward chain**.

The prerequisite view expands campaign chapters into the individual quests the
client supplies. It follows cross-campaign blocker references, detects cycles,
and retains completed quests. Each quest uses its own character flag: completing
a parallel quest does not falsely complete or skip another branch. Quest events,
quest-line updates, and level changes refresh the displayed state. Asynchronous
metadata updates preserve a manually selected quest even if its row moves.

Available start pins and active objectives can be sent to TomTom. If the game
does not provide a start location, the addon does not manufacture one. Empty map
results are treated as unknown availability, not proof that a quest is locked.

The related Dragonflight campaign is available for inspection, but is explicitly
distinguished from a reported blocker: its whole story is **not** automatically
declared mandatory for the shield. Historical Renown 12 advice is not enforced
as a universal current requirement. Missing chapter data is identified in the UI.

The coordinate button sends the exact displayed location to TomTom and explicitly
targets its arrow, even on repeated clicks. Waypoints are temporary (not saved
across sessions), and the addon does not remove other waypoints or change TomTom
settings. TomTom's arrow visibility and corpse-tracking preferences still apply.
Active quest objective coordinates are clickable too. If no coordinates are
available, the coordinate button is hidden; Show on map still tracks the quest.

## Initial coverage and limitations

- One curated reward, with 20 steps including Ally of Dragons, The Silver Purpose, Tyr's Fall, and
  Reforging the Tyr's Guard. Later quests after the shield reward are unnecessary.
- Other items open a clear **Guide not available** panel with a copyable item URL.
- This is not a universal quest database. The panel combines curated notes with
  live quest objectives; it does not fetch web walkthroughs in game.
- WoW's campaign APIs do not expose a complete dependency graph or a walkthrough
  for every quest. The new inspector reads their live information, but does not
  yet replace verified authored prerequisite routes for all phasing, reputation,
  faction, or campaign-skip cases. It must not be advertised as 100% coverage.
- Quest-giver coordinates are starting points and can be affected by phasing,
  scenarios, or game updates. The quest reference URL is available for each step.
- The native wardrobe Items tab is supported. Third-party wardrobe replacements,
  the Sets tab, illusions, and the transmogrifier UI are outside initial scope.
- Guide notes are English; quest names and active objectives use the client's
  localized text when available.
- Only the active item (per character) and minimap angle (shared) are saved in
  this addon's settings. Quest completion is read from the game, not written or
  copied between characters. Existing addons' settings are not modified.

## Validation

`python tools/test_appearance_guide.py` (requires `lupa`) loads the actual addon
files under Lua 5.1 and checks character progress, skipped prerequisites, reward
completion, live campaign blockers and chapter expansion, cyclic/missing metadata,
parallel quest flags, available versus hidden quest pins, source selection, map navigation, recycled UI rows/models, deferred
wardrobe loading, menu preservation, and event-driven refresh. Packaging checks
the archive root and TOC layout.
Tests also cover explicit tracking versus preview, saved-setting reloads,
launcher initialization, repeated clicks, delayed item icons, and minimap
dragging/placement at different scales and shapes.

These checks use mocked WoW APIs; they do not establish live-client rendering or
end-to-end quest completion. In-game acceptance checks:

- Open `/ag`, inspect long quest names, scroll to the final reward, and select Current quest.
- Track an item, preview another, and verify `/ag` and the minimap button return
  to the tracked one. Restart the game and check that the target and button
  position persist. Check the tracking controls do not overlap either reading panel.
- Set different targets on two characters, switch between them, and verify both
  `/ag` and the minimap button open each character's own item.
- Right-click the shield in Uncollected and compare the guide with `/ag`.
- Change wardrobe pages/slots, then right-click a different appearance.
- Confirm unknown items clear the previous guide and disable its map button.
- Accept/advance/turn in a listed quest and check the next-step refresh.
- Open Prerequisites on a character without the introduction. Compare the
  reported blocker and completed chapter quests with the native quest log.
  Accept/finish a prerequisite and check that the display updates without reloading.
- Confirm the native collected-appearance favorites menu still works.
- With TomTom enabled, click coordinates twice and check the arrow points to that
  location; change steps and verify the new destination. Without TomTom, verify
  the same button uses the native map. Unknown items must clear the old button.

## Authorship and references

This is an original addon in this collection, using the `_Edit` naming convention
for consistency. It is not a modified distribution of ATT or BtWQuests, and it
does not bundle their code or databases. Blizzard's UI art is referenced from the
installed game rather than redistributed.

Quest IDs, names, order, and giver coordinates were checked against these sources:

- [Tyr's Guard Bulwark reward](https://www.wowhead.com/item=208198/tyrs-guard-bulwark)
- [Walking the Path of Tyr](https://www.wowhead.com/quest=76171/walking-the-path-of-tyr)
- [Ally of Dragons](https://www.wowhead.com/quest=68794/ally-of-dragons): introduction,
  giver and reported messenger/search-area behavior. Player reports about newer
  campaign gating conflict, so they are not encoded as mandatory requirements.
- [BtWQuests Dragonflight](https://github.com/Breeni/BtWQuestsDragonflight), maintained
  by Breeni: `FriendOfTheDragonIsles.lua`, `10.1.0.lua`, `10.1.7.lua`, and the quest/NPC
  reference tables. Upstream authors retain their rights.
- [Blizzard wardrobe source mirror](https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_Collections)
- [Blizzard campaign API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/WarCampaignDocumentation.lua)
- [Blizzard quest-line API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua)

Future guides should include verified prerequisite order, quest-giver locations,
clear instructions, and references. Do not imply coverage for unverified items.
