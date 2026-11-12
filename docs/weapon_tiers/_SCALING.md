# Weapon tiers 2 to 6: scaling reference (read this first; every weapon file refers to it)

Goal: every weapon looks better, attacks cooler and gains real new abilities at each tier 2 to 6, on top of the simple
twist (`Game.weapon_twist`) and the numeric scaling that already exist. The higher the RARITY, the more exciting the weapon.
The reference for "one look + one new move per tier, all kept" is `cards/guard.gd`; the card-side standard is
`docs/card_tiers/_CONVENTIONS.md` (same drawing rules, same WeaponFx vocabulary, same test style).

Decisions made without asking (the owner can overrule any of them):
1. Art is composed at run time from the existing icons plus a code-drawn aura (section 5.1); no new PNGs are needed.
2. All per-weapon code lives in one new file per weapon, `items/weapons/tiers/<id>.gd`, reached through hooks written once.
3. A tier adds a fixed NUMBER of upgrades by rarity (table 2.2), so a Mythic at tier 2 already shows more than a Common at tier 4.
4. Fused weapons start at their fusion tier F; their file lists rows F..6, and row F is an ENTRY BUNDLE that carries the upgrades of rows 2..F.
5. Numeric scaling is untouched. New damage is written in multiples of H (= `Game.basic_hit(id)`, 2.0 for Sword/Pickaxe) before `WeaponUtil.power`.
6. The camera zoom is 5 on a 1280x720 window: the visible world is only about 256 x 144 px. Every size below is in world px.
   A radius of 128 spans the whole screen width. A 1 px line is 5 screen px wide; a 6 px mote is a big dot. Design for that.

---------------------------------------------------------------------------------------------------------------------

## 1. Inventory (built from the code, 39 weapons)

Rarity = `Game.weapon_rarity` (base weapons by `WEAPON_LEVEL`, a fusion is one step above its rarest part, capped at Legendary; Sword and Pickaxe are Common).
Note: Prismatic Staff comes out Legendary (Crystal Wand is Ancient, +1). It is designed in the Legendary band but is NOT one of the three named
legendaries (`LEGENDARY_WEAPONS`), which also get x1.5 damage in `weapon_power`.
F = fusion tier = first reachable tier. hit/cd = `Game.WEAPON_BASIC` at tier 1 (Sword and Pickaxe: a fixed 2.0 per swing, `Enemy.SWORD_HIT`, animation length 0.4 s).

### 1.1 Identity

| id | name | rarity | F | parents | element | type | hit | cd |
|---|---|---|---|---|---|---|---|---|
| sword | Sword | Common | 1 | start tool | - | tool (sprite sheet, hitbox) | 2.0 | 0.4 |
| pickaxe | Pickaxe | Common | 1 | start tool | - | tool (sprite sheet, hitbox) | 2.0 | 0.4 |
| torch | Hand Torch | Common | 1 | - | fire | light melee arc | 2.7 | 0.45 |
| spear | Spear | Common | 1 | - | pierce | thrust line | 2.7 | 0.45 |
| hammer | Hammer | Common | 1 | - | crush | slow smash, hold-charge | 5.1 | 0.85 |
| bow | Bow | Uncommon | 1 | - | - | projectile, hold-draw | 2.6 | 0.30 |
| daggers | Twin Daggers | Uncommon | 1 | - | - | fast melee, expose/backstab | 1.6 | 0.22 |
| scimitar | Scimitar | Uncommon | 1 | - | earth | melee arc, bleed | 2.2 | 0.30 |
| lance | Siege Lance | Uncommon | 2 | hammer+spear | pierce | thrust, hold-charge ram | 3.64 | 0.50 |
| quakepick | Quake Pick | Uncommon | 2 | hammer+pickaxe | crush | heavy arc, ground | 4.36 | 0.60 |
| whip | Whip | Rare | 1 | - | - | long arc, tip crack | 4.2 | 0.50 |
| shield | Shield | Rare | 1 | - | - | bash, parry stance | 5.0 | 0.70 |
| frostglaive | Frost Glaive | Rare | 1 | - | ice | cleave, chill | 3.75 | 0.45 |
| rapier | Rapier | Rare | 2 | daggers+spear | pierce | thrust combo, footwork | 2.33 | 0.28 |
| staff | Staff | Epic | 1 | - | fire | projectile bolt, blink | 4.8 | 0.50 |
| emberflail | Ember Flail | Epic | 1 | - | fire | heavy arc, ground fire | 5.8 | 0.60 |
| chainfangs | Chain Fangs | Epic | 2 | daggers+whip | - | 2-hit combo, grapple | 2.88 | 0.30 |
| bulwark | Bulwark Maul | Epic | 2 | hammer+shield | crush | slow maul, hold stance | 7.69 | 0.80 |
| knightblade | Knight's Blade | Epic | 2 | shield+sword | - | 3-hit combo, counter | 3.08 | 0.32 |
| rimelance | Rimelance | Epic | 2 | frostglaive+spear | ice | thrust, chill | 4.81 | 0.50 |
| sultanguard | Sultan's Guard | Epic | 2 | scimitar+shield | earth | melee arc, bleed parry | 2.88 | 0.30 |
| dragoonpike | Dragoon Pike | Epic | 3 | lance+rapier | pierce | thrust, charge chain | 4.81 | 0.50 |
| bogstaff | Bog Staff | Mythic | 1 | - | poison | projectile glob, DoT | 5.9 | 0.55 |
| magmamaul | Magma Maul | Mythic | 2 | emberflail+hammer | fire | slow maul, ground fire | 9.11 | 0.85 |
| spellblade | Spellblade | Mythic | 2 | staff+sword | fire | slash + wave, orbit blades | 4.29 | 0.40 |
| tempest | Tempest Lash | Mythic | 2 | staff+whip | - | chain lightning, charges | 4.82 | 0.45 |
| warpbow | Warp Bow | Mythic | 2 | bow+staff | - | projectile, hold-draw, anchor | 3.21 | 0.30 |
| juggernaut | Juggernaut | Mythic | 3 | bulwark+knightblade | crush | slow maul, hold stance | 8.57 | 0.80 |
| earthshaker | Earthshaker | Mythic | 3 | quakepick+bulwark | crush | heavy arc, ground | 6.43 | 0.60 |
| crystalwand | Crystal Wand | Ancient | 1 | - | pierce | 3-shard fan | 6.0 | 0.50 |
| witchstaff | Witch Staff | Ancient | 2 | bogstaff+staff | poison | piercing bolt, curses | 6.00 | 0.50 |
| soulreaper | Soulreaper | Ancient | 3 | chainfangs+spellblade | - | combo + wave, grapple | 3.60 | 0.30 |
| starfall | Starfall | Ancient | 3 | spellblade+tempest | fire (inherited) | slash + wave, charged blades | 4.80 | 0.40 |
| stormbow | Stormcaller Bow | Ancient | 3 | tempest+warpbow | - | projectile, hold-draw, warp | 3.60 | 0.30 |
| worldbreaker | Worldbreaker | Ancient | 4 | earthshaker+juggernaut | crush | slow maul, stance, eruptions | 9.60 | 0.80 |
| prismstaff | Prismatic Staff | Legendary | 2 | crystalwand+staff | pierce | 5-shard fan, beams | 7.33 | 0.50 |
| dawnbringer | Dawnbringer | Legendary (named) | 1 | - | fire | light blade arc | 3.9 | 0.40 |
| voidreaver | Voidreaver | Legendary (named) | 1 | - | pierce | wide scythe, lifesteal | 5.4 | 0.55 |
| mindbender | Mindbender | Legendary (named) | 1 | - | magic | bolt, conversion | 5.0 | 0.50 |

### 1.2 The four verbs (cooldowns in seconds; ultimate default 60 when not listed)

| id | ATTACK (left) | ABILITY (right, tier 2+) | DASH (shift) | ULTIMATE (space, tier 3+) |
|---|---|---|---|---|
| sword | Slash | Whirlwind (6) | Slash Dash (4) | Blade Tempest |
| pickaxe | Mine | Seismic Strike (6) | Dash-Mine (5) | Earthquake |
| torch | Burn | Flare (8) | Flame Dash (4) | Sunburst (55) |
| spear | Thrust (tip hits hard) | Javelin (6) | Lunge (5) | Spear Rain |
| hammer | Smash | Charged Slam, hold (7) | Leap Slam (5) | Meteor |
| bow | Draw and release, hold | Volley (6) | Backflip Shot (4) | Arrow Storm |
| daggers | Slash (backstab exposed) | Throwing Knives (5) | Shadow Step (4) | Death Mark |
| scimitar | Slash (bleeds) | Crescent Wave (5) | Mirage Step (4) | Sand Cyclone |
| lance | Impale (tip hits very hard) | Charge, hold (7) | Pole Vault (4) | Dragoon Dive |
| quakepick | Heavy pick (breaks rocks) | Fissure (7) | Burrow (5) | Cataclysm |
| whip | Crack (tip hits hard) | Hook (6) | Whip Swing (4) | Tempest Lash |
| shield | Bash | Parry (8) | Shield Charge (5) | Bastion |
| frostglaive | Cleave (chills) | Glacial Line (6) | Skate (4) | Deep Freeze |
| rapier | Thrust (3rd is double) | Fleche, chain x3 (6) | Evade (3.5) | Thousand Stabs |
| staff | Bolt | Arcane Burst (5) | Blink + rift (4) | Arcane Storm |
| emberflail | Swing (scorches ground) | Eruption (6) | Lava Surge (5) | Magma Ring |
| chainfangs | Chain slash (2nd reels in) | Grapple (6) | Chain Sweep (4) | Hunt |
| bulwark | Maul swing | Brace, hold (8) | Shoulder Charge (5) | Quake Fortress |
| knightblade | 3-hit combo | Riposte (3) | Slash Dash (4) | Judgment |
| rimelance | Frost thrust | Glaive Throw (6) | Skate (4) | Deep Freeze |
| sultanguard | Slash (bleeds) | Riposte Wave parry (7) | Mirage Guard (4) | Sand Cyclone |
| dragoonpike | Impale | Charge hold + 3 lunges (6) | Sky Vault (4) | Dragon Dive |
| bogstaff | Poison glob | Mire (6) | Bog Hop (4) | Swamp Swell |
| magmamaul | Heavy swing | Magma Slam (7) | Leap Burn (5) | Magma Ring |
| spellblade | Wave slash | Blade Storm (9) | Arcane Dash (4) | Blade Dance |
| tempest | Chain lightning (charges) | Thunderclap (6) | Static Dash (4) | Storm |
| warpbow | Arcane draw, hold | Warp Arrow (6) | Phase Step (3) | Rift Volley |
| juggernaut | Maul swing | Fortress, hold (7) | Shoulder Charge (5) | Unbreakable |
| earthshaker | Heavy pick | Triple Fissure (8) | Burrow braced (5) | Cataclysm |
| crystalwand | Shard fan (3) | Crystal Ring (6) | Refract (4) | Geode Storm |
| witchstaff | Poison bolt (pierces) | Hex (7) | Bog Hop far (4) | Swamp Swell |
| soulreaper | Chain slash + wave | Grapple, exposes group (6) | Chain Sweep (4) | Reap |
| starfall | Wave slash | Blade Storm charges (9) | Arcane Dash (4) | Blade Dance + stars |
| stormbow | Storm draw, hold | Storm Warp (5) | Phase Step (3) | Thunder Volley |
| worldbreaker | Maul swing | Fortress + eruptions (6) | Shoulder Charge (5) | Cataclysm Fortress |
| prismstaff | Shard fan (5) | Prism Beam (6) | Refract (4) | Geode Storm + nova |
| dawnbringer | Radiant Slash | Daybreak (9) | Sun Dash (3.5) | Solar Judgment (50) |
| voidreaver | Reap | Rift (8) | Void Step (4) | Event Horizon (55) |
| mindbender | Mind Bolt | Turncoat (11) | Mind Step (4) | Mass Conversion |

Existing numeric rules (do not change): tier = F + bonus (1..6); `weapon_power = (1+0.2*bonus) * (1+0.35*(F-1)) * (1.5 legendary) * (1+0.1*min(5,rarity))`;
cooldowns `x0.92^bonus * 0.95^(F-1)`; ability needs tier 2, ultimate needs tier 3; the twist is ONE per copy: `bleed/chill/chain/lifesteal/thunder`
picked by `id.hash()`, changing at tiers 2, 4 and 6 (rung = tier/2); `weapon_rules.gd` must keep passing (DPS rises with rarity, a fusion beats both parents).

---------------------------------------------------------------------------------------------------------------------

## 2. Rarity ladder: what each rarity feels like

One sentence per rarity first, then the numbers. "Budget" means what the tier ladder ADDS on top of today's verb at tier 6. Today's counts
(for instance Dawnbringer's 24 strikes) are grandfathered; the hard performance caps of 5.4 still apply to the whole.

### 2.1 Feel

| Rarity | Feels like | Existing examples that set the bar |
|---|---|---|
| Common | Simple, solid, readable. One idea per verb, one colour, one shape. Satisfying thunks, no clutter. A new tier is "the same weapon, sharper". | Spear: stay at the tip. Hammer: hold, release in the gold window. Torch: light and burn. Spear Rain (12 javelins in a 55 circle) and Meteor (one 1 s telegraph, one 60 px crash) are the biggest a Common ult should get. |
| Uncommon | Common plus one interplay between two of its verbs (expose then backstab, draw then perfect shot). Still one effect at a time. | Daggers: Shadow Step exposes, the next hit is a 3x backstab that refunds the dash. Arrow Storm (13 arrows, then one slam) is the top of the band. |
| Rare | Conditional mechanics: windows, combos, setups with a payoff. Two things happen at once, never three. | Parry (0.35 s window, refund), Rapier third-thrust rhythm and 3-chain Fleche, Whip hook that pulls the pack, Deep Freeze ring then freeze. |
| Epic | Terrain and stance: the weapon changes the ground or your state. Chains of 3 to 6 targets, patches, rings of strikes. Ultimates have a setup and a payoff plus a lingering field. | Eruption plus a ring of 6 sparks plus a burning pool; Magma Ring (12 + 6 strikes); Hunt chains through 5 enemies; Brace stores hits and slams for them. |
| Mythic | A SYSTEM: stacks, orbits, anchors, persistent fields that the player plays with for several seconds. The ultimate transforms the weapon or the field for a window. | Tempest charges that Thunderclap detonates; Blade Storm orbit blades (6 for 5 s in Blade Dance); Warp Arrow anchor; Fortress counter-pulses; Triple Fissure. |
| Ancient | Multi-stage set pieces that cover most of the screen and mix two ideas (its two parents). Several things at once, still telegraphed. | Starfall (blade dance, then 18 stars rain), Stormbow (volley, then 18 bolts, then one huge bolt), Reap (ring, 8 strikes, 16-strike rain), Worldbreaker (shield, pulses, 20 eruptions, final 130 quake). |
| Legendary | Rule-bending and screen-filling. The weapon changes what the battlefield is: daylight, a black hole, an army of turncoats, a prism of beams. Multi-stage, cinematic, still fair: every damaging stage has a visible telegraph. | Dawnbringer Solar Judgment (24 beams + column), Voidreaver Event Horizon (8 pulls), Mindbender Mass Conversion (a whole crowd changes sides for 25 s). |

### 2.2 Numbers (all are tier-6 totals of what is ADDED; section 3 spreads them over the tiers)

| | Common | Uncommon | Rare | Epic | Mythic | Ancient | Legendary |
|---|---|---|---|---|---|---|---|
| Upgrades per tier 2/3/4/5/6 (an upgrade = a new, nameable, testable change: hit effect, pattern, stage, proc, transformation; art does not count) | 1/1/1/1/1 | 1/1/1/1/2 | 1/1/2/1/2 | 1/2/2/2/2 | 2/2/2/2/3 | 2/3/3/2/3 | 3/3/3/3/4 |
| Total upgrades by tier 6 | 5 | 6 | 7 | 9 | 11 | 13 | 16 |
| Added WeaponFx nodes per verb burst | 6 | 10 | 14 | 20 | 28 | 36 | 48 |
| Count param of one fx (shards/motes/orbit/star points) | 6 | 8 | 12 | 16 | 24 | 32 | 40 |
| Added projectiles per volley | 2 | 3 | 4 | 6 | 8 | 10 | 14 |
| Shake (`player.shake`) ability / ultimate / finale | 2 / 3 / 4 | 2.5 / 4 / 5 | 3 / 4.5 / 5.5 | 3.5 / 5 / 6 | 4 / 6 / 7 | 5 / 7 / 8 | 6 / 8 / 10 |
| `Sfx.play` calls per verb (names: hit, big_hit, cast, ultimate, whoosh, thump, gong, boss_roar, chest, unlock, coin) | 1 | 2 | 2 | 3 | 3 | 4 | 5 |
| Ultimate stages (a stage = a separate telegraph/hit) | 1 (+finale) | 2 | 2 | 3 | 3 + transformation | 4 | 5 |
| Ultimate show length (press to last visual) | 1.5 s | 2 s | 2.5 s | 3.5 s | 4.5 s | 6 s | 8 s |
| Visual layers per verb (telegraph, hit, afterglow, secondary, persistent, finale) | 2 | 2 | 3 | 3 | 4 | 5 | 6 |
| Area growth allowed over today's radius, tier 6 | +25% | +30% | +35% | +40% | +50% | +60% | +75% |
| Persistent field / buff window (patch, aura, transformation) | 4 s | 5 s | 6 s | 8 s | 10 s | 12 s | 15 s |
| Added `LightSource` radius (only fire/light weapons) | +40 | +50 | +60 | +80 | +100 | +120 | +160 |
| Hand aura motes at tier 6 (5.1) | 4 | 5 | 6 | 8 | 10 | 12 | 16 |

What an ULTIMATE may do, by rarity (tier 6, all earlier tiers are subsets):
- Common: one telegraphed area hit, then the finale pop. No buff. Example target: Spear Rain with a closing "all spears at once" volley.
- Uncommon: two stages (stream + slam). A short self buff (<= 4 s) is allowed.
- Rare: setup then payoff (ring, then the effect it set up); may leave a 5 s field.
- Epic: three stages: telegraph, main, aftermath; may leave a field (<= 8 s) or chain through up to 6 targets.
- Mythic: transform the weapon or the field for up to 10 s (new attack pattern while it lasts: "Blade Dance" style) plus a 3-stage show.
- Ancient: four stages, uses BOTH parents' ideas, screen-wide, a persistent minion/orbit/field; one deliberate "boom" frame at the end.
- Legendary: five stages including a cinematic beat (0.3 s slow-mo via `Game.hit_stop`-like flash is allowed ONCE), screen-filling, changes the battlefield for up to 15 s, and a final strike. Still telegraphed: the player must be able to read where harm lands.

Counter-examples (what NOT to do): a Common with three simultaneous colours and a screen-wide field; a Legendary that is just a bigger ring; any tier whose
only upgrade is "+10% damage" (numbers are already handled by `weapon_power`).

---------------------------------------------------------------------------------------------------------------------

## 3. Tier ladder 1 to 6

Each tier has a NAME (flavour, optional for the codex), one HEADLINE slot, and gets its share of the rarity budget. Art improves at EVERY tier regardless of rarity.
Tier 1 is unchanged. Higher tiers keep everything lower tiers had.

### 3.1 The escalation recipe (applies to every weapon)

| Tier | Name | Art (always) | Headline slot (the upgrade that must exist) | Typical garnish added by higher rarities |
|---|---|---|---|---|
| 2 | Kindled | Polished icon (+8% bright, light edge), a twinkle at the tip every 1.6 s (aura 5.1) | ABILITY gets a RIDER: a new hit effect or secondary area on the right click (a status, a second hit, a bigger shape). | a hit-spark `burst` on every attack hit; attack swing leaves a faint after-arc |
| 3 | Honed | Rarity-coloured 1 px glow ring on the icon, tip glow pulses; weapon trail while swinging | ATTACK FLOURISH: every Nth attack (3rd or 4th) is a signature move (bigger arc, extra projectile, shockwave). ULTIMATE unlocks (code already does): its first look gets a bigger telegraph (`sigil`). | dash leaves a short streak; ability gets a second visual layer |
| 4 | Awakened | 2 px glow, white cross sparkle at the tip, an accent gem pixel; 2 motes orbit the head | DASH UPGRADE (trail with damage/status, afterimage, or an arrival burst) AND a second effect on the ability (chain, echo, second wave). Twist rung 2 arrives. | attack gains pierce/chain/split; ultimate telegraph grows |
| 5 | Exalted | Strong glow, shine stripe on the blade/head, 4+ motes, swing ghost trail of 3 frames | ULTIMATE STAGE 2: a follow-up phase (second wave, aftermath field, chain, summon) and an ATTACK CHAIN/PIERCE (projectiles split/chain, arcs reach further). | a persistent aura effect around the player while the weapon is in hand |
| 6 | Ascended | White-gold halo ring + full mote orbit + tip star, light pulse (fire/light weapons), icon at max | FINALE: the signature end of the ultimate (one big payoff, tagged FINALE in the file, skipped for `copy`-type duplicates if any) AND an ATTACK FINISHER (every 6th attack). Twist rung 3 arrives. | transformation window, extra cinematic beat, second finale |

Tier 1 to tier 6 spreads the budget this way: a design may use at most `ceil(total * frac)` of the rarity's added fx/particles/shake at tier t,
with `frac = {2: 0.20, 3: 0.35, 4: 0.55, 5: 0.78, 6: 1.00}`. Example: Mythic (28 added fx per burst) may add 6 at tier 2, 10 at tier 3, 16 at tier 4, 22 at tier 5, 28 at tier 6.
This is why a Mythic at tier 2 already looks like a Common at tier 6 (6 added fx), and a Common at tier 6 looks like an Uncommon at tier 3.

How the per-tier upgrade count of table 2.2 fills the slots: the HEADLINE is always upgrade number 1 of the tier. Rarities with 2 or more upgrades in that tier add
SECOND-SLOT upgrades from this garnish list, in this order of preference: (a) tier 2: a hit-spark/status on the attack, (b) tier 3: a second visual layer + extra effect on the ability,
(c) tier 4: attack pierce/chain/split or a dash status, (d) tier 5: a persistent field or a passive proc, (e) tier 6: ATTACK FINISHER (every 6th attack) and for 3+ upgrades a
transformation window. Common (one upgrade at tier 6) puts the FINALE first; Uncommon and up add the finisher. Mythic and above may also put a second FINALE or a cinematic beat on the ultimate.

### 3.2 How a tier composes with the twist and the numbers

- Twist (`bleed/chill/chain/lifesteal/thunder`) is applied by `WeaponUtil.hit` to EVERY hit, so every extra hit an upgrade makes is also twisted. Design rule:
  headline hits go through `WeaponUtil.hit` normally; echoes, ticks and chain jumps use `quiet = true` (5.3). Never design a rider that needs a specific twist.
- `chain` twist plus a chain upgrade, or `thunder` plus a pulse ult, look good together; they are different effects (chain: 40% arc to a neighbour within 55 px; thunder: every 4th hit a 32 px blast). Keep each upgrade's own look distinct from the five twist looks (arc burst, blue ring, red drips).
- Twist ladder: tiers 2-3 have twist 1, tiers 4-5 twist 2, tier 6 twist 3 (`WEAPON_TWISTS[(id.hash() + rung - 1) % 5]`). The weapon files print the ladder as computed with the djb2 string hash;
  it is an ESTIMATE for flavour (the file only uses it to avoid designing against the weapon's own twist). `tools/tests/twists.gd` prints the real ladder; if it differs, the file's flavour still holds because no upgrade depends on a twist.
- Numeric growth per tier is already big (+20% damage and -8% cooldown per tier). Upgrades are about shape, reach, count and control. Damage caps are in 5.4.
- A fusion's ENTRY row (tier F) uses the budget of rows 2..F added together and must already out-spectacle both parents' tier F rows.

---------------------------------------------------------------------------------------------------------------------

## 4. Visual toolkit

### 4.1 `WeaponFx` kinds that exist today (items/weapons/fx.gd)

`ring` (disc 0.14 + 2 px circle), `arc` (3 px arc around `dir`, `half_angle`), `burst` (8 radial lines), `line` (one fading line), and the card kinds
`flash` (boom disc + white core), `ripple` (`rings` expanding rings), `shards` (`count` triangles flying out, `spin`), `pillar` (`height`, `width`),
`motes` (`count` dots drifting up `rise`), `star` (`count` points, `spin`), `bolt` (jagged lightning along `dir`, `length`), `fall` (a rock/comet arriving: `radius`, `height`, `rise`, `core`).
Vars: `radius, dir, length, width, half_angle, life, count, spin, height, rise, rings, core`. Everything is drawn from `age` and index; no `randf()` in `_draw`.

### 4.2 New kinds implementers may add (once, in fx.gd; all plain `draw_*`, deterministic, <= 60 draw calls)

New vars: `shape := "dot"` (String), `thick := 6.0`, `inward := false`, `col2 := Color(1,1,1)` (second colour). All params stay plain numbers/colours/vectors/strings (`Rep.ser_ok`).

| kind | params | look |
|---|---|---|
| `slash` | `radius`, `dir`, `half_angle`, `thick` | A filled crescent (outer arc radius `radius`, inner arc `radius - thick`, tapered to points), alpha `0.55*fade`, white edge line on the outer arc, rotates 0.2 rad over life. Replaces the thin `arc` as the "good swing" at tier 3+. |
| `streak` | `dir`, `length`, `width` | A tapered wedge (point at the head, `width` at the tail) in `color` alpha 0.5*fade, a white spine, 5 spark dots along it (index-based). The dash look. |
| `cone` | `radius`, `dir`, `half_angle` | A filled sector alpha 0.22*fade with two bright edge lines and a bright arc at the rim; for fans, shotgun spreads, breaths. |
| `beam` | `dir`, `length`, `width` | Three layers: glow width*3 alpha 0.18, colour width alpha 0.7, white core width*0.35; a `flash`-like disc at the end. Straight light (prism, daybreak, arrow lance). Width eases `width*(1-t)` over life. |
| `orbit` | `radius`, `count`, `spin` (rad/s), `shape` ("dot","blade","star","shard"), `life` | `count` small shapes circling the point at `radius`, angle `spin*age + i*TAU/count`, alpha fades in 0.15 s and out 0.15 s. For blade storms, spirit rings, charged halos. Follows nothing: spawn again to move (0.1 s cadence is fine). |
| `vortex` | `radius`, `count` (arms), `spin`, `inward` | `count` spiral arms (polylines of 10 points) contracting (`inward`) or expanding with `t`, rotating by `spin*t`, alpha 0.7*fade. Pulls, cyclones, black holes. |
| `crack` | `radius`, `count` | `count` jagged ground lines (5 segments, index-based offsets) from the centre out to `radius`, dark core line plus coloured glow, alpha `fade^0.5`, so they last. Quakes, hammer slams. |
| `sigil` | `radius`, `count`, `spin` | A summoning circle: outer ring, inner ring at 0.7 r, `count` small diamonds on the ring, rotating dashes; alpha builds up over the first 60% of life then flashes. THE ultimate telegraph (replaces the plain `ring` in ground strikes at tier 3+). |
| `cut` | `radius`, `spin` | Two thin crossing lines (an X, angle `spin`), length `2*radius`, white core, alpha `fade`, scale pops 0.7 to 1.0 in the first 20% of life. Finishers, backstabs, kills. |
| `shock` | `radius`, `thick` | A thick expanding ring: width `thick*fade`, plus a second thin ring at 0.8 radius, plus a faint filled disc. The heavy-impact look (hammer, earthquake). |

Which of them to use by tier: tier 2: `burst`, `ring`, `motes`; tier 3: `slash`, `streak`, `sigil`; tier 4: `orbit`, `cone`, `shards`; tier 5: `ripple`, `star`, `beam`, `bolt`, `vortex`; tier 6: `flash`, `shock`, `crack`, `pillar`, `cut`, plus anything.

### 4.3 `WeaponProjectile` upgrades (items/weapons/projectile.gd; node is group `net`, so public vars replicate)

Add once; every one is optional and defaults to today's behaviour. Set through the existing `extra` dictionary of `WeaponProjectile.shoot`.

| var | meaning |
|---|---|
| `style: String = "arrow"` | how it is drawn: `arrow` (today), `orb` (glow disc r 3 and halo), `shard` (diamond), `blade` (crescent, 8 px), `crescent` (big wave 14 px wide, for wave slashes), `glob` (blob with a dripping tail), `bolt` (short jagged spark), `lance` (long needle 14 px) |
| `size: float = 1.0`, `glow: float = 0.0`, `trail: int = 0` | draw scale, halo alpha, number of trail dots (positions `pos - vel.normalized()*i*3`, deterministic) |
| `homing: float = 0.0` | rad/s turning toward the nearest enemy within 90 px (host only) |
| `chain: int = 0` | on a hit, jump to the nearest un-hit enemy within 55 px for 60% of `damage`, `chain` times; a `bolt` `WeaponFx` between them; hits are quiet |
| `burst_r: float = 0.0`, `burst_mult: float = 0.5` | on a hit, an area hit of `damage * burst_mult` to every enemy within `burst_r` (quiet, `aoe`), with a `burst` fx |
| `split: int = 0` | on the first hit, spawn `split` child projectiles of the same style at 40% damage fanned +-0.5 rad, `life 0.35`, `split = 0` |
| `wobble: float = 0.0` | sine drift sideways (amplitude px) for glob/snake shots |
| `on_hit_fx: String = ""` | a `WeaponFx` kind spawned at the hit point (`flash`, `shards`, `cut`) |
| `owner_id: int = 0` | `player.get_instance_id()` of whoever fired it (public, so it replicates); lets a weapon find its own projectiles (gates, caps, beasts). `Weapon.shoot_owned(...)` helper sets it |
| `tags: Dictionary = {}` | free host-only marks such as `{"gated": true}` (a name with a leading underscore in code: `_tags`) |
| `spin: float = 0.0` | visual spin for blades/shards (rad/s) |

Projectile cap per weapon: 40 alive; `split`/`chain` children count.

### 4.4 Other light-weight pieces that already exist

`LightSource.spawn(world, pos, radius, secs, col)`, `WeaponUtil.patch(world, pos, kind, r, col, secs, factor)` (`slow` is harmless to players, `heal` heals them, `burn`
HURTS players: 30/s, use sparingly and never for new Common/Uncommon abilities), `Weapon.ground_strike/rain/pulse_around`, `Game.light_up(e, secs)`, `WeaponUtil.expose/is_exposed`, `Enemy.charm/push/apply_slow`, `Game.hit_stop`.

---------------------------------------------------------------------------------------------------------------------

## 5. Rules for the implementers

### 5.1 Art: how a weapon looks better at each tier (cheapest robust way)

The in-hand sprite is a 32x32 icon at `icon_scale` 0.5 to 0.7 (about 19 world px). Decision: NO per-tier PNG explosion. Two code pieces:

1. `items/weapons/weapon_art.gd` (`class_name WeaponArt`, all static):
   - `PALETTE := {id: [main, hot, core]}`: three colours per weapon, given in each weapon file; defaults to the rarity colour.
   - `icon(id: String, tier: int) -> Texture2D`: loads the base icon (for Sword/Pickaxe the first 32x32 frame, as `UiKit.weapon_icon` does), composes the tier recipe on an `Image`, caches in a Dictionary keyed `id:tier`, returns `ImageTexture` (filter nearest). Recipe (cumulative, `rim = Game.rarity_color(rarity)`):
     tier 2: every non-black pixel `lightened(0.08)` plus a 1 px highlight on the upper-left edge pixels;
     tier 3: an outer 1 px glow ring around the black outline in `rim` alpha 0.55 (image is 32x32; weapons keep a margin; clip at the border), plus 2 sparkle pixels in `core` at fixed anchors;
     tier 4: a second glow ring alpha 0.25, a plus-shaped 5 px white sparkle at the tip, a 3 px gem in `hot` at the guard/head (anchor per weapon = the most saturated pixel region);
     tier 5: glow alphas x1.4, a 1 px white shine stripe along the brightest pixels, 4 sparkles;
     tier 6: glow in white-gold (`rim.lerp(gold, 0.5)`), 3 px reach, 6 sparkles, edge pixels shifted to `main`.
   - `hud_icon(id, tier)` the same, used by `UiKit.weapon_icon` and the codex/Forge/weapon cards so the HUD slot shows the tier (one helper, drift guard). Optional: `tools/make_weapon_art.gd` gets a mode `only=tiers` that bakes every `icon(id, tier)` into a contact sheet PNG for human review; the game never loads those files.
   - `Weapon._ready` sets `sprite.texture = WeaponArt.icon(weapon_id, tier)`; Sword/Pickaxe (`Tool`) do the same with their own sprite (animation frames stay: apply the tint/glow as a `Sprite2D` shader-free `modulate` pulse + the aura instead of recomposing sheets: `Tool` only gets the aura and a modulate shimmer `Color(1,1,1) -> rim` pulse, because its sheet has many frames).
2. `items/weapons/weapon_aura.gd` (`class_name WeaponAura`, `Node2D`, `add_to_group("net")`): ONE node per equipped weapon of tier >= 2, child of the world, following `player.global_position` on the host (`_physics_process`, host only). Public vars (synced, drawn by clients): `wid: String`, `tier: int`, `aim: Vector2`, `swing: float` (copy of `swing_offset`), `reach: float`, `kind: String = "hand"`, `col: Color`, `state: int = 0` (weapon-specific: e.g. charging 0..100). Private: `_owner` (the player; freed when the weapon is freed or replaced). `_age` ticks locally. It draws, in `_draw` from synced vars only:
   - tier 2: a white 4-point twinkle at the tip every 1.6 s (`since = fposmod(_age + jit(id.hash()), 1.6)`, visible 0.25 s);
   - tier 3: tip glow disc r 3.5 alpha `0.12 + 0.08*sin(_age*3)` in `col`;
   - tier 4: `n = 2 + rarity/3` motes orbiting the head at r 7, 1.1 rev/s, `hot`;
   - tier 5: `n * 2` motes, a swing ghost (3 faded copies of the blade line at `swing`, `swing - 0.25`, `swing - 0.5`, alpha 0.35, 0.2, 0.1) while `abs(swing) > 0.05`, and a 0.4 s faint trail of the tip positions;
   - tier 6: dotted halo ring r `reach + 9` rotating 0.6 rev/s, `n * 3` motes, a tip star (4 points, 0.5 s pulse), and for light weapons a soft glow;
   with `n_total <= Hand aura motes` from table 2.2 and <= 40 draw calls. Weapons add their own extra state drawings through `kind` strings listed in their file (e.g. `"orbit_blades"`, `"stance_ring"`, `"charge_dots"`): extra kinds draw from `state`, `aim` and `_age` only. This also fixes today's gap that orbiting blades, charge dots and stance rings are drawn inside the host's weapon node and are invisible to LAN clients.
   - Local-only drawing (`Weapon._draw`: previews) stays as is.
3. Art starts at tier 2; tier 1 keeps the old look. A weapon's `PALETTE` triple is the colour source for its fx too.

### 5.2 Code layout and hooks (written once by whoever implements the first weapon)

| File | Holds |
|---|---|
| `items/weapons/weapon_tiers.gd` (`WeaponTiers`) | `static func mod(id) -> Script` (loads `res://items/weapons/tiers/<id>.gd`, cached, null if absent), `static func run(w, fn: String, args := [])` (calls `mod(w.weapon_id).fn(w, tier, ...)` when it exists), `FRAC := {1:0.0, 2:0.20, 3:0.35, 4:0.55, 5:0.78, 6:1.0}`, `static func rarity(w) -> int` |
| `items/weapons/weapon_art.gd`, `weapon_aura.gd` | 5.1 |
| `items/weapons/tiers/<id>.gd` | ONE file per weapon, no class_name, `extends RefCounted`, only statics. A fused weapon may `preload` its parent's file and call its functions with other numbers. Function contract below |

Per-weapon module contract (every function optional; `w` is the Weapon or the Tool; `tier` is `w.tier`):

```
static func equip(w) -> void                          # once, from Weapon._ready after the sprite exists: w._st = {...} defaults, spawn the WeaponAura
static func pre_attack(w) -> void                     # optional, BEFORE the old attack() (to change its parameters through w._st, e.g. a longer thrust)
static func attack(w) -> void                         # right after the old attack() was called (hit may still be pending: visuals + counters)
static func ability(w) -> void                        # right after the old ability()
static func release(w) -> void                        # hold abilities / bow: after release_ability() / release_item()
static func dash(w) -> void                           # right after dash_attack()
static func ultimate(w) -> void                       # right after ultimate() was started (it may still be awaiting)
static func on_hit(w, e: Node, dmg: float) -> void    # after every WeaponUtil.hit made by THIS weapon (twist already applied); e may be freed: check
static func dash_hit(w, e: Node) -> void             # from Weapon._on_dash_hit
static func tick(w, delta: float) -> void             # from Weapon._process (host)
static func aura(a: WeaponAura, c: CanvasItem) -> void  # extra drawing for kind strings (clients too)
```

Every verb (`attack`, `ability`, `dash`, `ultimate`, `release`) also accepts an optional `pre_<verb>(w)` that runs BEFORE the old function.

Hook points in the base classes:
- `items/weapons/weapon.gd`: `_ready` (after the sprite): `sprite.texture = WeaponArt.icon(...)`, `_st = {}`, `WeaponTiers.run(self, "equip")`; `use_item` after `attack()`: `WeaponTiers.run(self, "attack")`; `use_ability` after `ability()`; `use_dash` after `dash_attack()`; `use_ultimate` after `ultimate()` (the `ultimate()` call is not awaited so the module runs immediately and may use timers); `_on_dash_hit` base calls `WeaponTiers.run(self, "dash_hit", [e])`; `_process` end: `tick`. `_claim()` also sets `WeaponUtil.owner = self` (a static, like `power`). `_exit_tree` frees its aura.
  Subclasses that override `release_ability`, `release_item` or `use_ability` (hammer, lance, bow, bulwark, rapier, warpbow, shield...) add the one line `WeaponTiers.run(self, "release")` at the end of their release.
  `var _st := {}` (host-only state) and `func verb() -> String` (the verb whose window is open: attack 0.35 s, ability 1.0 s (hold: until release + 0.5 s), dash 0.4 s, ultimate 3.0 s, else "attack"); attribution is approximate, use it for flavour only.
- `items/item.gd` (`Tool`, Sword and Pickaxe): add `weapon_id` (= `_id()`), `player` (= `get_parent().get_parent()`), `aim`, `fx()`, `game_world()`, `_st`, and the same hook calls in `_ready`, `use_item` (it is `pass` today: the animation hitbox does the damage; the module's `attack(w)` times its riders against the animation, hit moment about 0.12 s after the click), `use_ability`, `use_dash`, `use_ultimate`, `_process`. Tool damage today does not go through `WeaponUtil.power`; riders use `WeaponUtil.hit` (so they do) with 2.0 as H.
- `items/weapons/weapon_util.gd`: `static var owner = null` (the weapon that last `_claim`ed); `hit(...)` gets a final parameter `quiet := false`: `quiet` skips the twist, the `on_hit` hook and `Game.hit_stop`; after the twist, `if !quiet and owner != null: WeaponTiers.run(owner, "on_hit", [e, dmg])`. A static `_rider := false` guard stops recursion (a rider's own `hit` sets it).
  `static func stun(e, secs)`: caps stun to 2.0 s per 3 s per enemy (`set_meta("stun_cd_until")`), uses `apply_slow(0.0, s)` only for non-bosses (bosses get `apply_slow(0.35, s)`); new code calls this instead of raw stuns.
  `static func nearest(tree, pos, r, skip := [])`, `static func random_enemies(tree, pos, r, n)`: helper selection (enemies in group `enemy`, `_alive`, `hit_radius` aware).
- `items/weapons/projectile.gd` and `fx.gd`: section 4.

### 5.3 Multiplayer (from CLAUDE.md and MULTIPLAYER.md)

- Weapons are simulated on the host (remote and split-screen players have real player nodes on the host). Clients only see mirrored effects. So: every new visual goes through `WeaponFx.spawn` / `Sfx.play`, persistent visuals through the net nodes `WeaponAura`, `WeaponProjectile`, `Hazard`, `LightSource`, never through a new local node. No `randf()` in `_draw`; use `jit(i, salt)` = `fposmod(sin(i*12.9898 + salt*78.233) * 43758.5453, 1.0)`.
- All per-weapon state is host-only: `w._st`. Anything that changes how it is DRAWN lives in the aura's public vars.
- The `WeaponUtil` statics (`power`, `element`, `twist`, `lit`, now `owner`) are shared by every player. A rider that waits (`await get_tree().create_timer(...)`) must call `w._claim()` again when it resumes and before every `WeaponUtil.hit` (the previous weapon may have changed the statics in between), and must start with `if !is_instance_valid(w) or !w.is_inside_tree(): return`.
- Per-enemy marks use `e.set_meta("wt_<name>", deadline_seconds)` with `Time.get_ticks_msec()/1000.0`; if a mark must change enemy rules, change it once in `Enemy.apply_traits` and document it in the file.
- Clients act only through `Net.net_command` (already so for attack/ability/dash/ultimate input); this work adds NO new commands. Weapon changes with no new node type need no `net_coverage` change; the new node `WeaponAura` is group `net` and must be run through `tools/tests/net_coverage.gd`.
- Players are never hurt by new effects, except the existing `burn` patch (30/s). Prefer `slow`/`heal` patches and ground strikes.
- Bosses: `Boss.apply_slow` never stuns and `push` is weak; control effects check `e.has_method("charm")`, `e.is_in_group("boss")` (bosses are immune to charm, conversion, pulls beyond 40% strength, and `WeaponUtil.stun`).

### 5.4 Balance guard rails (keep damage budgets comparable to `Game.WEAPON_BASIC`)

All numbers are BEFORE `WeaponUtil.power` (which already grows with tier and rarity), per single target standing in the effect, summed over the verb, at tier 6 (lower tiers scale by `WeaponTiers.FRAC`).
- ATTACK riders: average added damage per swing <= +40% of H (a proc of 2 H every 5th swing counts as +0.4 H). The basic hit itself stays `Game.basic_hit`. This keeps `weapon_rules.gd` DPS ordering true.
- ABILITY riders: <= +60% of the ability's damage today. Pure control/shape changes cost nothing.
- DASH riders: <= +0.8 H per dash.
- ULTIMATE: stages after the first plus the finale add up to +100% of today's ultimate damage (stage 2 at tier 5 <= +50%, finale at tier 6 <= +50%). If today's ultimate deals under 4 H (exposes, buffs), treat it as 4 H.
- Per-use total (all verbs the tier adds, for one use) must stay <= `H * k` with `k = {Common 14, Uncommon 18, Rare 22, Epic 30, Mythic 40, Ancient 52, Legendary 70}` for the whole ultimate on a target in the middle, as a sanity check; the implementer sums it in the test.
- Hits per second: no effect ticks a target more than 5 times per second; no single frame hits one enemy more than twice (hit-stop and damage numbers pile up). Many small hits use `quiet = true` and `aoe = true`.
- `Game.hit_stop` fires for hits with raw damage >= 5: many-hit effects keep individual hits under 5 raw (or `quiet`), and only the headline hit of an ultimate is >= 5.
- Control: no new stun > 1.5 s on non-bosses; use `WeaponUtil.stun`. Bosses get slows only.
- Defence: no tier adds invulnerability beyond +25% of today's `shield_time`/`parry_time`; heals no more than 3% of the damage dealt (lifesteal twist already exists) and never above today's heal per use +50%.
- Performance: live `WeaponFx` nodes from one player <= 120; live projectiles <= 40 (children included); timers per verb <= 60; at most one `LightSource` per verb burst and <= 3 alive per player; patches <= 6 alive per player. Strike lists above these use every second strike. A verb that exceeds its rarity's "added fx" must drop the extras, not the design.
- Telegraph: every damaging stage bigger than a Common's hit shows a `ring`/`sigil` for >= 0.3 s before it lands (`ground_strike` already does).
- Fairness for the owner: new effects never delay the first hit of the verb by more than 0.25 s, never take control away from the player, and never block movement except where the weapon is a stance weapon today.

### 5.5 Test skeleton (style of `tools/tests/guards.gd`)

One file `tools/tests/weapon_tier_abilities.gd` with a section per weapon (`-- only=<id>`; `ok()` prints `PASS`/`FAIL`), plus the shared helpers below. Never name `Weapon`, `WeaponTiers`, `WeaponArt` as types; use `load("res://...")`.

```gdscript
extends SceneTree
## Weapon tiers 2-6 (docs/weapon_tiers): each tier's own upgrade, kept by the next tier, absent from the one before.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
var game
var world
var player
const P := Vector2(-40, 260)

func dummy(pos: Vector2, hp := 99999.0):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.health = hp
	e.set_physics_process(false)            # stands still; true only when the walking matters
	e.get_node("NavigationTimer").stop()
	return e
func lost(e) -> float:
	return 99999.0 - (e.health if is_instance_valid(e) else 0.0)
func clear() -> void:
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.1)
func aim_at(p: Vector2) -> void:                 # the weapon aims at the mouse
	root.warp_mouse(root.get_canvas_transform() * p)
	await wait(0.1)
func equip(id: String, tier: int):               # entry = id:bonus:twist; bonus = tier - fusion tier
	var f: int = load("res://items/fusion.gd").tier_of(id)
	var entry: String = game.make_weapon_entry(id, tier - f, game.weapon_twist(id, tier))
	player.equip_item(game.weapon_info(entry))
	await wait(0.3)
	player.position = P
	player.shield_time = 0.0
	player.speed_mult = 1.0
	return player.item
func fx_kinds(seen: Dictionary) -> void:        # call every 0.05 s while an effect plays
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/fx.gd"):
			seen[n.kind] = int(seen.get(n.kind, 0)) + 1
func count_script(path_end: String) -> int:     # projectiles, auras, hazards
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with(path_end):
			c += 1
	return c
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://wtier_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	player = world.get_node("Player")
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	# per weapon: func t_<id>() -> void with checks, called when only == "" or only == id
	quit()
```

Checks every weapon section must contain: (1) "tier N-1 does not have X, tier N has X" for each tier's headline upgrade (compare a measurable: fx kinds seen, damage, count of
projectiles, distance moved, meta flags, health of a dummy); (2) "tier 6 still has the tier 2 upgrade"; (3) draw smoke: equip each tier, `await wait(0.3)`, `player.item.queue_redraw()`, and the aura exists
(`count_script("weapon_aura.gd") == 1` for tier >= 2, 0 at tier 1) with no script errors in the log; (4) a budget check: during the ultimate at tier 6 the
number of live fx nodes stays <= 120 and the damage a central dummy takes is within `H * k` of section 5.4 (print the actual ratio); (5) `weapon_rules.gd` still passes.

### 5.6 Order of work and dependencies

1. Shared pieces: new `WeaponFx` kinds, `WeaponProjectile` features, `WeaponUtil` (`owner`, `quiet`, `stun`, `nearest`, `random_enemies`), `WeaponTiers`, `WeaponArt`, `WeaponAura`, hooks in `weapon.gd` and `item.gd`, the test base. Verify with the Sword.
2. Weapons in the order of the queue (rarity ascending). Lower rarities are the yardstick: a design file names the lower-rarity weapon it must outshine.
3. After each batch run `tools/tests/net_coverage.gd`, `weapon_rules.gd`, `kits.gd`, `tiers.gd`, `tool_tiers.gd`, `weapon_tiers.gd`, `forge_numbers.gd`, `single_source.gd` (new colours must come from `PALETTE` or `Game.rarity_color`, not raw `Color(` literals in UI code; weapon-side fx colours are not UI code).

### 5.7 File template used by every weapon file

`# <Name>` / `## Today (3 lines)` / `## Tier table` (rows 2..6: ART, ATTACK, ABILITY, DASH, ULTIMATE, twist) / `## What makes this feel like <rarity>` /
`## Rules for the implementer` (files, constants, hooks, multiplayer, performance budget) / `## How to test` (4 to 6 headless checks).
A cell marked `=` is unchanged from the row above (higher tiers keep everything). A cell marked `-` has nothing at that tier.

### 5.8 Cross-weapon registry (things the weapon files rely on; write each once)

Rarity band notes learned while designing the 39 weapons:
- Mythic, Ancient and Legendary each own a SYSTEM (a named mechanic the whole weapon plays with: Rot, Heat, Spirit Blades, Charge and Detonate, Rift Gates, Armour Plates, Fault Lines, Crystal Lattice, Hex, Souls, Constellations, Charged Gates, Tectonic Plates, Spectrum, Radiance, Hunger and Gravity, Will). The system is introduced at tier 2 or 3 and every later tier is partly an upgrade of that system.
- TRANSFORMATION windows (tier 6 ultimate): Mythic <= 10 s, Ancient <= 12 s, Legendary <= 15 s, counted from the end of the old ultimate. The "ultimate show length" row of 2.2 counts the OLD part plus stage 2; the transformation is on top and is the reason these weapons exist. A weapon in a transformation can still be swapped out: `_exit_tree` / `is_inside_tree()` checks end it cleanly (`player.speed_mult = 1.0`, `WeaponAura` freed, scale back).
- Cinematic beat: at most ONE `Game.hit_stop(0.3)` per ultimate and only for Legendary (Dawnbringer, Voidreaver, Mindbender).
- Fused-weapon rule used in all files: a fused weapon's module does NOT inherit its parents' module (dispatch is by `w.weapon_id`); it calls `preload("<parent>.gd")` helpers on purpose and says which ones. A fusion at tier F has an ENTRY row carrying the upgrades of rows 2..F.
- Execute effects (kill a non-boss below 15 to 25% health) exist only in Chain Fangs, Soulreaper, Voidreaver (and tier 6 of nothing else): bosses are always immune.

New shared code (implementer checklist, besides sections 4 and 5.1 to 5.2):
- `WeaponTiers.seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float` (distance from a point to a segment) used by Starfall and Stormcaller Bow lines; `WeaponTiers.watch(w, e)` / `WeaponTiers.deaths(w) -> Array[Vector2]` (a kill watch list: remembers enemies you hit with their last position, returns the positions of those that died since the last call; `_st.watch`); `WeaponTiers.owns(w, key) -> bool` (true when a module has replaced a base behaviour, e.g. Shield's growing Bastion pulses).
- `Game.MARKS` (from `docs/card_tiers/_CONVENTIONS.md` 11) gains `"hexed_until": 1.2` (Witch Staff) and `"void_until": 1.1` (Voidreaver). `Game.mark_mult` multiplies them like the others (bosses ignore marks).
- `WeaponUtil.rot_mult(e) -> float` (1.0 + 0.1 x stacks of `wt_rot`) read by `bleed` for the poison element; `WeaponUtil.stun`, `nearest`, `random_enemies`, `owner`, `quiet` (5.2).
- `WeaponProjectile`: `style, size, glow, trail, homing, chain, burst_r, burst_mult, split, wobble, on_hit_fx, owner_id, spin` (4.3). Styles needed by the files: `arrow, orb, shard, blade, crescent, glob, bolt, lance`.
- `WeaponFx` kinds: `slash, streak, cone, beam, orbit, vortex, crack, sigil, cut, shock` (4.2) plus the card kinds already present.
- `WeaponAura` public vars used by the files: `wid, tier, aim, swing, reach, kind, col, state` (base) and, per weapon, `phase` (orbit angle), `n_blades`, `n_spirit`, `avatar` (Spellblade, Starfall), `ng, g1, g2, g3` and `gates6` (Warp Bow, Stormbow), `n_fam`, `n_lens`, `n_suns`, `wings`, `radiance` (Crystal Wand, Prismatic Staff, Dawnbringer), `n_souls, reapers, scythe_r` (Soulreaper), `holes: PackedVector2Array, n_holes, blacksun_r, eclipse` (Voidreaver), `n_witch` (Witch Staff). Public aura vars are replicated automatically (MULTIPLAYER.md rule 2); keep each as a small int/float/Vector2/PackedVector2Array.
- Tool facade for `Tool` (Sword/Pickaxe): `weapon_id`, `player`, `aim`, `fx`, `game_world`, `_claim` (already), `_st`.

Priority and cost guide for the implementer (so the first merge is useful):
1. Shared code and art (5.1, 5.2, 4.2, 4.3, this list) and the Sword + Spear + Hammer (the three Common verbs exercise every hook: Tool, melee, hold-release).
2. Commons and Uncommons (cheap, visible everywhere early in a run).
3. Rare and Epic.
4. Mythic and Ancient (each needs its aura kind); do the ones that share systems together: Staff to Witch Staff to Prismatic Staff (arcane), Bulwark to Juggernaut to Worldbreaker (stance), Quake Pick to Earthshaker to Worldbreaker (ground), Spellblade to Starfall, Tempest to Stormbow, Warp Bow to Stormbow.
5. The Legendaries last (they depend on the heal/light/hit-stop rules and the Guard and `charm` fields).
Rough sizes: Common about 150 lines each, Uncommon 200, Rare 250, Epic 350, Mythic 450, Ancient 550, Legendary 700, plus about 900 lines of shared code.
