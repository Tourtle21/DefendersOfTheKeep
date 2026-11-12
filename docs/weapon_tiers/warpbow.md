# Warp Bow (`warpbow`, Mythic, no element, fusion tier 2 of Bow + Staff, H = 3.21, inherits `bow.gd`)

## Today
- Attack (from the Bow): hold left click to draw (0.8 s to full, you move at 60%), release fires: damage `H x (0.33 + 0.67 x ratio)`, speed 200 to 360, full draw pierces 1, release in the 0.8 to 1.1 s window is a perfect x1.6 (gold ring). The arrow colour is arcane-violet in the Warp Bow's own icon only.
- Warp Arrow (tier 2+, cd 6): fires a 0.5-damage marker arrow to the cursor (max 150 px) that plants an ANCHOR (violet `ring` r 14 lasting 2.5 s); a second right click within 2.5 s teleports you there (`player.blink`) with rings and a 0.05 s `ground_strike` r 26 (3.0, stun 0.5); unused it costs a 3 s cooldown. Phase Step (dash, cd 3): a short blink (40 px) with 0.3 s `shield_time`.
- Rift Volley (tier 3+): nine piercing arrows in a 0.12 rad fan (3.0 each, pierce 3, knock 100). Stormbow extends it (`_on_warped`, its own ult).
- Looks: violet rings and arrows.

Palette: rift violet `Color(0.65,0.50,1.0)`, gate white `Color(0.92,0.88,1.0)`, arrow `Color(0.85,0.75,1.0)`, void `Color(0.15,0.10,0.30)`. Names: 2 Rift Gate, 3 Echo Arrow, 4 Gate Chain, 5 Rift Barrage, 6 Rift Storm.

THE MYTHIC SYSTEM: **Rift Gates**. The anchor becomes a visible oval gate (aura `kind "gates"`: positions up to 3 stored as public aura vars `g1, g2, g3`, `ng`). Any arrow of yours that passes through a gate is DUPLICATED: it re-emerges from your hand (tier 3), or from every other gate (tier 4+). Gates last until used or 6 s (the anchor's 2.5 s grows to 6 s at tier 2: the 2nd right click still warps, taking you to the NEWEST gate; old gates stay).

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK (draw) | ABILITY (Warp Arrow) | DASH (Phase Step) | ULTIMATE (Rift Volley) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Rift Gate | The bowstring glows violet at full draw; arrows have a glow and a 4-dot trail (style `orb`-tipped `arrow`); the anchor is drawn as a gate: an oval of 12 dots with a swirl (aura `kind "gates"`). Entry: aura twinkle. | Arrows have `trail 4` and `glow 0.3`. | **Rift Gate**: the anchor lives 6 s (not 2.5) and warping to it leaves a gate at the departure point for 2 s (a return trip): a second right click within 2 s warps you back. | - | locked | bleed |
| 3 Echo Arrow | Tip glow; gates pulse. | **Echo Arrow**: an arrow shot through a gate (its path within 18 px of the gate) is echoed: a copy leaves your bow-hand 0.15 s later toward the same direction (60% damage, pierce as the original), and the gate flashes. | **Echo Gate**: warping hits everything within 26 px at BOTH ends (`ground_strike` r 26 at departure too, 0.05 s, 2.0). | = | unlocked; the volley's `sigil` r 40 (violet) at the bow 0.3 s. | bleed |
| 4 Gate Chain | 3 orbit violet motes, gem pixel. | = | **Gate Chain**: you may place up to 3 gates: each right click within 2.5 s of the previous (before warping) places another (max 3, the first costs the cooldown; a 4th press warps to the last). Arrows through ANY gate re-emerge from ALL other gates (at 40% damage each). Warping takes you to the gate you ARE AIMING at (nearest to the cursor). | **Phase Gate**: the dash leaves a gate (2 s) at the start; `streak` (width 5). Arrows shot through it echo (as above). | = | chill |
| 5 Rift Barrage | 5 motes, ghost trail. | = | = | = | **Stage 2 Rift Barrage**: the nine-arrow volley is fired from EVERY gate too (3 arrows from each gate toward the cursor, 0.3 s staggered, 0.6 H = 1.9 each, pierce 2); each volley arrow that crosses a gate echoes (cap 24 projectiles). If you have no gate, one is planted at the cursor for the volley. | thunder |
| 6 Rift Storm | Halo ring (a ring of 6 gate ovals), 8 motes, tip star. | **Finisher** every 5th shot: a "rift arrow": opens a gate AT THE TARGET (a 1.5 s gate) from which 3 arrows burst outward (0.5 H each, pierce 1) in a 120-degree fan toward further enemies. | = | = | **FINALE + TRANSFORMATION Rift Storm (10 s)**: the sky opens: 6 gates ring the screen around you at r 90 (60-degree steps, aura draws them as big ovals) for 10 s; your arrows fire from ALL 6 (1 copy each at 40%: cap by `_st` budget), the right click warps you to any gate and fires a 5-arrow fan at the exit, and every 1.5 s a gate fires a piercing arrow at the nearest enemy (1.0 H = 3.2). At the end all gates fire together: 6 gates x 4 arrows (0.5 H = 1.6, pierce 2), `flash` r 30 at each gate, `ripple` r 100 rings 3. Shake 6, `Sfx ultimate`. | lifesteal |

Caps (H = 3.21): attack echo +40..60% of an arrow only on gate crossings (a few a minute); ability warp 2.0 + 3.0; dash +0; ultimate: barrage 3 gates x 3 arrows x 1.9; the transformation's gate shots (every 1.5 s, 1.0 H each, a central target gets at most 4 = 13 H) plus the finale (24 arrows of 1.6, a central target meets about 6 = 9.6 H): the sum on one target stays under the Mythic k = 40 H.

## What makes this feel like Mythic
A SYSTEM: gates that you place, shoot through and warp between, whose geometry multiplies your arrows. The tier 6 ultimate rings the screen with gates and every arrow is copied six times: spectacle comes from geometry, not from big explosions. Compared with Epic Staff (rift mines), the Warp Bow's gates move YOU and your projectiles.

## Rules for the implementer
- `items/weapons/tiers/warpbow.gd` (`preload("bow.gd")` module helpers: draw ratio and trail). `warpbow.gd` edits: `use_ability()` (anchor list `_gates: Array[Vector2]` replaces the single `_anchor`; keep `_anchor` as the last element for Stormbow's `_on_warped`; the 2.5 s timer becomes 6 s at tier 2), `dash_attack()` gate, `ultimate()` unchanged: the module adds the barrage at press + 0.3 s and the transformation at 1.0 s.
- Gate crossing: in `tick(w, delta)` iterate `WeaponProjectile` nodes in the group `net` whose `get_meta("owner") == w` (set in `shoot` through `extra {"owner_id": player_id}`: add public var `owner_id := 0` to `WeaponProjectile` and set it in `Weapon.fx`-style helper) that are within 18 px of a gate and have no meta `wt_gated`; mark them `wt_gated` (so they echo once) and spawn the copies via `WeaponProjectile.shoot` with the same `style/pierce`, `vel`, `owner_id`, `wt_gated = true`.
- Public aura vars: `ng: int`, `g1`, `g2`, `g3: Vector2` (gate positions; the Rift Storm ring uses `kind "gates6"` with `phase`).
- Constants: `WB_GATE_SECS := 6.0`, `WB_BACK_SECS := 2.0`, `WB_ECHO_MULT := 0.6`, `WB_ECHO_DELAY := 0.15`, `WB_GATES_MAX := 3`, `WB_CHAIN_MULT := 0.4`, `WB_BARRAGE_ARROWS := 3`, `WB_BARRAGE_MULT := 0.6`, `WB_FINISHER_EVERY := 5`, `WB_STORM_SECS := 10.0`, `WB_STORM_GATES := 6`, `WB_STORM_SHOT := 1.5`, `WB_FINAL_ARROWS := 4`, `WB_FINAL_MULT := 0.5`, `WB_PROJ_CAP := 40`.
- Stormcaller Bow `extends warpbow.gd`: its `_on_warped` keeps working (the last gate is `_anchor`). Its own module `preload`s this file.
- Multiplayer: the aura draws gates from synced vars; projectiles are net nodes (cap 40 alive per player: refuse echoes above the cap).
- Performance: Rift Storm ~25 projectiles peak, 6 aura ovals (each 12 dots) = 72 dots: draw them as 6 `draw_arc` + 6 small circles (<= 20 calls).

## How to test (section `warpbow`)
1. Rift Gate: tier 2, warp arrow: `ng == 1` for >= 5 s (not 2.5); after warping a return gate exists for 2 s and a second right click returns.
2. Echo Arrow: tier 3, an arrow shot through the gate: projectile count 2 within 0.3 s; tier 2 only 1; the warp hits a dummy at the DEPARTURE point too.
3. Gate Chain: tier 4: three right clicks place `ng == 3`; an arrow through one gate re-emerges from the other two (count >= 3 projectiles); the dash leaves a gate.
4. Rift Barrage: tier 5 ultimate: projectiles spawned at gate positions (not only at the bow) >= 9 within 1.5 s; tier 4 only the 9 from the bow.
5. Rift Storm: tier 6: aura `kind "gates6"` for ~10 s; each shot spawns copies at the gates; at ~11 s `flash` kinds at 6 gates; projectile count never > 40.
6. Draw smoke; Stormcaller Bow still warps (its `_on_warped` strikes) with gates present.
