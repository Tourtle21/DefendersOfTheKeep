# Spike Trap (`spike_trap`, kind `build`/`spike_trap`, no element)

## Today
- A floor trap of `radius` 22 with `uses` 10. Every 0.45 s, if any enemy is within `radius`, every such enemy takes `damage` (0.5, scales with tier) and `apply_slow(slow, 0.6)`, then one use is spent; at 0 uses it disappears (`_expire`). Drawn as a pale ring with 7 small grey spikes.
- NOTE: the card's `slow` is 1.0 (= no slowdown) so today it only hurts; the new abilities below do their own slowing.
- Adds already (`BUILD_TWISTS.spike_trap`): t2 `rearm` (+1 use every 3 s), t3 `venom` (bleed on hit), t4 `more_uses` (+3), t5 `barbed` (+50% damage), t6 `deep_freeze` (no effect on slow 1.0, so tier 6's own ability below uses a real slow).

Palette: iron `Color(0.75,0.75,0.8)` (card colour), dark iron `Color(0.35,0.37,0.42)`, rust `Color(0.55,0.3,0.2)`, gold tip `Color(1.0,0.85,0.4)`.

## Tier table

| Tier | ART | ATTACK / EFFECT visuals | ABILITY | Already added |
|---|---|---|---|---|
| 2 Snare | A zig-zag wire loop around the plate (12-point polyline on a circle of 0.85 r, dark iron, width 1.5) with a rivet at each peak; the spikes grow slightly (height 6). | Trigger: `burst` radius 10 iron at each hit enemy; the wire flashes white for 0.2 s. | **Snare**: whoever triggers it is truly slowed: `apply_slow(0.45, 1.0)` on each hit enemy (a real 55% slow for a second; stacks with the card's own slow value if it ever gets one). | rearm |
| 3 Spring Trap | A pressure plate in the centre (disc r 5, dark iron, rim lighter) that sinks (r 4.2) during the 0.2 s after a trigger; spikes are taller (9) with a small spring coil (3 zig-zag lines) at each base and a metallic highlight line on each spike. | Every 3rd trigger the spikes shoot up: `ripple` radius `radius*1.4` rings 2 iron + `shards` count 10 radius radius*1.4, `Sfx.play("big_hit")`. | **Spring trap**: every 3rd trigger the trap springs: `pulse(st, radius * 1.4, damage * 4.0, 200, 0.6, iron, "pierce")` on top of the normal hit. | venom |
| 4 Caltrop Field | 10 caltrops (4-point jacks: two crossed lines r 3) lie scattered in a wider ring (1.0 to 1.35 r, positions `jit`), faint outer disc alpha 0.1 at 1.35 r, a few with a white glint. | When a caltrop patch refreshes: `motes` count 4 radius radius*1.3 rise 8, iron coloured (subtle). | **Caltrop field**: a slow patch of radius `radius * 1.35` keeps lying around the trap while it has uses (`slow_patch(st, radius*1.35, 4.0, 0.6)` refreshed every 3.5 s). Enemies crossing it slow to 60% even before they reach the plate. | more_uses |
| 5 Barbed Chain | A barbed chain runs round the trap: 20 links (circles r 1.2, dark iron) along a circle of 1.1 r, with small barbs (V shapes) at every 4th link; a hook shape at the north point. Spikes get barbs (tiny V near the tip). | Hook: `line` from the trap centre to the dragged enemy (iron, width 2, life 0.2) + `burst` radius 8. `Sfx.play("whoosh")`. | **Barbed chain**: when it triggers, every enemy within `1.6 x radius` outside the plate is dragged to the plate: `push(dir_to_trap * 260, 0.18)` and bleeds (`WeaponUtil.bleed(tree, e, 3, damage * 0.4)`). | barbed |
| 6 Impaler | Double-layer spikes (an outer ring of 7 at 0.8 r plus 4 inner tall spikes of height 14 with gold tips), a rune ring (8 tiny glowing marks, pulse with `_age`), the plate becomes a gold-trimmed skull-free sigil (hexagon outline). Its uses are drawn as pips around the rim. | **Last gasp** (when the last use is spent): `flash` radius 2.2 r iron-white, `ripple` radius 2.2 r rings 3, `shards` count 16, `pillar` height 40 width 20 gold, `Sfx.play("ultimate")`. | **Last gasp**: when its final use is spent it erupts instead of crumbling: `pulse(st, radius * 2.2, damage * 12.0, 260, 1.0, gold, "pierce")` and leaves a slow patch (`slow_patch(st, radius * 2.2, 6.0, 0.4)`). | deep_freeze |

## Rules for the implementer
- `structure.gd` spike branch: after the hit loop, call `StructureTiers.on_trigger(self, hit)` (`hit` is the enemy array) and before `_expire()` at `uses <= 0` call `StructureTiers.on_last_use(self)`; `_expire` must still run (the trap frees itself after the burst; the burst's patch outlives it).
- Trigger counter `_triggers` (private) for Spring trap: `_triggers % 3 == 0`.
- Snare/Barbed Chain/pull are done inside `on_trigger_spike_trap(st, hit)` per enemy; enemies beyond `radius` for the chain come from `StructureTiers.enemies(st, radius * 1.6)` minus `hit`.
- Caltrop patch refresh `pace(st, "caltrop", 3.5)` while `uses > 0`.
- Tier 6 uses `StructureTiers.pulse` with element `"pierce"` (ignores armour).
- Draw: `StructureArt.draw_spike_trap(st, col)`; show remaining uses as pips (max 12) for tier 6 only; plate sink: `st.flash > 0`.
- Constants: `SPIKE_SNARE := 0.45`, `SPIKE_SPRING_EVERY := 3`, `SPIKE_SPRING_MULT := 4.0`, `SPIKE_CALTROP_R := 1.35`, `SPIKE_CHAIN_R := 1.6`, `SPIKE_GASP_MULT := 12.0`.
- Multiplayer: `uses`, `flash` are public already; the patch is a Hazard.

## How to test (`tools/tests/tier_spike_trap.gd`)
1. Snare: tier 2 dummy on the trap after 0.6 s has `slow_mult <= 0.46`; tier 1 `slow_mult == 1.0`.
2. Spring: tier 3 over 5 triggers the damage taken has a spike at the 3rd (>= 4 x damage extra) ; a `ripple` fx is seen.
3. Caltrops: tier 4 `slow` hazard exists (`get_nodes_in_group("hazard")`) and a dummy 1.2 r away has `slow_mult <= 0.61`; tier 3 none.
4. Chain: tier 5 dummy 1.4 r away is closer to the trap after a trigger and is bleeding (health keeps dropping 1 s later); tier 4 not.
5. Last gasp: tier 6 with `uses = 1`: after the trigger a `flash` fx exists, a slow patch with radius ~2.2 r exists, and a dummy at 2.0 r took >= 12 x damage; tier 5 just disappears.
6. Cumulative: tier 6 trap still snares and springs.
