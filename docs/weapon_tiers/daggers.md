# Twin Daggers (`daggers`, Uncommon, no element, H = 1.6)

## Today
- Attack: alternating `swing` slashes, `arc` r 28 (+-55 degrees), 1.0 H, knock 60, cd 0.22. An EXPOSED target (or a stunned one) is a backstab: x3 (4.8), a red `ring` r 16, shake 2, and half the Shadow Step cooldown is refunded.
- Throwing Knives (tier 2, cd 5): 3 knives (spread 0.16), speed 280, 1.0 each, life 0.36, expose 2 s. Shadow Step (cd 4): 44 px dash, hits 1.0, exposes 2 s with a violet ring. Death Mark (tier 3): ring r 150, everything in it exposed 6 s, you move at 1.4x for 6 s.
- Looks: grey arcs, red and violet rings; it is all about the exposed state.

Palette: steel `Color(0.85,0.90,1.0)`, shadow `Color(0.45,0.30,0.70)`, blood `Color(1.0,0.30,0.30)`, silver `Color(0.95,0.97,1.0)`. Names: 2 Fan of Knives, 3 Flurry, 4 Phantom Step, 5 Shadow Clones, 6 Thousand Cuts.

## Tier table

| Tier | ART | ATTACK | ABILITY (Throwing Knives) | DASH (Shadow Step) | ULTIMATE (Death Mark) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Fan of Knives | Aura twinkle on both blades; exposed enemies near you show 2 violet `motes` over their heads: `tick(w, delta)` spawns a `WeaponFx motes` (count 2, radius 6, life 0.5) every 0.5 s on at most 4 exposed enemies within 120 px (never node meta drawn on clients). | Backstabs throw a `cut` r 12 | **Fan of Knives**: 5 knives (spread 0.14) instead of 3, style `blade` with a 3-dot trail. | - | locked | lifesteal |
| 3 Flurry | Tip glows; both blades trail violet while swinging. | **Flurry**: every 3rd slash becomes 3 cuts in 0.2 s (hits at 0, 0.1, 0.2 s; each 0.5 H, knock 40) with a `slash` fx per cut alternating sides; a backstab inside the flurry only triggers once. | = | = | unlocked; a `sigil` r 90 (`shadow`) for 0.25 s then the ring. | lifesteal |
| 4 Phantom Step | 2 orbiting shadow motes, gem pixel. | = | = | **Phantom Step**: the dash starts with a `streak` (width 6, `shadow`) and leaves a phantom at the start point for 0.6 s (an `orbit` fx shape `blade` r 8 count 2 life 0.6): when it vanishes it strikes everything within 26 px of the start for 0.8 H (1.3), exposes them 2 s, a `cut` fx on each (max 3). | = | thunder |
| 5 Shadow Clones | 4 motes, ghost trail. | = | = | = | **Stage 2 Shadow Clones**: for the 6 s of the mark two shadow clones circle you (`orbit` fx shape `blade`, r 18, count 2, re-spawned every 0.5 s with life 0.6): every 0.6 s each throws a knife (`bolt` fx, quiet hit 0.5 H = 0.8) at the nearest exposed enemy within 120 px and re-exposes it 2 s. | thunder |
| 6 Thousand Cuts | Halo ring, 5 motes, tip star. | **Finisher**: every 6th slash is an X-cut (`cut` r 20): 2 x H total (instead of 1.0), applies a 1.0 s exposure. | = | = | **FINALE Thousand Cuts**: when the 6 s end (or the clones' last throw), every enemy still exposed within 150 px (up to 8) takes 6 quick cuts of 0.35 H (0.56) over 0.5 s with a `cut` fx every second hit (max 5 nearest get fx, the rest damage only) and a `flash` r 18; each finishes with a `burst`. Shake 4, `Sfx big_hit`. | bleed |

Caps (H = 1.6, today's Death Mark counts as 4 H = 6.4 for the budget): fan +2 knives (1.0 each = 2.0 on a clump); flurry avg +0.33 H; phantom 1.3; clones about 10 throws x 0.8 spread over targets (3 per target = 2.4); finale 6 x 0.56 = 3.4: total < +100% of 6.4.

## What makes this feel like Uncommon
It adds speed and trickery on top of Common readability: one extra state (exposed) that you must set up and cash in. Each tier adds a fast, small, many-hit thing: knives, cuts, a phantom, clones. Compared with Spear (Common) the player is now managing a mark, but the spectacle is small and sharp (violet lines and X-cuts), never a big field.

## Rules for the implementer
- `items/weapons/tiers/daggers.gd`; edits in `daggers.gd`: `ability()` count and style, slash counter in `attack()` (module: `attack(w)` increments `_st.slashes` and schedules the two extra cuts via `create_timer(0.1/0.2)`; the old attack has already done cut 1), `ultimate()` unchanged (the module adds the clone loop and the finale).
- Constants: `DAG_KNIVES := 5`, `DAG_FLURRY_EVERY := 3`, `DAG_FLURRY_MULT := 0.5`, `DAG_PHANTOM_T := 0.6`, `DAG_PHANTOM_MULT := 0.8`, `DAG_CLONE_N := 2`, `DAG_CLONE_EVERY := 0.6`, `DAG_CLONE_MULT := 0.5`, `DAG_FINALE_HITS := 6`, `DAG_FINALE_MULT := 0.35`, `DAG_FINALE_MAX := 8`, `DAG_FINISHER_EVERY := 6`.
- Exposure is a meta (`exposed_until`) on the enemy; read with `WeaponUtil.is_exposed`. Death Mark's 6 s: the module stores `_st.mark_until = now + 6.0` and runs a 0.1 s `tick` that fires the clone throws and, at the end, the finale; make the loop cancel when the weapon is swapped (`is_inside_tree()`).
- The refund on backstab keeps working at all tiers (the Flurry's extra cuts do not refund: only the first backstab per flurry).
- Multiplayer: exposed markers are `WeaponFx motes`, never node meta drawn on clients. Projectile cap fine (5 knives).
- Performance: finale at most 5 `cut` + 8 `burst` + 1 `flash` = 14 fx; clones 2 fx per 0.5 s.

## How to test (section `daggers`)
1. Fan of Knives: tier 2 ability spawns 5 projectiles (tier 1: 3); 
2. Flurry: tier 3, 3 slashes on a non-exposed dummy at 20 px: the third slash does >= 2.0 H total (3 cuts of 0.5 H + base), earlier ones 1.0 H; the 3rd has 3 hits (health samples at 0.05, 0.15, 0.25 s).
3. Phantom Step: tier 4 dash: a dummy standing 15 px from the start point (not on the dash line) loses >= 0.8 H after 0.7 s and is exposed; tier 3 unchanged.
4. Shadow Clones: tier 5 ultimate: a dummy at 80 px, exposed by the mark, loses health in >= 4 separate steps of ~0.8 over 3 s; tier 4 none (only exposure).
5. Thousand Cuts: tier 6, after 6.3 s a dummy at 100 px takes >= 6 hits in 0.6 s (sample health every 0.1 s); fx `cut` seen; tier 5 not.
6. Draw smoke; the dash cooldown refund on backstab still works at tier 6.
