# Defenders of the Keep: co-op design (draft v1)

Everything here is open to change. Nothing existing is sacred.

## Pitch
A roguelike co-op tower-defense / exploration game for 1 to 4 players (online).
Everyone has the same character. The **Keep** is a station: whoever stands inside
it runs the base. The others go out, explore, fight and gather. You will not get
far on your first run; each run unlocks more stuff and you get further.

## Look (design language)

ONE look for menus and HUD alike. Values live in `ui/cards/ui_kit.gd` (constants and `make_theme()`); screens use them,
never literals (`tools/tests/single_source.gd` enforces it).

- **Surfaces**: dark navy panels with a gold edge (`BG`, `PANEL`, `PANEL_DEEP`, `BORDER`), a gold title bar (`BAR_BG`, `GOLD`
  heading), a blue "what to do here" line (`HINT_BG`, `HINT_EDGE`). Buttons, labels, panels, bars, rich text and tooltips
  come from `UiKit.make_theme()`; HUD roots use `make_theme(true)`.
- **Text**: Godot's default font, `TEXT` / `TEXT_DIM` / `TEXT_HINT`; text over the game world always has the black outline.
- **Accents, one meaning each**: `GOLD` headings / selection / money, `GOOD` can do it, `WARN` cannot yet, `BAD` damage and
  danger, `SKY` info and storage, `MAGIC` the crystal and rare things, `WARM` banners, `MUTED` locked.
- **Bars**: a black frame with a flat fill, square corners (health `HP_RED`, keep `KEEP_FILL`, mana `MANA_FILL`).
- **Font sizes**: one scale, 11 / 13 / 15 / 18 / 22 / 28 / 40 (`FONT_TINY` .. `FONT_HUGE`). Split views scale the whole
  screen by view width / 1100 instead of choosing other sizes.
- **Pixel art** (drawn 4x, nearest filtering) is for game sprites and icons only. The compact weapon frames stay.
- Exceptions kept on purpose: the original hand-built HUD scripts (`ui/hud/inventory`, `tokens`, `upgrades`).

## No fixed roles
- Every player has the same kind of character (move, melee, gather, pick up weapons).
- The Keep has its own pooled **mana and resources**. Anyone can spend them, so
  usually one person needs to be inside at a time.
- Inside the Keep you get the **base interface**: build, play ability cards,
  and see far across the map (like the current tower view that zooms out), so you
  can scout enemies and call out threats for the people outside.
- Solo play must work (you alternate between inside and outside), but multiplayer
  (up to 4) is a core feature, not an add-on.

## Someone should always be in the Keep
The base must keep a player busy, otherwise it is just a menu. Candidate jobs:
- **Card hand and mana.** Cards are drawn over time and have costs and
  cooldowns. Mana only regenerates and cards only draw while someone is inside.
- **Scouting.** The wide view shows enemies and objectives; fog hides the rest.
  The player inside can ping targets for the explorers.
- **Defence upkeep.** Towers and barricades need to be repaired, refueled or
  manually triggered (for example firing a tower volley on cooldown).
- **Incoming waves are telegraphed**, so the person inside decides where to
  spend cards and tells explorers when to come home.
- **Deposits.** Explorers drop resources at the Keep; the person inside spends
  them on building and unlocking.
(These need playtesting to see which are actually fun. Expect to cut some.)

## Crystal abilities (cards)
The crystal's abilities can **only be cast from inside the Keep**. Unlocking them
between runs is the roguelike progression. Upgrades to the base also happen here.
Each card has a mana cost, a cooldown, and is cast on a spot on the wide map.
Ideas to start from (to be cut and tuned in playtests):
- **Fireball**: big area damage at a target spot. Slow cast, long cooldown.
- **Rejuvenation Field**: a healing zone for players that lasts a while.
  Cast where the explorers are fighting.
- **Aegis**: a shield on a chosen player or on the Keep for a few seconds.
- **Frost Ring**: slows enemies in an area.
- **Barricade**: a wall segment that blocks the path and enemies must break.
- **Lightning Chain**: hits several enemies in a line, cheap and fast.
- **Beacon**: lights an area (useful at night and when fog hides enemies).
- **Recall**: pulls an explorer back to the Keep (also a rescue).
- **Overcharge**: boosts the Keep towers' fire rate for a short time.
Later quadrants add stronger or stranger cards tied to their resources
(for example a lava field from the volcanic quadrant).

## Getting and upgrading cards
- The starting hand pool is small. **Chests** (loot events, see below) and boss
  drops give cards.
- When a chest opens you get a **draft: pick 1 of 3** cards, chosen from the
  cards you have unlocked (meta-progression widens that pool).
- Picking a card you already own **upgrades** it (Fireball Lv2: bigger radius
  and damage; Frost Ring Lv2: stronger slow, and so on), so a run builds a
  personal deck. Max level around 3 to 5.
- Between runs, Shards unlock new cards into the pool and new starting cards.

## Gold
- Enemies drop **gold coins** (more from higher-level enemies). Coins vanish after
  about 10 seconds, so someone has to run out and grab them. Picked-up gold is
  carried and deposited by entering the keep, like other resources.
- **Gold Magnet** card: fired from the crystal, it collects all gold in an area
  straight into the keep, so the base player can cover for explorers.
- Gold is spent on base upgrades (together with stone/stick) and later quadrant
  unlocks and card costs.

## Feedback and audio (built)
- Floating damage numbers (gold and bigger for 4+ damage), a short hit-stop on 5+ damage
  hits, a burst when enemies die, a red flash when you are hurt, screen shake on big moves.
- `core/sfx.gd`: ten synthesized sound effects (hit, big hit, cast, coin, chest, hurt, boss
  roar, ultimate, unlock, whoosh) hooked to the matching events, including weapon attacks,
  abilities, dashes and turret shots.
- `core/music.gd`: synthesized looping music, one theme per sector (grassland, desert,
  tundra, volcano, swamp, crystal) that follows the most recently unlocked sector, plus a
  boss theme during boss fights, with crossfades. Swap any theme or effect for a real
  audio file by assigning to `Music.tracks[...]` / `Sfx.streams[...]`.

## Keep upkeep and escalating waves (built)
Reasons someone has to stay in the keep:
- **Keep Integrity** (150): every enemy standing at the crystal chews it down (1.5 to 5
  per second by type). At zero the run ends. From inside the keep, spend 3 stone to
  repair 30.
- **Arrow turrets** on all six towers: 12 arrows each, then silent. Click a tower in the
  wide view to reload for 2 sticks from the pool.
- Mana, card draws, upgrades and the radar only work in the keep; the keep also slowly
  heals whoever is inside.
- **Waves escalate:** +0.6 enemies per wave (plus one per extra open sector), +1 level
  every 3 waves, brutes (slow, 24 hp) every third wave, runners (fast) from wave 4, and
  the gap between waves shrinks. Enemies come from every unlocked sector.
- Baseline check: a player who only sits in the keep sees it at 51/150 after 3 waves.

## Built so far (single player), latest
- Run loop: dying or losing the crystal ends the run, awards Shards (waves, kills, gold,
  bosses), saved to `user://save.json`; a shop permanently unlocks cards; new runs
  start with only Fireball and Frost Ring.
- Six sectors around the keep (the grey covers in `world.tscn`), each with its own
  ground, trees, resource, natives and boss; beating a boss opens the next sector and
  its gate; after the sixth, The Devourer; beating it wins the run.
- Each sector unlocks a card that needs its resource (Sandstorm/iron, Blizzard/frost,
  Lava Pool/ember, Poison Cloud/moss, Crystal Spikes/gem).
- Minimap radar and chest edge markers for whoever is in the keep; H shows controls.

## Built so far (single player), earlier
Base mode, cards and drafts, chests, gold, 9 base weapons with 4-slot kits, the Forge with 9 tier-2 and 2 tier-3 weapons.
(older note follows)
Base mode in towers, pooled mana and resources, drag-to-cast cards shot from the
crystal, run deck with levels, chests with a pick-1-of-3 draft, gold drops and
Gold Magnet. Next: explorer weapons, then quadrant 2.

## Scouting and directing explorers
The wide view from the Keep is the base player's second job: calling things out.
- See enemy waves coming and which way they will go.
- **Loot events:** chests and rare resources drop on the map, visible only from
  the wide view (or when an explorer is near). The base player pings them so
  explorers know where to go and what to grab before it vanishes or an enemy
  takes it.
- Ping system: mark a target, a danger, or a "come here" on the map for everyone.
- This makes the base player the one who knows where things are, and the
  explorers the ones who can act on it.

## Explorers
- Move, fight, gather. Weapons found or crafted, each with a basic attack and
  one ability (right click, cooldown), so learning a weapon is the skill.
- Starter weapons: Sword (spin), Pickaxe (mine, dash-mine); later Bow, Hammer
  (slam), Blink Blade.
- Enemies come up the southern path, so explorers can intercept them early at the
  cost of leaving resources ungathered.

### Weapon roster (explorers need lots of variety)
Each weapon has a basic attack and an ability on right click with a cooldown.
More are found in chests and unlocked between runs; quadrants add themed ones.
- Sword: spin attack. Spear: long thrust and a lunge. Hammer: ground slam that stuns.
- Bow: charged shot. Boomerang Axe: throw and recall, hits twice.
- Twin Daggers: fast hits, dash-stab. Whip: pull an enemy to you.
- Shield: block and parry bash. Staff: bolt plus short blink.
- Pickaxe: mine (dash-mine). Later: chain flail, scythe, lantern that reveals chests.
Carry limited slots (the HUD has 3), so choosing loadouts matters.

## Work queue (do these in order; test each with a script in tools/tests; do not stop to report)
1. DONE (hazards: quicksand/mud/snow slow, lava burns, crystal shrines heal; natives mixes; boss intro,
   volley and quake attacks; test: tools/tests/sector_depth.gd). Original item: per-sector enemy mixes (natives use spitters/splitters/brutes), a second
   boss attack pattern each, boss intro telegraph, sector-specific hazards (desert sandstorm
   slows, tundra ice, volcano lava patches, swamp mud).
2. DONE (Dragoon Pike, Soulreaper, Earthshaker, Starfall at tier 3; Worldbreaker at tier 4 needing gems;
   Forge recipe journal saved in meta; test: tools/tests/tier34.gd). Original item: More tier-3 fusions (cover every tier-2 pairing worth having) and a tier-4 recipe; Forge UI
   shows known recipes as they are discovered.
3. DONE (swap with the active weapon when full, old one drops; hover tooltip lists the kit; test:
   tools/tests/pickups.gd). Original item: Weapon pickups: allow swapping when all three slots are full; show an item name tooltip.
4. DONE (Game.ui_scale from the window height via content_scale_factor, camera zoom divided by it so the
   world framing is unchanged; fixed top-of-screen overlaps; test: tools/tests/ui_scale.gd). Original item: UI scaling for big windows (cards, labels, radar) without changing the world view.
5. DONE as a first pass (simulation: tools/tests/balance.gd; idle keep-sitter loses at wave 4, a competent
   keep-only bot reaches wave 7 before the crystal is stolen; wave growth 0.5/wave, keep damage per enemy
   0.8-4/s). Needs real playtest feedback to tune further. Original item: Balance pass: keep HP / enemy dps / turret damage / chest and gold rates, using the AFK and
   active-player simulations; first run should end around wave 3 to 4.
6. DONE as a proof of concept: `core/net.gd` (ENet host/join, client input at 20 Hz, snapshots at 10 Hz),
   remote-controlled avatars on the host (move, aim, attack, ability, dash, ultimate), `net/client_view.gd`
   (draws the snapshot, forwards input), host/join buttons in the pause menu, `-- host` / `-- join=ADDRESS`
   command-line flags. Tested with two processes: tools/tests/net_host.gd + net_client.gd (client avatar moved
   from x=30.6 to 59.5 by network input; its remote attacks took a dummy from 30 to 12.5 hp).
   Original item: Multiplayer groundwork: host/join lobby (ENet), spawn a second player, replicate enemies,
   projectiles and Game state from the host; test with two local processes.
6b. DONE (client enters a tower via Enter near it, sees hand/mana/resources, casts by click, repairs, buys
    upgrades; keep UI is per player now via Game.local_in_base(); test: net_host_keep.gd + net_client_keep.gd).
    Original item: Client in the keep: client can enter a tower; snapshots carry hand/mana/resources; client casts cards by
    sending (card, position) to the host, which runs Game.cast with the client as caster.
6c. DONE for the core (clients: own weapon slots + switching, one Enter key for tower/chest/pickup, chest card
    draft shown and pickable, Forge fusion, enemies/bosses/spitters target the nearest player; test:
    net_host_loot.gd + net_client_loot.gd). Still shared: carried resources and the keep pool; per-player carried
    items and per-player HP bar on the client are not done. Original item: Per-player state: inventory/weapon slots, health bar and carried resources per player instead of the
    host's HUD; pickups, chests, the Forge and boss loot usable by clients; enemies target all players.
6d. DONE (client view smooths enemy/player motion between snapshots; names via `-- name=X` or Net.my_name and a
    roster in snapshots; host frees a dropped client's avatar and the keep; client notices a vanished host and
    returns to a solo game; waves scale x(1+0.6 per extra player) for every group, bosses +60% hp per extra
    player; tests: net_host_polish.gd + net_client_polish.gd, player_scaling.gd). Still no ready-up lobby
    screen. Original item: Smoothing and lobby: interpolate snapshots on the client, a proper lobby screen (names, ready),
    handle disconnects/rejoin, scale difficulty with player count.
7a. DONE (stress test tools/tests/perf.gd: 120 enemies + 60 coins + spells + turrets went from 78 to 120 fps;
    far enemies skip collision, path updates slowed and staggered, locked sectors sleep until unlocked; physics
    per frame with 120 enemies 29 ms -> 8 ms). Original item: Performance pass: stress test (100+ enemies, six turrets, hazards, projectiles) and fix the worst per-frame
    costs (group scans in _process, redraws); keep frame time reasonable.
7b. DONE (ui/base/hints.gd: ten one-time tips, remembered in meta, off switch in the pause menu; test:
    tools/tests/hints.gd). Original item: First-run hints: contextual one-time tips (pick up a weapon, gather, enter the tower, cards, chests, Forge).
7c. DONE (client minimap + HP bar + carrying label; per-player carried resources deposited on entering a
    tower; host lobby with roster and Start via `-- host`; tests: net_host_7c.gd + net_client_7c.gd). Original
    item: Co-op polish: client radar/minimap, per-player HP bar on the client, per-player carried resources, a
    ready-up lobby screen.
7d. DONE (Scimitar/desert bleeds, Frost Glaive/tundra chills, Ember Flail/volcano scorches, Bog Staff/swamp
    poisons and muds, Crystal Wand/caverns shards; each lies in its sector on unlock and drops from its boss;
    five new tier-2 fusions: Sultan's Guard, Rimelance, Magma Maul, Witch Staff, Prismatic Staff; test:
    tools/tests/sector_weapons.gd). Original item: Sector-themed weapons: one new tier-1 weapon per sector that only drops there, usable in fusion.
7. (needs the user) Replace generated art with hand-made art as it becomes available.

## Multiplayer status (proof of concept)
Works: host/join over ENet, one remote avatar per client on the host, input forwarding, host-authoritative
world, snapshots of players, enemies, bosses, keep HP, mana and wave; a client view that draws them.
Clients can enter a tower, cast cards, repair and buy upgrades, pick up items, open chests (and pick from the
draft) and use the Forge; the client view is smoothed and shows a roster. Not yet: the radar for clients,
per-player carried resources;
enemies only path toward the host's player; no per-player health bar; no snapshot interpolation; no lobby UI.
Try it: host runs the game with `-- host` (or pause menu > Host co-op game); the other machine runs
`Godot --path . -- join=HOST_ADDRESS` (or pause menu > Join). Port 24680.

## Controls (outside the keep)
Every weapon has the same four slots, each with its own cooldown:
- **Left click**: the basic attack (shortest cooldown). Many have a skill twist:
  spear/whip tip hits hit harder, bow draw is hold-and-release, daggers backstab
  exposed enemies.
- **Right click**: the weapon's ability.
- **Shift**: the weapon's dash attack.
- **Space**: the weapon's ultimate (about 60 seconds cooldown).
- **Aim rule for abilities, dash and ultimate:** hold the key to aim, release to cast.
  A quick tap casts right away at the cursor; holding more than a second shows the
  aim preview (only for abilities that have an aim). Esc cancels. Charge-style abilities
  (Hammer slam, Lance charge, Bulwark brace) keep press-to-start / release-to-finish.
- E switches weapons; Enter interacts (pick up, tower, chest, Forge).

## Weapon kits (tier 1)
| Weapon | Left click | Right click | Shift dash | Space ultimate |
|---|---|---|---|---|
| Sword | slash | Whirlwind (3 pulses, move while spinning) | Slash Dash | Blade Tempest |
| Pickaxe | mine | Seismic Strike at cursor | Dash-Mine | Earthquake |
| Spear | thrust (tip x2) | Javelin throw | Lunge (refunds on hit) | Spear Rain |
| Hammer | smash | Charged Slam (hold, perfect window) | Leap Slam | Meteor |
| Bow | draw and release (hold, perfect window) | Volley | Backflip Shot | Arrow Storm |
| Twin Daggers | slash (backstab exposed) | Throwing Knives (expose) | Shadow Step (expose) | Death Mark |
| Whip | crack (tip x2.5) | Hook (pull, stun, expose) | Whip Swing | Tempest Lash |
| Shield | bash | Parry (0.35s window) | Shield Charge | Bastion |
| Staff | bolt | Arcane Burst at cursor | Blink (leaves exploding rift) | Arcane Storm |

## Fusion and the Forge
- The **Forge** sits in the keep yard. Pick two weapons of the same tier, pay gold
  from the keep's pool (10 for tier 2, 25 for tier 3), get a new weapon.
- Only listed recipes exist, and each result is a **re-learned** weapon: new left,
  right, dash and ultimate that echo the parents but play differently.
- Tier 2: Siege Lance (spear+hammer), Warp Bow (bow+staff), Chain Fangs
  (daggers+whip), Bulwark Maul (shield+hammer), Knight's Blade (sword+shield),
  Quake Pick (pickaxe+hammer), Tempest Lash (staff+whip), Rapier (spear+daggers),
  Spellblade (sword+staff).
- Tier 3 (two tier-2 weapons): Stormcaller Bow (Tempest Lash + Warp Bow),
  Juggernaut (Bulwark Maul + Knight's Blade).
- More tier 3: Dragoon Pike (Siege Lance + Rapier), Soulreaper (Chain Fangs + Spellblade),
  Earthshaker (Bulwark Maul + Quake Pick), Starfall (Spellblade + Tempest Lash).
- Tier 4: Worldbreaker (Earthshaker + Juggernaut), costs gold, iron and gems. Tier 5+: not built.

## The Card Fuser
- A second station on the other side of the keep from the Forge (x +62, the Forge is at -62). Interact to open it.
- Pick two different cards in your hand of the same tier; pay 4 gold per tier; get one hybrid card of that tier with a fixed twist.
  Recipes (Game.FUSE_RECIPES): Fireball+Frost Ring = Frostfire, Fireball+Flare = Solar Burst, Barricade+Spike Trap = Spiked Wall,
  Sentry+Spike Trap = Spiked Sentry, Sentry+Torch = Beacon Turret, Mender+Torch = Healing Lantern, Barricade+Torch = Bonfire Wall.
- Fused cards live in Game.CARDS with "fused": true and are never drawn, offered as rewards or unlocked; they exist only in the hand.
- Each hybrid has its own frame and an icon made from its two parents' icons (tools/make_card_art.gd, `only=fused`). Split-screen players 2-4 open it with d-pad up (ui/base/local_fuser_ui.gd).

## Quadrants and progression within a run
The world is split into quadrants around the Keep, each locked at the start.
- Each quadrant is a distinct **environment**: its own ground, props, lighting and
  palette (grassland start, then for example desert, tundra, swamp, volcanic).
  Entering one should feel like arriving somewhere else.
- Each adds a new **resource**, new **enemies**, and new weapons and cards that
  need that resource.
- Each quadrant ends in a **boss**. Defeating it unlocks the next quadrant.
- Beat all quadrants, then a **final boss**. That is the win condition.

## Roguelike meta-progression
- A run ends when the crystal is lost.
- First run: you will probably not clear the first quadrant. That is intended.
- Runs award **Shards** (by progress made, bosses beaten, resources delivered).
- Shards permanently unlock cards, weapons, base upgrades, starting bonuses.
  Later runs are easier because you unlock stronger things, until you can clear
  everything.
- The old "flip tokens to choose enemies" screen becomes an optional **wager**
  (take a harder wave for more Shards) rather than the only way waves happen.

## Networking
- Godot high-level multiplayer (ENet), up to 4 peers. One peer hosts and is
  authoritative for enemies, pooled resources, mana and the crystal.
- "Inside the Keep" is a state on a player; the base UI and the wide camera
  are local to that player, the effects (cards, building) are sent to the host.
- Tested locally by running a host and several client processes on one machine.

## Build order (each step is playtested before moving on)
Focus is **single player** until the gameplay feels good. Multiplayer is kept in
mind (see Networking) but not built yet.
1. Base mode: entering a tower gives the wide view and the base UI. Pooled
   mana and resources. A hand of cards that can be cast (Fireball, Frost Ring,
   Rejuvenation Field, Aegis). Explorers deposit resources by entering the base.
2. Loot chests and pings, tower upkeep jobs, more cards; tune until the base
   always has something to do.
3. Weapon abilities.
4. Quadrant 2 with its own environment, resource, enemies, cards and boss, plus locking.
5. Run structure: loss, Shards, unlock screen, then the final boss.
6. Multiplayer (lobby, host and join, up to 4 players).

## Multiplayer-ready rules for single-player code
- Game state (pooled mana, resources, unlocked cards, quadrant state) lives in
  one place (an autoload), not spread across nodes.
- Spells and building go through functions like `Game.cast(card_id, position,
  caster)` rather than being applied directly from UI code, so they can later
  become "ask the host to do this".
- Nothing should assume exactly one player node; look players up through a
  "players" group.

## Open questions
- Where exactly is "inside the Keep": the walled yard, or only the tower interior?
- Do characters outside the Keep keep their full abilities? (Leaning yes.)
- How should difficulty scale with player count (1 vs 4)?
- Can there be more than one person in the Keep? (Leaning yes, but the extra
  person should not add much, so it does not trivialise the base.)

## Progression and building redesign (agreed with the user, in order)
8. DONE (first pass): Shard shop for weapons (3 T1 weapons in the chest pool at start, Shards add daggers/whip/
   shield/staff), choose a starting weapon, fusion tiers 3/4 locked behind Shards (tier 2 known from start).
   Tests: tools/tests/weapon_shop.gd.
9. DONE (first pass): Build cards. Cost materials (no mana), dragged onto the map like spells, then placed as
   Structures (cards/structure.gd): barricade, spike trap, sentry, mender totem; per-sector materials add iron
   wall, frost totem, ember turret, thorn hedge, crystal pylon. Placing the same card on a structure merges it
   up a tier (max 3 so far). Also Guards (summon fighters) and Charm (enemies fight for you). Test: build.gd.
10. DONE (Game.COMBO_CARDS: storm_spire iron+frost, magma_wall iron+ember, venom_tower moss+ember, prism_tower gem+frost+ember, healing_grove moss+gem; each unlocks into the run when all its sectors are open; test build.gd). Original item: combo buildings that need materials from two sectors.
11. DONE for weapons and cards (weapon tier = fusion tier + Forge awakenings, max 6; ability needs tier 2, ultimate tier 3; awakenings add +20% damage / -8% cooldowns each and cost gold + sector materials; HUD shows locked slots; tests weapon_tiers.gd, rewards.gd). Buildings now merge up to tier 6 (x1.35 per merge, drop the same card on a placed structure). Original item: six tiers for EVERYTHING (cards, buildings, weapons), one per place. Weapons: tier 1 has basic attack
    + dash attack only; tier 2 unlocks the right-click ability, tier 3 unlocks the ultimate; tiers 4-6 are
    stronger/cooler versions of effects. Replace the current "all four moves at tier 1" kit and re-balance the
    fusion tree to fit.
12. DONE (Game.make_rewards/claim_reward/convert_reward/card_tier/upgrade_card, ui/base/collection_ui.gd, run_end_ui.gd; test rewards.gd; weapon tiers still to come under 11): end-of-run card rewards. At run end you draw reward cards whose quality scales with how far you got;
    they can unlock the next tier of a spell/building/weapon or brand-new ones (options only; can be things you
    already own). A permanent collection screen: spend Shards to upgrade any owned card at any time, or turn a
    card into Shards (useful if you own it already or are saving up for something new).
13. DONE for cards (Game.card_numbers + collection screen highlights current and next tier numbers; weapon stat text comes with 11): card text shows the real numbers (damage, speed %, duration, radius, cost) with the numbers
    highlighted, and the card for the next tier highlights what changes so upgrades can be compared.
14. DONE (ui/hud/ability_hud.gd, test ability_hud.gd screenshot): ability HUD in the bottom-right corner: icons for attack/ability/dash/ultimate with a fun cooldown
    animation, clear "ready again" pop.

15. PARTLY DONE (Forge shows real damage/cooldown numbers with the next awakening highlighted; test forge_numbers.gd; recipe journal compacted). Still open: weapon numbers on a "weapon card" (damage, cooldowns, tier changes highlighted) in the Forge / a weapon
    collection screen; today the Forge only shows tier text and costs. Weapon permanent mastery from reward draws.
16. TODO: balance pass for the new economy (material costs of build cards, awaken costs, Shard prices, reward quality)
    once a human has played it; build cards and spells compete for the same 5-card hand.
17. TODO (deferred by the user until the game is good): multiplayer clients render the real scene incl. structures,
    guards, the ability HUD and the new Forge awaken button (host side command exists: "awaken").

12b. DONE (replaces the pick-one draw): end-of-run rewards give one card per realm level reached (1-6, final = 6),
    all kept and applied immediately. Each reward is a tier-L card/weapon drawn only from realms up to L (Game.card_level,
    WEAPON_LEVEL); it unlocks (NEW), raises the tier (TIER UP) or, if you already have it, turns into Shards
    (2*tier+1, so lower levels pay less). Shards for the run itself are on top. Test: rewards.gd (30 trials per
    level: counts, tier cap, realm cap).

12c. DONE: NEW cards/weapons from the reward draw are offers: pay Shards to unlock (Game.unlock_cost, unlock_offer) or
    convert them to Shards (convert_offer); tier-ups of owned cards still apply automatically and duplicates convert.
18. DONE: Shard perks (Game.PERKS: Stronger Keep, Supply Cache, Lucky Coins, Deep Well; test perks.gd), sold on the
    run-end screen. Shard sinks now: card tier upgrades, unlocking offers/cards, weapons, fusion tiers, perks.

18b. DONE (replaces the four perks): permanent skill tree, core/skills.gd (19 skills in Keep / Magic / Warrior / Economy /
    Builder branches with prerequisites; bonus(key) read all over: keep HP, keep damage taken, repair, max mana, mana
    regen, spell damage and radius, card draw, weapon damage, cooldowns, ultimate cooldown, move speed, gold chance,
    start materials, chest rate, Shards per run, structure power/duration/count), ui/base/skill_tree_ui.gd opened
    from the run-end screen. Test: skills.gd. Open: more skills per branch (rows 3+), respec, balance of costs.

19. DONE: resource generators (scenery/generator/generator.gd): one per biome plus a stone one near the keep.
    Dormant until activated with carried gold (4), then they produce the biome's resource into storage;
    Enter collects everything, Enter with nothing stored upgrades (levels 1-5: faster, bigger storage; costs gold +
    the resource). Sleep with their sector. Test: generator.gd. Open: show them on the radar, client support.
20. DONE: skill tree additions: Prospector (extra stone/sticks), Deep Veins (extra iron/frost/ember/moss/gems),
    Overclock (faster generators), Soul Siphon (mana per kill), Nimble Dash, Arsenal (turret ammo). 25 skills total.
21. DONE: radar shows generators (diamond in the resource colour, ringed when something is ready to collect) and
    placed structures (small green dots). Balance bot (tools/tests/balance.gd) now also places walls, traps and sentries.
22. DONE: two decks. The hand is drawn separately from the spell deck (3 slots) and the build deck (2 slots), spells
    listed first; a deck missing a kind fills the hand with the other. Within a deck, affordable cards are drawn
    more often. Test: decks.gd.
23. DONE: enemy counters. Enemy.apply_traits: armor (flat per hit, min 25%, "pierce" ignores it), element resist/weak
    multipliers (fire, ice, poison, earth, pierce), extra damage while slowed. Brute and golem and crystal guard are
    armored, runners fear slows, frost/ember imps counter each other, bog lurkers regenerate and resist poison.
    Five biome enemies (golem, frost_imp, ember_imp, bog_lurker, crystal_guard) are natives and join waves once their
    sector is open. Spells, builds and the sector weapons carry elements (damage numbers: orange weak, grey resisted).
    Test: counters.gd prints the full matrix. Open: weapon (T1) element variety, more enemy abilities per biome,
    showing an enemy's weakness near it, bosses with weaknesses.
24. DONE: more counter depth. Spear, lance, rapier and dragoon pike deal pierce damage (ignores armor), staff and spellblade
    deal fire; every enemy shows weakness pips (filled = weak, ring = resists, grey square = armored, plus = fears slows);
    bosses have weaknesses too (Sand Colossus and Magma Titan weak to ice, Frost Wyrm and Bog Mother weak to fire,
    Crystal Warden armored and weak to earth) with pips beside the name. Test: counters.gd (matrix + bosses + screenshot).
25. DONE: the lake in the yard is gone (world.gd REMOVE_LAKE converts its water and shore tiles to grass at start; it
    was only for fun and blocked pathing/tests). Flip the flag to bring it back if a biome feature wants water.
26. DONE: biome enemy abilities (frost imp leaves freezing ground, ember imp leaves burning ground, golem stomps with a
    telegraphed ring, crystal guard has a regrowing shield that only pierce bypasses) and the "crush" element (hammer,
    quakepick, bulwark, juggernaut, earthshaker, worldbreaker break armor: it counts half). Test: enemy_abilities.gd.
27. DONE: weapon codex (ui/base/codex_ui.gd, opened from the run-end screen): all 33 weapons, tier, element, moves with
    cooldown numbers and the tier that unlocks them, how to get each, awakening costs; undiscovered fusion recipes are ???.
    Test: codex.gd. Hints added for build cards, generators and new biomes.
28. DONE: swarm counter. Enemy.swarm (scarab, splitter, splitter minis): area attacks deal +50% (Spell fireball/zones,
    structure splash and spike traps, burn hazards, ground strikes, pulses, and any weapon swing that hits 2+ enemies in
    the same frame count as area). Cluster-of-dots pip. Test: swarm.gd. So: armored -> pierce/crush/heavy, fast -> slows,
    swarm -> area, elemental -> the opposite element.

29. DONE: multiplayer rebuilt so new content works automatically (see MULTIPLAYER.md). core/replication.gd (autoload Rep):
    group "net" => spawned on clients as puppets of the same scene/script, all public vars synced with change-only
    updates, positions smoothed, despawn; effects/damage numbers/sounds/announcements mirrored as events; every
    public Game variable synced; packets chunked under the MTU; late joiners get the full world. The client view now
    shows the real towers, Well, Forge, trees, rocks, enemies, structures, generators, projectiles, hazards, pickups.
    Tests: net_coverage.gd (fails on forgotten opt-in), rep_host.gd + rep_client.gd (236 nodes matched, despawn,
    state changes, three clients at once, a brand-new content type with zero multiplayer code), the older net_*
    pairs still pass.
30. DONE: LAN play: UDP discovery (hosts announce, the pause menu lists games), the host shows its LAN address,
    ./mp_run.sh N starts a local host + clients, `-- host` / `-- join=ADDR name=X` flags. Test: lan_host.gd + lan_scan.gd.
31. DONE: client features: cooldown HUD fed from the host (incl. tier locks), build/spell hand, Forge awaken button,
    run-end notice, weapon name on avatars, radar from puppets.
32. TODO (multiplayer polish): client-side prediction for the local avatar; per-player Shards/unlocks; full Player scene as
    a puppet (animations, held weapon); host migration is out of scope; internet play (NAT/relay) after LAN is solid.
33. DONE (co-op audit): a restarted run respawns every connected player's avatar and tells clients (RUN_START); clients can use
    generators with their own carried loot (Game.carried_of / pay_carried(who)); in co-op the wave-token screen and the
    pause menu no longer freeze the game (tokens auto-pick after 12 s); late joiners receive the whole live world.
    Tests: rep2_host/rep2_client (generator + restart), rep3_host/rep3_client (late join).
34. DECIDED: co-op progression stays HOST-ONLY (user preference): the host earns Shards, rewards and unlocks; clients play with the host's setup.
    TODO before a wider test: an exported build (no Godot needed), music reacting on
    clients, client-side prediction, key rebinding / gamepad, a mid-run save, hand-made art and sound, human balance pass.
35. DONE: enemy navigation. world/nav_builder.gd keeps ONE navigation polygon for the whole map carved around everything solid
    (towers, Well, every tree and rock, barricades; group "nav_obstacle" + Game.nav_changed, rebaked off-thread after a short
    pause), replacing the tile navigation. Enemies follow paths precisely (path_desired_distance 5). enemies/unstick.gd: when
    pushing without moving, chew through the tree/rock in front or sidestep. The boss now paths too and its charge ends when it
    hits something solid. Test nav.gd: 6 of 6 enemies placed behind the six towers reach the keep in 5-8 s (0 of 6 before) and
    the boss gets around a tower (stuck 280 px away before).
36. DONE: towers. Each turret only works (and draws) once its tower's sector is open and the tower is visible, so hidden/covered
    towers no longer shoot; the two scene-hidden towers appear when their sector unlocks (Game.sector_at).
37. DONE: crystal theft (original rise-and-steal kept: the pressure plate raises the crystal, an enemy touching it when fully up
    steals it). NEW: the thief runs for the map edge (loses the run if it arrives), the base is offline while the crystal is away
    (no casting, mana, card draws, repairs, upgrades, turret fire), killing the thief drops it, a player picks it up and carries it
    back to the Well. Banner + arrow + radar markers + a hint. collectables/crystal/crystal.gd, ui/base/crystal_alert.gd.
    Test: crystal.gd.
38. DONE: rainbow sheep (collectables/sheep/rainbow_sheep.gd, world/critter_spawner.gd): appears about every 70-120 s (first at
    30 s) in an open sector, wanders, bolts when a player is near (sprints, then tires), runs off after a minute; any weapon, spell
    or the starting sword can hit it (group "critter", ignored by turrets); drops 8-12 gold, 5-7 resources from the open sectors
    and sometimes a card chest. Rainbow dot on the radar. Test: rainbow_sheep.gd.
39. DONE: performance check (tools/tests/perf.gd, windowed): 145 enemies marching + keep UI + 60 coins + spells + turret fire:
    117-120 fps, physics 4-7 ms. Navigation bake 19 ms (153 obstacles; rebakes run off the main thread). Loading the world is one
    ~1.3 s frame at start (no other spike over 25 ms). Co-op: reading the state of ~410 replicated nodes cost 4.5 ms per tick, so
    Rep now spreads the work over 5 slices (each node still sent at 10 Hz, ~1 ms per slice); all replication tests still pass.
40. DONE (economy rebalance, from play feedback "too many Shards, no scaling, never show a tier you cannot reach"):
    Shards per run = 1.5/wave + 0.1/kill + gold/20 + 6/boss + 4 per realm beyond the first (x Soul Harvest); win +30.
    First run ~6, level 2 run ~30, level 4 run ~54, level 6 run ~106. Prices: card unlock 16 x realm^1.5 (16, 45, 83, 128, 179, 235: double the upgrade into the same tier number); weapons use the same rule by their realm. Only the Sword and Pickaxe are free (no starter weapon); both are always in the weapon chest pool and have the full 6-tier ladder (tier 2 ability, tier 3 ultimate, +12% area per tier, copies combine, rare drops/twists). The Pickaxe mines areas (Seismic Strike, Earthquake hit breakables more at higher tiers). Chests roll the Rare Draws odds table at (Rare Draws level + realms opened, max row 5): weapon chests drop a tiered copy, card drafts offer tiered cards ("id:tier:twist", never above the unlocked tier). The rainbow sheep always drops a weapon, a card chest 60% of the time, and uses one row higher (row 6, sheep only). Tests: tool_tiers.gd, chest_quality.gd, card upgrade
    8 x n^1.5 (8, 23, 42, 64, 89 = 226 for tier 1 to 6), weapons 24/24/32/32, fusion tiers 60 and 140, skills x2.5 and (level)^1.8 (a 5-level skill with base cost 6: 15, 52, 108, 182, 272), convert value
    3 x tier + 2 x realm. Reward draws never skip a tier: unowned = tier 1 offer, owned = exactly tier+1 and never above the
    level reached; at most one reward per card per draw. A card can also be bought directly from the collection once you
    have reached its realm in any run (meta.best_level). Tests: rewards.gd (240 random collections, 0 violations).
41. DONE: every weapon must be unlocked once (Shards) before it can appear: the 4 chest weapons (24-32) and now the 5 sector
    weapons (scimitar 40, frostglaive 48, emberflail 56, bogstaff 64, crystalwand 72; they also come up in reward draws by
    realm). Locked sector weapons do not spawn in their sector or drop from the boss; the chest pool never holds sector
    weapons. A fused weapon's recipe is shown (codex, Forge journal) once both ingredients are unlocked, marked "needs Tier N
    fusions" until that tier is bought; unknown ones show "???". The codex has an Unlock button for locked weapons.
    Awakening works on any weapon you hold. Test: weapon_unlock.gd.
42. DONE: offers you do not unlock or convert are kept between runs (meta.pending, up to 12; extras convert to Shards) and are
    listed on the next end screen as KEPT; reward draws never repeat a pending offer. Recipes are shown only when BOTH
    ingredients are unlocked (preview no longer reveals them), and the end screen lists recipes that just became known.
    Upgrades are offline while the crystal is away. Test: pending.gd.
43. DONE (user decision: "the unlocked tier is the ceiling"): cards start every run at tier 1 and can be raised during the run (chest
    duplicates, merging placed buildings) only up to the tier unlocked in the collection; drafts only offer cards that can still
    grow; a merge blocked by the ceiling says so. Weapon awakening is capped by the fusion tiers you own: cap = 2 + highest unlocked
    fusion tier (4 at first, 5 with Tier 3 fusions, 6 with Tier 4). Test: tier_ceiling.gd.
44. DONE (design with the user): ONE tier language for cards, buildings and weapons.
    * Doubling rule: two things of the same tier make the next tier (tier 2 needs 2, tier 3 needs 4...). Cards: two identical
      cards of the same tier in your hand merge (drag one onto the other); each hand card carries its tier ("id:tier:twist").
      Buildings hold POINTS (tier n card = 2^(n-1)); placing a card next to a same-kind structure feeds it, so a tier 1 card
      can be fed into a tier 3 and a bar shows how much more it needs. Weapons: two identical copies (same weapon, same tier)
      combine at the Forge for gold + realm materials ("id:bonus:twist"); different weapons still fuse by recipe.
    * Unlocked tier is the ceiling: merging/feeding/combining stops at the tier you unlocked (cards) or the fusion tiers you
      bought (weapons: cap = 2 + highest fusion tier); structures say "LOCKED: unlock tier N".
    * Rare Draws (Magic skill, 5 levels): chance that a drawn card or dropped weapon comes in at tier 2/3/4 (10/0/0% at level 1
      up to 30/8/2% at level 5), always capped by the ceiling.
    * Balance: Game.scaled uses power 1.1 x 2^(tier-1) split by role, so one tier N is worth more than the cards merged
      into it (tier 3 sentry 4.4x dps, barricade 4.4x hp, fireball 2.6x damage in 2.1x area).
    * Twists change HOW things work and are part of the upgrade, never random: `Game.twist_for(id, tier)` and
      `Game.weapon_twist(id, tier)` give the first twist at tier 2, the next at tier 4, the last at tier 6 (a card with
      fewer twists keeps its last). Spells: twin, aftermath, shrapnel, echo, wide. Buildings: thorned, regrow (barricade),
      rearm, venom (spike trap), twin shot, frost shot, blast shot (sentry), wide field, swift healing (mender), deep freeze
      (totem). Weapons: bleeding, chilling, chain, vampiric, thunder (the ladder starts at a different one per weapon).
      Tests: card_tiers.gd, twists.gd, weapon_copies.gd, tier_ceiling.gd.

45. **Day, night and waves** (world/world.gd, core/game.gd): a 300 s cycle (day until 150 s, dusk to 200, night to 260, dawn to 300),
    clock only runs unpaused. One DAY wave (spawns at 40 s of the cycle; the first at 50 s) and one NIGHT wave (175 s), so waves are
    125 to 165 s apart (they used to be 15 to 60 s). Waves are 2x bigger (WAVE_SIZE) and night waves another 1.5x with +1 level; Shards are
    6 per run + 3 per wave. Token screen says "Day wave N" / "Night wave N" and finishes forced steps (Draw Two, Upgrade) after 15 idle s.
    Night (Game.night_level, synced): enemies outside every light are SHROUDED (x0.6 damage, Game.SHROUD) and towers/sentries only see
    them within 50 px (Game.defence_sees). Light comes from players (46 px), torches (card + Torch weapon), flares, fire spells (fireball
    blast, lava pool), glowing buildings (ember turret, crystal pylon, tower tops) and glowing weapons (WEAPON light table in weapon.gd).
    Fire damage and glowing-weapon hits light the enemy for 2 to 2.5 s. New: Torch (free starter building card, light radius by tier,
    twists wide field / blaze), Flare (spell, realm 1), Torch (weapon, 16 Shards, Flare / Flame Dash / Sunburst). Cards with "night": true
    are drawn 3x as often at night. Dash goes the way you move (falls back to the cursor standing still). Co-op clients see the night.
    Tests: night.gd, wave_director.gd, wave_draw.gd, night_shots.gd (window).

46. **Rewards, rarity and legendaries** (core/game.gd, ui/base/run_end_ui.gd): reward cards need a run that got past the first wave
    (waves >= 2); then 1/3/5/6/7/8 cards for the realms opened (REWARD_COUNT) and 10 + a legendary for winning (win_run ->
    make_rewards(true)). Rarity (Game.RARITIES): realm 1 Common ... realm 6 Ancient, Legendary for the 6 legendaries; a card's rarity
    never depends on its tier; a fused weapon is one rarity above its rarest part (weapon_rarity). Fused weapons also hit 35% harder
    per fusion tier and are 5% faster (Game.weapon_power); legendary weapons x1.5. Legendaries (cannot be bought or drawn; winning earns one as an
    OFFER you still unlock with Shards: LEGENDARY_PRICE 400, kept until unlocked or converted for 150, never counts toward the vault
    limit; 80 Shards instead once all six are owned or waiting): cards Meteor Shower, Stasis Field, Sunspire, Phoenix Shrine; weapons
    Dawnbringer, Voidreaver. Reward screen: cards arrive face down (deal-in, wobble, hover), click or Flip all; rumble + rarity-coloured
    edge tell, overshoot flip, burst/sparks/shake/flash/banner scaled by rarity, per-rarity Sfx (core/sfx.gd _arp, play_ui), "Best pull".
    Replication: rarely-changing Game state (sectors, hand, deck, resources...) now goes in a small reliable message (rep_game) and
    only mana/keep hp/stats/night_level stay unreliable (a lost one-off packet used to leave a client stale). Tests: legendary.gd,
    rewards_flip.gd (window).

47. **Falling in battle** (player/player.gd, ui/hud/respawn_ui.gd): no longer ends the run. `Player.fall()` takes you out of the fight for
    30 s (RESPAWN_TIME): hidden, collisions off, parked at the keep so the camera watches it, enemies/bosses/spitters/sheep ignore you
    (`downed`), damage and input ignored; then `respawn()` at the keep with full health and 2.5 s of shield. Co-op avatars fall and
    respawn the same way (snapshot `down` seconds, client countdown). The run still ends when the keep falls or the crystal is
    stolen. Test: respawn.gd.

48. **Spare copies** (core/game.gd spare_*, ui/base/run_end_ui.gd): a reward for a card you already own that cannot be raised
    for free is no longer turned into Shards: it is a "spare" copy kept in the vault (MAX_PENDING, a full vault sells it). Merge it
    into your card when its tier equals the card's tier and that tier is below the deepest level you have reached (1+1=2, 2+2=3:
    spare_merge), combine two spares of the same card and tier into one a tier higher (spare_combine), or sell it for
    convert_value(tier, realm) Shards (spare_sell). Test: spare_copies.gd.
