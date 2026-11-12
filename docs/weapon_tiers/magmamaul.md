# Magma Maul (`magmamaul`, Mythic, fire, light weapon (105), fusion tier 2 of Ember Flail + Hammer, H = 9.11, inherits `t1x/emberflail.gd`)

## Today
- Attack Heavy swing (cd 0.85): `swing(1.3)`, 0.22 s later a `ring` r 34 at 24 px ahead, 1.0 H, knock 280, stun 0.4, shake 2, breaks stones, and a `burn` patch r 20 for 4 s (hurts players). Magma Slam (tier 2+, cd 7): `ground_strike` at the cursor (range 100) r 44, 0.6 s, 8.0, knock 320, stun 0.8, then a burn crater r 44 for 6 s.
- Leap Burn (dash): 70 px leap, a `ground_strike` r 30 0.22 s 4.0 knock 240 stun 0.5 and a burn patch r 26 for 4 s. Magma Ring (tier 3+, inherited from the Flail): 12 strikes at 85 px (r 22, 4.5, burn patches r 20 6 s) and 6 inner strikes at 45 px.
- Looks: orange rings, burning patches; slow and heavy.

Palette: magma `Color(1.0,0.38,0.08)`, molten `Color(1.0,0.60,0.20)`, white-hot `Color(1.0,0.92,0.60)`, obsidian `Color(0.20,0.10,0.10)`. Names: 2 Cooling Crust, 3 Heat Surge, 4 Molten Core, 5 Meltdown, 6 Eruption Titan.

THE MYTHIC SYSTEM: **Heat**. A gauge 0 to 100 (public in the aura `state`, drawn as the head glowing from obsidian to white-hot and a ring of cracks). Heavy swing +12, Magma Slam +40, Leap Burn +25, kills +5. Heat decays 8 per second after 3 s without a gain. At 100 the weapon goes **Molten** for 6 s (heat drains to 0 over it): every swing is a slam (+ shockwave), the Slam becomes a double slam, and the head `flash`es. Molten can trigger once every 12 s.

## Tier table (fusion tier 2: rows 2 to 6)

| Tier | ART | ATTACK | ABILITY (Magma Slam) | DASH (Leap Burn) | ULTIMATE (Magma Ring) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Cooling Crust | The head is obsidian with glowing seams; seams brighten with heat (aura draws 4 seam lines whose alpha = heat/100); aura twinkle; embers drip (2 `motes`/0.5 s). Light +10. Heat starts: all gains and the decay as above (the gauge is visible only in the glow, no number). | Hits spawn `shards` count 4 (obsidian chips) and `burst` r 10. | **Cooling Crust**: the crater grows a crust ring: a `crack` fx (count 6, r 50) and the strike throws 6 lava `shards` (r 80) hitting enemies at the rim for 0.4 H (3.6, aoe, quiet). | - | locked | thunder |
| 3 Heat Surge | Tip glow; heat shimmers (the whole sprite `modulate` pulses toward white-hot at heat > 60). Light +20. | **Heat Surge**: every 3rd swing is a lava slap: `shock` r 40 (thick 7), +1.0 H, knock 320; and heat +12 extra. | = | = | unlocked; `sigil` r 90 count 12 0.3 s; the pulses of the ring also give you +30 heat each ring (max 100). | thunder |
| 4 Molten Core | 3 orbit embers, gem pixel (magma). Light +30. | **Molten**: at 100 heat the weapon goes MOLTEN (6 s): each swing is a full slam (hit circle r 44, `shock` r 44, 1.4 H), shake 3; the head `flash`es; the aura gives a ring of cracks. | **Molten Slam**: in molten state the slam is DOUBLE: a second strike 0.5 s after the first at +-40 px, same damage x0.7, and the crater doubles (two craters). | **Molten Leap**: the dash is a `streak` (width 10, `magma`), the landing `flash` r 40 and an immediate second leap-slam in molten state (r 30 again 0.3 s later). | = | lifesteal |
| 5 Meltdown | 5 embers, white-hot veins, ghost trail. Light +40. | = | = | = | **Stage 2 Meltdown**: the ring's 12 strikes each leave a lava geyser: 0.8 s after landing a `pillar` (height 70, width 16) and a second strike (r 22, 0.5 H = 4.6) fire at each; you gain heat to 100 at once and go molten (6 s) at the end of the ring: the ring's last pulse is a `flash` r 85. | chain |
| 6 Eruption Titan | Halo ring (lava ring), 8 motes, tip star; the whole sprite glows white-hot in molten state. Light +60. | **Finisher** (molten): every 5th molten swing: a `beam`-like fire stream: a forward `cone` r 70 half 0.6 (0.8 H) and 3 lava globs (`WeaponProjectile` style `orb`, 0.6 H, burst r 22). | = | = | **FINALE + TRANSFORMATION Eruption Titan (8 s)**: after Meltdown you become the volcano: for 8 s you are molten (heat locked at 100), every swing is a double slam, and every 1.0 s a lava bomb (`fall` radius 5 + `ground_strike` r 24, 0.4 s, 1.0 H = 9.1) lands on a random enemy within 110 px; at the end a great eruption: `sigil` r 90, then `flash` r 90, `pillar` height 160 width 40, `shock` r 100, `crack` count 12: all in r 90 take 2.0 H (18.2), knock 420, stun 1.2 (`WeaponUtil.stun`); light 190 for 5 s. Shake 7, `Sfx ultimate` + `thump`. | bleed |

Caps (H = 9.11): attack avg +0.5 H (slap 1.0 H per 3 swings = 0.33; molten swings 1.4 H vs 1.0 H for 6 s per 12 s cycle: +0.2 H average); ability crust shards 0.4 H + molten double 0.7 H = +1.1 H when molten; dash +0.8 H; ultimate stage 2 12 x 0.5 H spread (two geysers per target at most: 1.0 H) + 8 bombs (8 s: 8 x 1.0 H spread over targets, 2 on one: 2.0 H) + finale 2.0 H: +5 H vs today 4.5/9.11 x 12 x ... the ring's per target 1.0 H: well inside k = 40 H.
Burn patches hurt players: only the already existing ones (swing, crater, leap, ring) appear; every NEW ground piece is a fx or a `slow` patch.

## What makes this feel like Mythic
A SYSTEM with a rhythm: Heat builds, then you become Molten and every verb doubles. The weapon is the loudest of the band (glowing white-hot, double slams) but you control when. Compared with Epic Ember Flail (ground fire, caldera, volcano), the Maul's escalation is internal state (heat) rather than ground fields: it makes the PLAYER the effect.

## Rules for the implementer
- `items/weapons/tiers/magmamaul.gd`; `magmamaul.gd` edits: `attack()` heat gain and molten branches (hit circle radius and mult read from `_st.molten`), `ability()` second strike when molten, `dash_attack()` second leap, `ultimate()` inherited from the Flail (the module's `ultimate(w)` schedules stage 2 at +0.74 s... the Flail's ring runs ~0.8 s: Meltdown geysers at press + 1.6 s each; the transformation starts at 2.4 s and lasts 8 s; the eruption at 10.4 s).
- Heat is `_st.heat` (float); published to the aura `state = int(heat)` each tick; `_st.molten_until`, `_st.molten_cd_until`. A kill adds +5 through `on_hit` (check `dmg >= e.health`: a simple heuristic `e.health <= 0` after the hit).
- Constants: `MM_HEAT_SWING := 12`, `MM_HEAT_SLAM := 40`, `MM_HEAT_LEAP := 25`, `MM_HEAT_KILL := 5`, `MM_DECAY := 8.0`, `MM_DECAY_DELAY := 3.0`, `MM_MOLTEN_SECS := 6.0`, `MM_MOLTEN_CD := 12.0`, `MM_SLAP_EVERY := 3`, `MM_MOLTEN_MULT := 1.4`, `MM_GEYSER_MULT := 0.5`, `MM_BOMB_EVERY := 1.0`, `MM_TITAN_SECS := 8.0`, `MM_FINALE_MULT := 2.0`, `MM_FINISHER_EVERY := 5`, `MM_LIGHT_BONUS := [0, 10, 20, 30, 40, 60]`.
- The hammer-based sibling Earthshaker is not related to this file.
- Multiplayer: heat as aura `state`; molten flag `state >= 100` plus `kind "molten"`. Light radius changes: re-attach `GlowLight` as in torch.md.
- Performance: Titan peak ~35 fx; bombs 1 per second.

## How to test (section `magmamaul`)
1. Heat: tier 2, three swings raise the aura `state` by >= 30; it decays after 3 s idle (poll `_st.heat`).
2. Heat Surge: tier 3, the 3rd swing has kind `shock` and hits a dummy at 38 px; a lower swing does not.
3. Molten: tier 4: after reaching 100 heat (set `_st.heat = 100` directly, as the tests do) the next swing hits a dummy at 42 px (r 44) with 1.4 H; the molten state ends after 6 s; the slam makes a second strike 0.5 s later.
4. Meltdown: tier 5 ultimate: >= 12 `pillar` kinds within 3.5 s; after the ring the weapon is molten.
5. Eruption Titan: tier 6: 8 s of bombs (>= 6 `fall` kinds) and at ~10.5 s a `flash` r 90 with the centre dummy taking >= 18.
6. Draw smoke; no new `burn` hazards beyond the old ones (count hazards of kind `burn` after a tier 6 ultimate <= the number the old code makes).
