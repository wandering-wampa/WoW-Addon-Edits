# Cage Haul

Cages learned battle pets in batches for WoW Retail, Midnight 12.1.5 (US build 70961, November 17, 2026). All eligible copies are included, even the last copy of a species, favorites, named pets and leveled pets. The cages go into your bags.

1. Extract `CageHaul_Edit` directly into `_retail_/Interface/AddOns` and start WoW.
2. Type `/cagehaul` to open the compact panel with **Cage Pets**, **Deposit**, **Retrieve**, and **Learn**. `/cagehaul status` shows the eligible count, free bag slots, and reasons pets were skipped.
3. Click **Cage Pets** or type `/cagehaul start` once to cage a batch. When your bags fill, bank the cages and start another batch. Click the running batch's button again to stop it.

You can also bind **Start or stop a pet cage batch** under **Options → Keybindings → AddOns → Cage Haul**. Press once to start and again to stop. `/cagehaul stop` stops the queue after any request already sent. `/cagehaul one` cages a single eligible pet.

To deposit, open the Blizzard guild bank, select the destination tab, and type `/cagehaul deposit`. Cage Haul fills empty slots in that tab with pet cages from your bags. It stops when the tab fills, you run out of cages, or you switch tabs or close the bank. You need permission to view and deposit in the selected tab. `/cagehaul stop` also stops deposits after any transfer already sent.

To withdraw, select the source tab in the guild bank and type `/cagehaul retrieve`. It moves pet cages into your normal bags until they're full, the tab is out of cages, or you reach your guild withdrawal limit. `/cagehaul stop` also stops withdrawals.

Close the guild bank before learning. Each **Learn** click uses the next eligible cage in your bags. WoW requires one click per pet. For a macro, use `/click CageHaulLearnButton`. The addon skips cages at their species cap and moves past cages WoW doesn't learn. `/cagehaul learn` displays the macro command and resets skipped cages.

The scan covers your entire learned collection regardless of Pet Journal filters. WoW skips nontradable and otherwise unavailable pets. Heal injured pets, take pets out of their active battle slots and unwrap gifts before rerunning. Bags reserved for reagents or other specialized items do not count as space. If WoW misses or rejects a request, the batch checks the journal and retries eligible pets after a short pause. After three attempts it sets that pet aside for the session and continues with the rest. `/cagehaul retry` makes those pets eligible for another attempt.

Cage Haul is an original standalone addon with no dependencies. It uses the cage API and journal acknowledgement from the [Blizzard Pet Journal](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Collections/Shared/Blizzard_PetCollection.lua), the same transfer APIs as the [Blizzard Guild Bank](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua), and standard [Retail panel templates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml). Lua checks cover command dispatch, batch recovery, guild bank transfers, and the four button callbacks. Live appearance and protected item use need a separate in-game check.
