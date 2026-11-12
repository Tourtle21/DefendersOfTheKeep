# Chain Fangs (`chainfangs`, Epic, no element, fusion tier 2 of Daggers + Whip, H = 2.88)

## Today
- Attack: a fast 2-hit chain slash (cd 0.3): `arc` r 36 (+-40 degrees), 1.0 H x `melee_share`; the 2nd hit of a pair (within 0.6 s) pulls the target 170 px/s toward you. An exposed enemy is a backstab x3, shake 2, red ring. Grapple (tier 2+, cd 6): the nearest enemy in a 130 px line: you fly to it (dash 0.14 s), hit 1.0, expose 2 s. Chain Sweep (dash, cd 4): 40 px dash, hits 1.5 and slows 0.4 for 1.0 s.
- Hunt (tier 3+, cd 60): five consecutive dashes onto the 5 nearest distinct enemies within 170 px (0.16 s apart), each 5.0 and a line fx. Fused weapon: `Soulreaper` extends it.
- Looks: grey-blue arcs, a line for the grapple.

Palette: chain steel `Color(0.80,0.85,1.0)`, link `Color(0.55,0.60,0.75)`, blood `Color(1.0,0.30,0.30)`, silver `Color(0.95,0.97,1.0)`. Names: 2 Barbed Chain, 3 Reel, 4 Chain Lightning, 5 Dragnet, 6 Execution.

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Grapple) | DASH (Chain Sweep) | ULTIMATE (Hunt) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Barbed Chain | The fangs are linked by a visible chain: the aura draws a swaying chain (6 links) from the hand to the blade; aura twinkle. | The 2nd hit's reel-in has a `streak` of links (`line` fx, 3 px) back to you | **Barbed Chain**: the grapple's chain remains as a tether for 1.5 s: the target is exposed 3 s (not 2) and gets 3 bleed ticks of 0.15 H, and the arrival is a `flash` r 14. | - | locked | lifesteal |
| 3 Reel | Tip glow, chain glints. | **Reel**: every 3rd pair (the 6th hit) is a "yank": all enemies within 60 px of the target are also pulled to you (260, 0.2 s), slowed 0.4 for 1 s; `slash` r 36 thick 4 + `shards` count 6. | = | = | unlocked; `sigil` r 90 (steel) 0.25 s. | lifesteal |
| 4 Chain Lightning | 2 orbit links, gem pixel. | = | **Chain Link**: the grapple's tether jumps: from the target the chain arcs to the nearest enemy within 60 px (and again, 2 jumps): each jump 0.5 H (1.4), exposes 2 s, a `bolt` fx between victims. | **Chain Lash**: the sweep is a `streak` with a chain (width 7); it also reels in everything within 30 px of its path 80 px/0.2 s, hits 1.0 H more (2.9) at the end point `shock` r 26. | = | thunder |
| 5 Dragnet | 4 links orbit, trail. | = | = | = | **Stage 2 Dragnet**: after the 5th target a net of chains drops over the whole hunted area: a `vortex` (inward, r 100, count 4) pulls every enemy within 100 px to the final position over 0.4 s, exposes 3 s, slows 0.2 for 1.5 s; each hunted target (up to 5) is chained to you by a `line` fx (persistent for 1.5 s). | thunder |
| 6 Execution | Halo ring (chain ring), 6 motes, tip star. | **Finisher** every 6th hit: an executing double cut: 2 x 0.8 H on a target below 30% health: instead it dies if its health is below 15% of `max_health` (not bosses) with a `cut` r 20 and `flash` r 14. | = | = | **FINALE Execution**: 0.3 s after Dragnet every exposed enemy within 100 px takes 1.5 H (4.3) in a rapid series of 3 cuts (`cut` fx on the 5 nearest: 0.5 H each); targets below 25% health are executed (instant kill except bosses). `shock` r 100 (thick 6), shake 5.5, `Sfx big_hit` + `ultimate`. | bleed |

Caps (H = 2.88): attack avg +0.2 H; ability bleeds 3 x 0.15 + jumps 2 x 0.5 = +1.5 H; dash +1.0 H; ultimate dragnet 0 + finale 4.3 (+execute) vs today 5 x 5.0 = 17 = +25%. Execute thresholds are small (15% and 25%) because no weapon so far kills outright: bosses immune.

## What makes this feel like Epic
A tether system: every verb now creates or uses a visible chain between you and enemies, and the ultimate nets the whole group. Compared with Rare Rapier (a rhythm), the Fangs' pattern is spatial: where the chains go. Compared with Daggers (Uncommon) its backstab/exposure chain covers a pack, not one target.

## Rules for the implementer
- `items/weapons/tiers/chainfangs.gd`; `chainfangs.gd` edits: `ability()` expose duration and bleed at tier >= 2 and the jumps at tier >= 4 (after the grapple hit), `attack()` counts hits in `_st.hits`: the yank on the 6th hit inside the module (`attack(w)` after the old hit), `dash_attack()` pull; `ultimate()` unchanged: the module's `ultimate(w)` schedules Dragnet at press + 0.16 x n + 0.2 (n = number of targets found; store `_st.hunt_n` in the old function: one line) and the finale 0.5 s later.
- Soulreaper `extends chainfangs.gd` and has its own module (calls `preload("chainfangs.gd")` functions).
- Constants: `CF_BLEED_TICKS := 3`, `CF_YANK_EVERY := 6`, `CF_YANK_R := 60.0`, `CF_JUMPS := 2`, `CF_JUMP_R := 60.0`, `CF_JUMP_MULT := 0.5`, `CF_NET_R := 100.0`, `CF_EXECUTE := 0.15`, `CF_FINALE_EXECUTE := 0.25`, `CF_FINALE_MULT := 1.5`.
- Execute: `e.health <= e.max_health * frac and !e.is_in_group("boss")` then `e.spell_damage(e.health + 1.0, "", false)`; one per enemy.
- Multiplayer: chains are `line` fx; nothing else. Performance: finale 20 fx.

## How to test (section `chainfangs`)
1. Barbed Chain: tier 2 grapple: the target is exposed >= 2.5 s afterwards (read `exposed_until`) and loses health in 3 ticks; tier 1 2.0 s and no ticks.
2. Reel: tier 3, 6 hits (3 pairs): a dummy 40 px from the target is pulled > 20 px on the 6th hit only.
3. Chain Lightning: tier 4 grapple with dummies B at 40 px from A and C at 40 px from B: both take 1.4 and are exposed; tier 3 only A. Sweep reels a dummy 25 px off the path.
4. Dragnet: tier 5 ultimate with 3 dummies 90 px away: all end within 25 px of the final position and exposed; tier 4 not.
5. Execution: tier 6: a dummy at 20% of its health is dead after the finale (and a boss stand-in is not); a dummy at 100% takes >= 4.3 extra.
6. Draw smoke; Soulreaper still runs (module dispatch by `weapon_id`).
