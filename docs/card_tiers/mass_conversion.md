# Mass Conversion (`mass_conversion`, kind `charm`, no element, LEGENDARY)

## Today
- Same kind as Charm, bigger: lands over `radius` 95 and calls `e.charm(duration 25)` on every enemy in it (bosses have no `charm` and are untouched). One cyan `ring` and the node frees itself at once. A converted enemy hunts the nearest other enemy within 220 px (`Enemy._charmed`) and is a target for the others (group `ally`).
- Costs mana 60, 2 gems, 4 gold.
- Adds already (charm pool): t2 `wide`, t3 `lingers`, t4 `twin`, t5 `refund`, t6 `potent`.
- The Charm card's tier abilities (`charm.md`) are keyed on `data.id == "charm"`; Mass Conversion has its own, below, built on the same enemy fields (`charm_power`, `charm_blast`, `charm(time, power, blast)` described in `charm.md` — build Charm first or add those fields here).

Palette: mind `Color(0.55,0.9,1.0)`, violet `Color(0.55,0.4,0.95)`, white `Color(0.95,0.98,1.0)`, banner gold `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Conscription | Wave landing: an expanding wave ring (3 rings, `ripple`) and a violet mind-eye at the centre for 1.0 s (almond outline 2 arcs + iris circle r 4 + pupil r 2, blinking). Each converted enemy gets a cyan ring under its feet and a small cyan flame above (drawn by the spell for 1.5 s after landing from the enemies with `charm_time > 0` inside; later by their own tint only). | `ripple` radius r rings 3 mind, `motes` count 14 radius r rise 24 violet; `Sfx.play("cast")`. | **Conscription**: converts are healed to full on conversion and fight 30% harder (`charm_power` 1.3). | wide |
| 3 Rally Banner | The spell stays for the whole conversion (see rules): a banner stands in the middle (pole rect 2x26, flag polygon 14x9 waving by `sin(since*4)`, mind colour with a violet eye emblem, gold finial), with a faint dashed ring of radius 0.9 r around it. Rally lines: thin dashed lines from the banner to up to 12 converts (alpha 0.18). | Banner glow pulses each 2 s. | **Rally banner**: converts with nobody to fight within 220 px march back to the banner and wait there (instead of standing still where they were) — a standing army that holds the spot and engages anything that comes. | lingers |
| 4 War Cry | The banner flag grows (20x12) and runs with 8 small flames; a horn motif: a crescent above the flag. Every war cry a ring of cyan runes (8 diamonds) expands from the banner. | Every 5 s: `ripple` radius r rings 2 mind, `star` radius 24 count 6 gold at the banner, `Sfx.play("boss_roar")` (quiet pitch 1.3). Converts glow bright for 2 s (their tint stays; the spell draws cyan halo rings on them). | **War cry**: every 5.0 s all converts get a surge for 2.0 s: `charm_power` 2.0 (twice as hard-hitting) and 25% faster; implemented by re-calling `e.charm(remaining, 2.0, blast)` and resetting after 2 s. | twin |
| 5 Lieutenants | The three toughest converts become lieutenants: the spell draws a gold crown (zigzag 5 points) above each and a gold ring around them, and the converts' cyan rings become violet-gold double rings. Lieutenants are 1.3 x larger (scale). Chains of mind-colour between lieutenants and the banner. | Promotion: `star` radius 16 count 5 gold at each lieutenant, `Sfx.play("unlock")`. | **Lieutenants**: the 3 toughest converts (`max_health`) gain +100% health, hit 2.5x as hard and act as rally points: other enemies prefer attacking them (they sit in `ally` already) and idle converts rally to the nearest lieutenant instead of the banner. | refund |
| 6 Dominion | A violet-cyan dome over the whole area: 3 translucent rings (0.4, 0.7, 1.0 r) with 12 rune glyphs rotating, a pale starfield, the banner is enormous (pole 36 px, flag 28x16 with a flaming eye), and a column of mind light from the banner (pillar). A crown of 8 floating swords (thin polygons) circles the banner. | **Finale on landing**: `flash` radius r mind-violet, `ripple` radius 1.5 r rings 4, `star` radius r count 8 gold, `pillar` height 120 width 36, `Sfx.play("ultimate")`; 5 honour guards appear with a `ring` each. | **Dominion**: (1) the conversion spreads: every 0.5 s each convert converts ONE unconverted enemy within 60 px for the REMAINING time (maximum 12 spread conversions per cast); (2) **Honour guard (FINALE)**: 5 Captain-tier guards (`Game.stats_of(Game.make_entry("guards", 4, ""))`) appear around the banner and fight until they fall. Honour guard skipped when `data.copy`. `potent` also gives converts +25% (`charm_power` x 1.25). | potent |

`MC_POWER := [1.0, 1.3, 1.3, 1.3, 1.3, 1.3]`, `MC_SURGE := 2.0`, `MC_SURGE_T := 2.0`, `MC_WARCRY := 5.0`, `MC_LIEUTENANTS := 3`, `MC_SPREAD_MAX := 12`, `MC_GUARDS := 5`.

## Rules for the implementer
- Spell flow for this id: like Charm in `charm.md`: tiers 1 and 2 free the node right after the conversion; from tier 3 the node stays until `duration` ends (tier 3+: `SpellTiers.effect_time` returns `data.duration`), and `tick_mass_conversion` runs. Public vars on the spell (so clients can draw): `banner_on := false`, `lieutenants: Array = []` (Vector2 positions, refreshed every 0.2 s on the host).
- On landing: `e.charm(duration, MC_POWER[tier-1] * (1.25 if "potent" in adds else 1.0), 0.0)`; tier >= 2 also `e.health = e.max_health`.
- Rally (tier 3+): every 0.5 s for each convert (group `ally`, `charm_time > 0`) that has no enemy within 220 px: `Game.move_on_map`-style steering is done in `Enemy._charmed`; add to it: `if best == null and rally_point != Vector2.INF: move toward rally_point if farther than 30 px` with `var rally_point := Vector2.INF` set by the spell (host, a public var so the field replicates; cleared when the charm ends).
- War cry: every 5.0 s `pace`; for each convert: `e.charm_power = MC_SURGE`; after 2 s `create_timer` resets to its base. Draw halos from `charm_power >= 2.0` (public var).
- Lieutenants: pick top 3 `max_health` among converts at landing (and re-pick if one dies); set `e.max_health *= 2.0`, `e.health = e.max_health`, `e.scale *= 1.3` (restore at end), `charm_power *= 2.5 / base` -> simply `charm_power = 2.5`.
- Dominion spread: converts within 60 px of an unconverted enemy: `e2.charm(remaining, base_power, 0.0)` where remaining = `duration - since`.
- Honour guard: `Guard.new()`; `g.setup(card, pos)` with `card = Game.stats_of(Game.make_entry("guards", 4, ""))`; add to `get_parent()`. 5 at `pos + from_angle(i*TAU/5) * 18`.
- Bosses: `has_method("charm")` guards stay. Keep today's behaviour for crystal carriers (`has_crystal`); do not special-case them.
- Draw `SpellArt.draw_mass_conversion`; the per-enemy overlays read `get_tree().get_nodes_in_group("enemy")` with `charm_time > 0` and `global_position` within 1.3 r.
- Multiplayer: new enemy vars are public (`charm_power`, `rally_point`) so they replicate; lieutenant crowns come from the public `lieutenants` array.

## How to test (`tools/tests/tier_mass_conversion.gd`)
1. Conscription: tier 2 dummy with `health = 10, max_health = 100` ends converted with `health == max_health` and `charm_power >= 1.3`; tier 1 not healed.
2. Rally: tier 3 converted dummy with nobody near (others far) walks toward the spell centre (distance shrinks by > 20 px in 2 s); tier 2 stays.
3. War cry: tier 4 at ~5.2 s converts show `charm_power == 2.0`, back to 1.3 after 2.2 more seconds; fx `star` seen.
4. Lieutenants: tier 5 with 5 dummies of different `max_health`: exactly the 3 highest have doubled max health; `lieutenants.size() == 3`.
5. Dominion: tier 6: one dummy converted at landing, another unconverted at 40 px: converted within 1 s (and has the remaining time); 5 guards (`get_nodes_in_group("guard")`) exist right after landing; a `copy` cast has none.
6. Boss in the area is untouched.
