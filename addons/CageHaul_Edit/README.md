# Cage Haul

Cages learned battle pets in batches for WoW Retail, Midnight 12.1.5 (US build 70961, November 17, 2026). All eligible copies are included, even the last copy of a species, favorites, named pets and leveled pets. The cages go into your bags.

1. Extract `CageHaul_Edit` directly into `_retail_/Interface/AddOns` and start WoW.
2. Type `/cagehaul` to see the eligible count, free bag slots, and reasons pets were skipped.
3. Type `/cagehaul start` once to cage a batch. When your bags fill, bank the cages and start another batch.

You can also bind **Start or stop a pet cage batch** under **Options → Keybindings → AddOns → Cage Haul**. Press once to start and again to stop. `/cagehaul stop` stops the queue after any request already sent. `/cagehaul one` cages a single eligible pet.

The scan covers your entire learned collection regardless of Pet Journal filters. WoW skips nontradable and otherwise unavailable pets. Heal injured pets, take pets out of their active battle slots and unwrap gifts before rerunning. Bags reserved for reagents or other specialized items do not count as space. If WoW misses or rejects a request, the batch checks the journal and retries eligible pets after a short pause. After three attempts it sets that pet aside for the session and continues with the rest. `/cagehaul retry` makes those pets eligible for another attempt.

Cage Haul is an original standalone addon with no dependencies. It uses the same cage API and journal acknowledgement as the [Blizzard Pet Journal](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Collections/Shared/Blizzard_PetCollection.lua). Headless Lua checks cover the command and binding entry points, queue acknowledgements, bag limits, exclusions, stopping, and failed requests. A live cage run is a separate check.
