local _, ns = ...

-- Curated game facts; references and coverage are documented in README.md.
-- Coordinates identify quest givers, not quest objectives. Active quests use
-- the client's live objective waypoint instead whenever it is available.
ns.guides = {
    [208198] = {
        name = "Tyr's Guard Bulwark",
        rewardQuest = 76171,
        note = "A cosmetic shield rewarded by Walking the Path of Tyr. Use the reward item to learn the appearance; a shield-using character may be needed.",
        unlockNote = "If the first quest is missing, check Dragonflight campaign progress and the Valdrakken Accord Renown 12 unlock. Enable Trivial Quests on the minimap. Later quest progress takes priority over these older unlock requirements.",
        steps = {
            {id=67074, name="The Gift of Silver", chapter="The Silver Purpose", npc="Alexstrasza the Life-Binder", map=2112, x=.5821, y=.3478,
                note="Start at the top of the Seat of the Aspects in Valdrakken. The Renown 12 introduction, Ally of Dragons, may lead you here."},
            {id=70703, name="The Legacy of Tyrhold", chapter="The Silver Purpose", npc="Alexstrasza the Life-Binder", map=2112, x=.5821, y=.3478,
                note="Continue Alexstrasza's story and follow the quest to Tyrhold."},
            {id=67075, name="The Magic Within", chapter="The Silver Purpose", npc="Watcher Koranos", map=2025, x=.5815, y=.5883},
            {id=67076, name="A Spark of Discovery", chapter="The Silver Purpose", npc="Watcher Koranos", map=2025, x=.5815, y=.5883},
            {id=67077, name="Memories of the Past", chapter="The Silver Purpose", npc="Alexstrasza the Life-Binder", map=2025, x=.6213, y=.5928},
            {id=67078, name="Parting Instructions", chapter="The Silver Purpose", npc="Keeper Tyr", map=2025, x=.622, y=.592},
            {id=67079, name="Hard Lock Life", chapter="The Silver Purpose", npc="Watcher Koranos", map=2025, x=.5815, y=.5883},
            {id=67081, name="Halls of Infusion: An Infusion of Materials", chapter="The Silver Purpose", npc="Keeper Tyr", map=2025, x=.622, y=.592,
                note="This step requires Halls of Infusion: collect 10 Ancient Titansteel Ingots and defeat the Primal Tsunami. Pick up the quest before entering the dungeon."},
            {id=67084, name="The Silver Purpose", chapter="The Silver Purpose", npc="Keeper Tyr", map=2025, x=.622, y=.592},
            {id=72440, name="Silver Mettle", chapter="Tyr's Fall", npc="Nozdormu", map=2025, x=.6039, y=.5883,
                note="Begin the next chain with Nozdormu at Tyrhold. Follow the quest's travel instructions to Tirisfal Glades."},
            {id=72441, name="Breaching the Tomb", chapter="Tyr's Fall", npc="Travard", map=20, x=.3914, y=.4123,
                note="Meet Travard in Tirisfal Glades and follow the party into the tomb. Characters in a different phase may need to follow the quest's travel route."},
            {id=72442, name="The Remains of Tyr", chapter="Tyr's Fall", npc="Watcher Koranos", map=20, x=.3795, y=.5488},
            {id=72526, name="Keeper's Rest", chapter="Tyr's Fall", npc="Watcher Koranos", map=20, x=.3795, y=.5488},
            {id=72443, name="Tyr's Fall", chapter="Tyr's Fall", npc="Watcher Koranos", map=20, x=.4206, y=.8575},
            {id=72444, name="A Sliver of Silver", chapter="Tyr's Fall", npc="Watcher Koranos", map=20, x=.4206, y=.8575},
            {id=75632, name="A Dislocated Disc", chapter="Reforging the Tyr's Guard", npc="Nozdormu", map=2112, x=.6149, y=.3909,
                note="Return to Nozdormu at the Seat of the Aspects in Valdrakken to start the reward chain."},
            {id=75633, name="We Have the Technology", chapter="Reforging the Tyr's Guard", npc="Eternus", map=2025, x=.6041, y=.5903},
            {id=75634, name="Reforging the Tyr's Guard", chapter="Reforging the Tyr's Guard", npc="Travard", map=2025, x=.604, y=.5892,
                note="Meet Travard at Tyrhold, then follow the quest to the Tyr's Guard camp in the Azure Span."},
            {id=76171, name="Walking the Path of Tyr", chapter="Reforging the Tyr's Guard", npc="Travard", map=2024, x=.1759, y=.3153,
                note="Equip the four recruits with Tyr's Guard gear. Stand close to each recruit before interacting so the correct recruit receives credit. Turn in to Travard for the shield; later quests are not required for this reward."},
        },
    },
}
