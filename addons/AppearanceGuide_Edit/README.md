# AppearanceGuide_Edit

A focused quest guide opened directly from the Retail Appearances collection.
Version 0.2.1 includes **Tyr's Guard Bulwark** (item 208198), from the early Tyr
prerequisites through **Walking the Path of Tyr**. ATT and BtWQuests are not required.

## Installation and use

Extract the ZIP and manually place `AppearanceGuide_Edit` in `Interface/AddOns`.
Restart WoW after installing this new addon, and enable it in the addon list.

1. Open Collections > Appearances and show uncollected appearances.
2. Right-click an appearance and select **How to obtain**.
3. If the appearance has several item sources, choose the source to inspect.
4. Read the next quest step and use **Show on map** for its location.

Normal preview clicks and Blizzard's collected-appearance menu are preserved.
The panel uses a Retail portrait frame, plain opaque reading panels with native
inset borders, and slim scrollbars. Decorative corners stay out of the text areas. The quest list stays above a separately scrolling
instruction panel. Long quest names wrap. Drag the frame to reposition it.

## Commands

- `/ag` or `/appearanceguide`: open the Tyr's Guard Bulwark guide.
- `/ag 208198`: open a specific item ID.
- `/ag <item link>`: open the linked item.

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

## Initial coverage and limitations

- One curated reward, with 19 steps across The Silver Purpose, Tyr's Fall, and
  Reforging the Tyr's Guard. Later quests after the shield reward are unnecessary.
- Other items open a clear **Guide not available** panel with a copyable item URL.
- This is not a universal quest database. The panel combines curated notes with
  live quest objectives; it does not fetch web walkthroughs in game.
- The Silver Purpose's campaign/Renown unlock is described as a troubleshooting
  prerequisite, not enforced as a hard block. Later progress overrides it.
- Quest-giver coordinates are starting points and can be affected by phasing,
  scenarios, or game updates. The quest reference URL is available for each step.
- The native wardrobe Items tab is supported. Third-party wardrobe replacements,
  the Sets tab, illusions, and the transmogrifier UI are outside initial scope.
- Guide notes are English; quest names and active objectives use the client's
  localized text when available.
- No SavedVariables are created or modified. Existing addons and character data
  are independent of this addon.

## Validation

`python tools/test_appearance_guide.py` (requires `lupa`) loads the actual addon
files under Lua 5.1 and checks character progress, skipped prerequisites, reward
completion, source selection, map navigation, recycled UI rows/models, deferred
wardrobe loading, menu preservation, and event-driven refresh. Packaging checks
the archive root and TOC layout.

These checks use mocked WoW APIs; they do not establish live-client rendering or
end-to-end quest completion. In-game acceptance checks:

- Open `/ag`, inspect long quest names, scroll to the final reward, and select Current quest.
- Right-click the shield in Uncollected and compare the guide with `/ag`.
- Change wardrobe pages/slots, then right-click a different appearance.
- Confirm unknown items clear the previous guide and disable its map button.
- Accept/advance/turn in a listed quest and check the next-step refresh.
- Confirm the native collected-appearance favorites menu still works.

## Authorship and references

This is an original addon in this collection, using the `_Edit` naming convention
for consistency. It is not a modified distribution of ATT or BtWQuests, and it
does not bundle their code or databases. Blizzard's UI art is referenced from the
installed game rather than redistributed.

Quest IDs, names, order, and giver coordinates were checked against these sources:

- [Tyr's Guard Bulwark reward](https://www.wowhead.com/item=208198/tyrs-guard-bulwark)
- [Walking the Path of Tyr](https://www.wowhead.com/quest=76171/walking-the-path-of-tyr)
- [BtWQuests Dragonflight](https://github.com/Breeni/BtWQuestsDragonflight), maintained
  by Breeni: `FriendOfTheDragonIsles.lua`, `10.1.0.lua`, `10.1.7.lua`, and the quest/NPC
  reference tables. Upstream authors retain their rights.
- [Blizzard wardrobe source mirror](https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_Collections)

Future guides should include verified prerequisite order, quest-giver locations,
clear instructions, and references. Do not imply coverage for unverified items.
