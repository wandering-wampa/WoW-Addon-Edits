# ProfessionAssistance_Edit

A Retail edit of **Profession Assistance 6.3.1** by **Dragonfreaky**, adding
Auctionator prices beside the materials in its tooltips.

Target: **WoW Retail / Midnight 12.1.5** (TOC 120100 / 120105).
Integration checked against **Auctionator 342** on **November 8, 2026**.
Prices come from the user's Auctionator database for the active realm/region.

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
  page. Existing drop chances, profession settings and material data are retained.
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
uncached items, dependency failures, refreshed prices, chat links, closed/reused
tooltips and existing visibility controls. Release CI runs the suite.

Native reference: Blizzard's
[GameTooltip.xml](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml),
[GameTooltip.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua)
and
[TooltipDataHandler.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua).
The edit retains the native tooltip and adds ordinary `AddDoubleLine` rows;
it does not create a replacement window or skin.

Automated checks do not establish live appearance. In-game visual validation
remains pending: check an herb, ore, disenchantable item and chat link at the
chosen UI scale; confirm coin alignment, long material names, missing prices,
Shift controls and the Settings toggle. Upstream material coverage and drop
probabilities remain estimates supplied by the original addon.

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
