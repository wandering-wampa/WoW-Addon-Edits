# ProfessionAssistance_Edit

A Retail edit of **Profession Assistance 6.3.1** by **Dragonfreaky**, adding
Auctionator prices beside the materials in its tooltips.

Target: **WoW Retail / Midnight 12.1.5** (TOC 120100 / 120105).
Integration checked against **Auctionator 342** on **November 8, 2026**.
Prices come from the user's Auctionator database for the active realm/region.

## Disenchant data review in 6.3.1-auctionator.3

Reviewed on **November 8, 2026**, for **Retail / Midnight 12.1.5**. Removed all
33 Retail disenchant bonus groups labeled **±30%** or **±35%**, including the
corresponding reverse source entries. This covers more than Dawn Crystals:
the extra dust/shard/crystal relationships appeared across several expansions.
The remaining material rows still show Auctionator unit prices.

Disenchant tooltips no longer display fixed percentages, including **100%**.
They describe material types, not a measured probability, guaranteed quantity,
or guarantee that every listed quality rank drops together. Milling and
prospecting probability displays are unchanged.

Fixed a separate upstream data error: the Midnight epic-gear entry used expansion
ID 10 (The War Within), making its results unreachable for expansion 11 gear.

The reviewed main material families are:

| Expansion | Uncommon gear | Rare gear | Epic gear |
| --- | --- | --- | --- |
| Dragonflight | Chromatic Dust (194123) | Vibrant Shard (194124) | Resonant Crystal (200113) |
| The War Within | Storm Dust (219946–219948) | Gleaming Shard (219949–219951) | Refulgent Crystal (219952, 219954, 219955) |
| Midnight | Eversinging Dust (243599, 243600) | Radiant Shard (243602, 243603) | Dawn Crystal (243605, 243606) |

All 18 material IDs were checked against Wowhead's item tooltip data. The
[Midnight specialization guide](https://www.wow-professions.com/midnight/enchanting-specialization-guide-and-builds)
and [The War Within specialization guide](https://www.wowhead.com/guide/the-war-within/professions/enchanting-specialization)
support the main quality-based families. A
[first-hand report of 1,000 rare Midnight disenchants](https://www.wowhead.com/item=239671/courtly-wrists)
lists Radiant Shards and bonus gathering reagents, with no Dawn Crystals listed.
That contradicts treating a 30% crystal bonus as universal; it does not establish
every item's exact loot table or prove crystals impossible in every situation.

This is a simplified reference. Profession skill, specialization bonuses,
item-specific exceptions, quantities, rank probabilities and older expansion
loot tables are **not fully verified or modeled**. For example,
[Dragonflight players reported crystals from crafted blue weapons with the relevant specialization](https://us.forums.blizzard.com/en/wow/t/draconic-disenchantment-question/1430821).
The removed entries are unsupported blanket claims, not proof that bonus
outcomes never occur. Reverse source lists have the same coverage limitation.

## Fix in 6.3.1-auctionator.2

The first build could stop after the disenchanting heading and chance, hiding
all material rows when the first material had a recorded price. Its call to
the removed global `GetCoinTextureString` failed on current Retail. The edit
now uses `C_CurrencyInfo.GetCoinTextureString`, as documented in Blizzard's
[CurrencyInfo API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua).
If price formatting fails, the material remains visible with **Price unavailable**
and subsequent rows continue to render.

Live feedback on November 8, 2026 confirmed the heading-only failure on rare
Midnight gear in the first build. The regression test now reproduces that
case with the legacy global absent and checks every material row and price.
It fails against the first build and passes with this fix. Subsequent live
feedback confirmed material and price rows on rare Midnight gear; it also
identified the unsupported bonus section addressed in auctionator.3.

## Changes

- Milling, prospecting and disenchanting material rows show a right-aligned
  price using WoW's coin icons. The column is labeled **Auctionator / each**:
  values are per individual material, not per stack, processing batch or
  probability-weighted outcome.
- Reverse source lists and item-based gathering sources also show prices.
  Non-item descriptions such as Frozen Herb and geographic locations do not
  receive prices.
- Uses `Auctionator.API.v1.GetAuctionPriceByItemID` with each material's exact
  ID, including distinct quality IDs. Reads the current database whenever the
  tooltip is built; it does not initiate auction searches.
- **No price** means Auctionator has no usable recorded value for that material.
  Search/scan the material with Auctionator, then hover it again. Values reflect
  the database's last observation and are not guaranteed live auction quotes.
- If Auctionator is disabled or its pricing API is unavailable, the original
  material display remains available without the price column.
- Adds **Show Auctionator prices**, enabled by default, to the existing Settings
  page. Existing profession settings are retained. Disenchant data corrections
  and coverage limits are described above.
- Folder, TOC, addon-list title, Settings title, metadata lookups and expansion
  artwork paths use `ProfessionAssistance_Edit`. Deferred chat tooltips check
  that they are still displaying the same request before adding material rows.

## Installation and commands

1. Extract `ProfessionAssistance_Edit.zip` into `Interface/AddOns`, so the file
   `ProfessionAssistance_Edit/ProfessionAssistance_Edit.toc` exists there.
2. Enable **ProfessionAssistance_Edit** and **Auctionator**. Keep the original
   **Profession Assistance** disabled: both editions share globals and settings.
3. Use `/pa` or `/professionassistance_edit`, or the addon compartment entry, to
   open the Settings page. Prices are enabled automatically.

Auctionator is an optional dependency; its code is not bundled.
This package targets Retail, not Classic.

### Migrating existing settings

The `PA_SavedSettings` global is unchanged. Renaming the addon changes its
SavedVariables filename. With WoW fully closed, back up the original addon and
account SavedVariables, then copy
`WTF/Account/<account>/SavedVariables/Profession_Assistance.lua` to
`ProfessionAssistance_Edit.lua` in the same folder. Do not overwrite an existing
destination without first preserving it. Disable the original addon before
launching WoW. New installs require no migration.

## Validation and limitations

Run `python tools/test_profession_assistance.py` from the repository root with
`lupa==2.8` installed. The suite loads the real TOC in Lua 5.1, fires the actual
`ADDON_LOADED` and tooltip callbacks, and checks Settings entry points, milling,
prospecting, disenchanting, reverse sources, gathering sources, quality IDs,
uncached items, dependency/formatter failures, refreshed prices, chat links, closed/reused
tooltips and existing visibility controls. It also rejects duplicate/missing
Retail expansion entries and leftover 30%/35% disenchant groups, then checks the
reviewed material IDs, prices and reverse sources for all three gear qualities
in Dragonflight, The War Within and Midnight, using both armor and weapons in
normal and chat tooltips. The new data checks failed before the correction and
pass afterward. Release CI runs the suite.

Native reference: Blizzard's
[GameTooltip.xml](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml),
[GameTooltip.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua)
and
[TooltipDataHandler.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua).
The edit retains the native tooltip and adds ordinary `AddDoubleLine` rows;
it does not create a replacement window or skin.

Automated checks do not establish live appearance. The auctionator.3 layout
still needs an in-game recheck: check a disenchantable item and chat link at the
chosen UI scale; confirm coin alignment, long material names, missing prices,
Shift controls and the Settings toggle. The rest of the upstream database is
not a newly certified source of loot probabilities.

## Upstream attribution

[Profession Assistance](https://www.curseforge.com/wow/addons/profession-assistance)
is by **Dragonfreaky**, with **Misstory** credited upstream; translator credits
remain in the Settings credits page. Based on
[PA_V6.3.1, file 8405730](https://www.curseforge.com/wow/addons/profession-assistance/files/8405730),
published July 10, 2026. CurseForge lists the upstream license as **All Rights
Reserved**. Original authorship and that license are unchanged; this edit does
not relicense the upstream code, data or artwork.

The upstream archive contained no README or standalone license file. Retail
source, localization, data and images are preserved with the changes described
above; Classic's alternate TOC and options implementation are not included.

[Auctionator](https://github.com/Auctionator/Auctionator) provides the pricing API;
the implementation was checked against its installed
`Source/API/v1/GetAuctionPrice.lua`.
