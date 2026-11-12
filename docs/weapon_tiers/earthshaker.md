# Earthshaker (`earthshaker`, Mythic, crush, fusion tier 3 of Quake Pick + Bulwark Maul, H = 6.43, inherits `t2/quakepick.gd`)

## Today
- Attack Heavy pick (cd 0.6): `swing(1.0)`, 0.18 s later `arc` r 30 (+-60 degrees), 1.0 H, knock 160, breaks rocks and trees 3 times. Triple Fissure (tier 2+, cd 8): three diverging lines (-0.35, 0, +0.35 rad), each of 5 ground strikes from 22 px every 18 px (r 18, delays 0.4 to 0.8 s, 3.0, knock 220, stun 0.5, breakables).
- Burrow (dash, cd 5): 70 px dash and a `ground_strike` 70 px ahead (r 26, 0.35 s, 3.5, stun 0.6), then 0.8 s of `shield_time` (arrive braced). Cataclysm (tier 3+): three rings of six strikes at 30/60/90 px (r 22, delays 0.3/0.65/1.0, 4.0, stun 0.5).
- Looks: brown rings. It is a ground weapon of long lines and rings.

Palette: bedrock `Color(0.55,0.40,0.25)`, crack glow `Color(1.0,0.60,0.20)`, dust `Color(0.88,0.76,0.55)`, deep `Color(0.20,0.12,0.08)`. Names: 3 Fault Lines, 4 Tremor, 5 Tectonic Shift, 6 World Shaker.

THE MYTHIC SYSTEM: **Fault Lines**. Every eruption of an ability or the dash leaves a fault point (a `slow` patch r 12, factor 0.7, 8 s, `Hazard`, harmless to players; at most 14 alive, oldest is freed first). Faults are visible as dark glowing cracks (the `Hazard` draws a dark disc; add `crack` fx once at creation). The Heavy pick's finisher and the ultimate trigger **Aftershock**: every fault erupts (`ground_strike` r 16, 0.25 s telegraph, 0.5 H = 3.2, knock 160) and is consumed. Enemies standing on a fault are also slowed by the patch.

## Tier table (fusion tier 3: rows 3 to 6)

| Tier | ART | ATTACK | ABILITY (Triple Fissure) | DASH (Burrow) | ULTIMATE (Cataclysm) | Twist (est.) |
|---|---|---|---|---|---|---|
| 3 Fault Lines (entry) | The pick head is stone with a glowing seam; the maul's face is the back; aura twinkle + glow ring; dust trail. | **Fault Lines**: every 3rd swing a stone spike erupts 40 px ahead (Quake Rock Spike) and leaves a fault; `shards` count 5. | **Branching + Fault Lines**: the lines fork (Quake Branching Fissure on strikes 2 and 4 of each line) and EVERY eruption leaves a fault. | **Fault Burrow**: leaves a fault trail of 3 along the path (the Quake Tunnel eruptions). | unlocked; `sigil` r 90 0.3 s; each strike leaves a fault. | thunder |
| 4 Tremor | 3 orbit dust motes, gem pixel. | **Tremor**: each swing sends a ground ripple forward: `crack` fx (count 3, length 40) and a `shock` r 14 at 30/48 px: two extra hits (0.4 H = 2.6) in a line. | **Tremor**: the 3 lines now pulse: 0.7 s after the last eruption a second wave runs back along each line (the strikes re-erupt in reverse order, 0.4 H = 2.6, `crack` fx), and enemies are pushed along the line direction. | **Tremor Burrow**: the dash is a `streak` (width 10, `deep`) and while burrowing you are braced; arrival `shock` r 40, 1.0 H, stun 0.8; **Aftershock** trigger: arriving erupts all faults within 60 px. | = | lifesteal |
| 5 Tectonic Shift | 5 motes, `crack` ghost trail. | = | = | = | **Stage 2 Tectonic Shift**: after the rings, the ground shifts: a `crack` ring (count 12, r 110) opens and for 2 s every enemy within 110 px is dragged toward you (`push` 180 every 0.4 s) with `crack` and `motes`, then an **Aftershock** (all faults erupt) and a second ring of 12 strikes at 110 px (0.5 H = 3.2, stun 0.4). | thunder |
| 6 World Shaker | Halo ring (stone ring with glowing cracks), 8 motes, tip star; the sprite has white-hot cracks. | **Finisher** every 6th swing: **Aftershock** (all faults erupt) + a forward `shock` r 50. | = | = | **FINALE + TRANSFORMATION World Shaker (8 s)**: the ground is yours: for 8 s every step (each 0.5 s) leaves a fault; every 1.0 s an automatic Aftershock erupts the faults in r 120 (they re-form: faults are not consumed in this mode, they are refreshed); the cursor spot gets a pillar: every 2.0 s a `pillar` (height 90 width 24) and a `ground_strike` r 34 at the cursor (0.5 s, 1.0 H = 6.4, stun 0.6); the screen shakes gently (`shake 2` each strike). At the end: a titanic quake: `sigil` r 100, then `flash` r 100, `shock` r 120 thick 10, `crack` count 16; all in r 120 take 2.0 H (12.9), knock 440, stun 1.2 (`WeaponUtil.stun`). Shake 7, `Sfx thump` + `ultimate`. | chain |

Caps (H = 6.43): attack avg +0.4 H (tremor 2 x 0.4 H = 0.8 on a target in line, per swing: only every other swing hits both: avg 0.4 H); ability +0.4 H return wave x up to 3 eruptions on a target = +1.2 H, plus faults 0.5 H each (>= 3 faults under a target = +1.5): +2.7 H vs today ~3.0 x 3 = 9.0 H (+30%); dash 1.0 H; ultimate: shift 12 x 0.5 H spread + aftershock ~2 faults x 0.5 H + World Shaker: Aftershock every 1.0 s x 8 = 8 x 0.5 H x faults... cap: each fault can erupt once per 2 s (so a target meets 4 x 0.5 H) + 4 cursor pillars x 1.0 H + finale 2.0 H = ~10 H: inside k = 40.

## What makes this feel like Mythic
A SYSTEM of terrain memory: your attacks write faults on the ground and later verbs read them, so a fight becomes a map of cracks. The ultimate is a transformation (you move and the earth erupts behind you). Compared with Epic Quake Pick (rings and lines that finish), the Earthshaker's lines come back and its faults detonate on cue.

## Rules for the implementer
- `items/weapons/tiers/earthshaker.gd` (`preload("quakepick.gd")` for Branching/Rock Spike/Tunnel helpers with Earthshaker constants).
- Faults: `_st.faults: Array` of `{pos, born}`; creation `WeaponUtil.patch(world, pos, "slow", 12.0, Color(0.30,0.20,0.10,0.6), 8.0, 0.7)` plus one `crack` fx; `aftershock(w, radius := INF)`: for each fault within radius: `ground_strike` r 16 0.25 s, then free the hazard (`queue_free` the stored `Hazard` ref; the module stores node refs: `_st.faults[i].node`). Cap 14: free the oldest node first.
- `earthshaker.gd` edits: `attack()` tremor (module `attack(w)` spawns the two `shock` hits at 30/48 px via `ground_strike` with `0.15 s` delay), `ability()` return wave at +0.7 s (re-erupt strikes in reverse order), `dash_attack()` (inherited from Quake Pick; Earthshaker calls super then `shield_time`): module `dash(w)` aftershock at the arrival; `ultimate()` unchanged: stage 2 at press + 1.3 s + 0.3 s, transformation at 3.2 s, finale at 11.2 s.
- Constants: `ES_FAULT_MAX := 14`, `ES_FAULT_SECS := 8.0`, `ES_FAULT_SLOW := 0.7`, `ES_AFTERSHOCK_MULT := 0.5`, `ES_TREMOR_MULT := 0.4`, `ES_RETURN_MULT := 0.4`, `ES_SHIFT_PULL := 180.0`, `ES_SHIFT_N := 12`, `ES_SHAKER_SECS := 8.0`, `ES_SHAKER_STEP := 0.5`, `ES_PILLAR_EVERY := 2.0`, `ES_PILLAR_MULT := 1.0`, `ES_FINALE_MULT := 2.0`, `ES_FINISHER_EVERY := 6`.
- Faults never hurt players (`slow` kind); they are `Hazard` (net).
- Multiplayer: nothing new beyond patches/fx. Performance: <= 14 hazards; finale ~30 fx.

## How to test (section `earthshaker`)
1. Entry: tier 3 fissure leaves `slow` hazards (count >= 10 right after) and a swing #3 spike leaves a fault.
2. Tremor: tier 4 swing: two extra hits on a dummy at 40 px; the ability's return wave hits a dummy at the line's start again 0.8 s later; arriving by burrow erupts faults within 60 px (their hazards vanish).
3. Tectonic Shift: tier 5 ultimate with dummies at 100 px: they are pulled toward the player >= 20 px during the shift window and an Aftershock erupts all faults (hazard count falls to ~0 then refills).
4. World Shaker: tier 6: for 8 s every ~0.5 s a new fault exists near the player; a `pillar` fx every ~2 s at the cursor; at ~11.5 s `flash` r 100 and a dummy at 100 px takes >= 12.9.
5. Faults never exceed 14 and never hurt the player (stand in one 3 s: health unchanged).
6. Draw smoke; Quake Pick unaffected.
