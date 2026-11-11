# Scripted playtests

These drive the real game headlessly-ish (a window opens) and print results; some save
screenshots to `user://` (on macOS: `~/Library/Application Support/Godot/app_userdata/Defenders Of The Keep/`).

Run one with:

    /path/to/Godot --path . --script res://tools/tests/<name>.gd

They use a throwaway save file (`user://test_save.json`) so your real Shards are untouched.
Known quirks: do not name `Game`-dependent `class_name`s inside these files (compile order in
`--script` mode); key events cannot be injected, so keyboard handlers are called directly.

| script | checks |
|---|---|
| kits.gd | left/right/dash actions of the nine base weapons |
| tiers.gd | hold-to-aim rule, the Forge flow, every fused weapon runs all four actions |
| sectors.gd | boss chain through all six sectors, gates, iron mining, final boss and victory |
| newcards.gd | the five sector cards, resource costs, draft pool unlocks |
| waves.gd | wave growth, multi-sector spawns, turrets (fire, empty, reload, click) |
| newenemies.gd | spitter projectiles, splitter bursting, wave 6 composition |
| runend.gd | game-over, Shards, unlock shop, persistence |
| hitstop.gd, feedback.gd | hit-stop, damage numbers, hurt signal |
| music.gd, pause.gd | music themes and switching, pause menu and volume |
| radar.gd | wide view, minimap, chest markers (screenshot) |
| quick_merge.gd | merge two held weapons anywhere (player 1, player 2+), forge hands / storage areas, fusing hand cards in the keep |
| weapon_rules.gd | every fusion is rarer than both parts, out-damages them; damage per second rises with rarity; every weapon in the basic-attack table |
| gong_roster.gd | the gong starts the next wave; per-level enemy roster (three kinds, phased in, older buffed but weaker); chests offer only owned cards from open sectors; players 2-4 reach as far as player 1 |
| enemy_kinds.gd | the six upper-level enemy kinds each have their own move (bomber fuse, charger lane, burrower dive, lobber puddles, blinker ring, shard burst), each with its own sheet, also built that way on a LAN client |
| boss_frost_wyrm.gd | bosses are tougher; the Frost Wyrm burrows, is then exposed, raises pillars that stop its breath, and charges |
| forge_shots.gd | window screenshots of the forge areas and the merge hint |
| ui_parity.gd | every shared screen (Forge, Card Fuser, chest choice, HUD top, upgrade cards) built through player 1, a split-screen player and a LAN client view (fake snapshot) gives the same tree |
| single_source.gd | (no game, 1 s) fails when a known single-source helper is written again, or UI code adds raw colours / font sizes over its budget |
| split_tour.gd | slow window tour of the split screen (HUDs, fight, merge hint, both Forges, chests, towers); n=2..4, hold=seconds, saves PNGs |

## Two-process network test

    Godot --headless --path . --script res://tools/tests/net_host.gd &    # starts hosting, waits ~20s
    sleep 5
    Godot --headless --path . --script res://tools/tests/net_client.gd    # joins, moves, attacks

The client prints what it received; the host prints the avatar movement and the dummy's health.

New in the progression/building pass: `build.gd` (build cards, tiers, guards, charm), `weapon_shop.gd`
(Shard weapon/fusion unlocks, start weapon), `weapon_tiers.gd` (tier gating + awakening),
`rewards.gd` (end-of-run draw, card tiers, upgrades; needs a window for its two screenshots),
`ability_hud.gd` (screenshot of the cooldown HUD; needs a window).

Multiplayer tests (see MULTIPLAYER.md): `net_coverage.gd` (single process; fails if a gameplay node is not replicated),
`rep_host.gd` + `rep_client.gd` (replication end to end; start the host, wait ~6 s, start one or more clients),
`lan_host.gd` + `lan_scan.gd` (LAN discovery), and the older `net_host*/net_client*` pairs.

Progression and loot: `tool_tiers.gd` (Sword and Pickaxe tier ladder, chest pool), `chest_quality.gd` (chest and rainbow sheep
tier odds by level, tiered drafts), `progression_sim.gd` (a new player over many runs: how fast cards, tiers and weapons open up),
`tool_shots.gd` (window; HUD padlocks and the tiered draft), `net_host_shots.gd` + `net_client_shots.gd` (window client screenshot
of buildings with feeding bars). Delete stale `user://rep_host_*.json` before rep runs (the host test now does it itself).

Night and waves: `night.gd` (clock, shroud, lights, night draws, dash direction), `wave_director.gd` (real director sped up: when each
wave spawns), `wave_draw.gd` (the automatic wave draw and the wave-start rules: no overlap, bosses asleep early, E key), `night_shots.gd` (window screenshots).

Rewards: `legendary.gd` (reward counts, win reward, the six legendaries in play), `rewards_flip.gd` (window: the face-down reward
screen and the flip sequence; pass `-- win` for a victory).

Controller: `controller.gd` (injected pad events: left stick walks, right stick aims, RT/LT attack and ability, A/B/X/Y actions,
mouse takes over again, pad off while a menu or the keep is up).

Forge storage over LAN: `net_forge_host.gd` + `net_forge_client.gd` (run as a pair like `net_host.gd` / `net_client.gd`: the client drops a weapon
into the forge and combines a held with a stored one; the host checks). The split-screen forge (grouped list, drop in / take out, combine with a
stored weapon) is covered by the same rules in `Net.forge_*`.

Local split screen: `split_two_pads.gd` (two simulated controllers, 22 checks: each controller drives only its own player; pickup, fighting, towers and cards, one person per tower, the forge, pause, damage).

`card_fuser.gd`: the Card Fuser (opposite the Forge): recipes, gold cost, same-tier rule, the screen, the `card_fuse` net command's range check, casting a fused card.
| two_player_cards.gd | two players share the hand and deck: start (4-card deck, hand of 3), both cast, 3-card chest, deck row with copy counts, merge |
| card_tour.gd | a slow, watchable 2-player run of the keep's cards in a real window (hold=<s>) |
| shared_hands.gd | player 1 (HUD slots) and a split-screen player (weapon_slots) go through the same Net hand functions: give, store, take out, craft, pickup-merge; both end in the same state |
| guards.gd | guards have health (no timer), swing with a wind-up about once a second, draw enemies' aggro and take their hits, and fall when their health runs out |
| conversion.gd | the legendary Mass Conversion card (costs crystal gems) and the Mindbender weapon turn enemies to your side; allies fight the rest and the rest turn on them |
| card_adds.gd | every card adds something new at each tier 2-6 and keeps the earlier ones; the card says Added; spells and buildings apply all of them |
