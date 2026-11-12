# Soulreaper (`soulreaper`, Ancient, no element, fusion tier 3 of Chain Fangs + Spellblade, H = 3.60, inherits `t2/chainfangs.gd`)

## Today
- Attack: Chain Fangs' 2-hit chain slash (cd 0.3, melee share 2/3: `arc` r 36, +-40 degrees, 0.67 H; the 2nd hit of a pair reels the target in (170 px/s); an exposed target is a backstab x3) PLUS a piercing wave (`WeaponProjectile` speed 250, `H / 3`, life 0.5, pierce 2, knock 80, violet) every attack. Grapple (tier 2+, cd 6): fly to the nearest enemy in a 130 px line (hit 1.0, expose 2 s) and then, 0.2 s later, everything within 55 px of you is exposed for 4 s (violet rings).
- Chain Sweep (dash): 40 px, hits 1.5, slows 0.4 for 1 s. Reap (tier 3+): ring r 170 (0.6 s) hitting everything for 5.0, stun 0.8, exposed 5 s, 8 bleed ticks; then 8 ground strikes at 100 px (r 26, 5.0) and a `rain` r 150 of 16 strikes over 2.6 s (4.5 each).
- Looks: violet rings and waves.

Palette: soul violet `Color(0.70,0.45,1.0)`, ghost `Color(0.80,0.95,1.0)`, scythe steel `Color(0.80,0.85,1.0)`, void `Color(0.15,0.08,0.25)`. Names: 3 Soul Harvest, 4 Reaping Hook, 5 Soul Tide, 6 Grim Reaper.

THE ANCIENT SYSTEM: **Souls**. An enemy that dies within 60 px of you or from one of your hits releases a SOUL (a wisp that flies to you; aura `kind "souls"`, `n_souls` public, max by tier). Souls orbit you (r 14, ghost-white wisps with a trail) and are SPENT: by the attack (each swing with 3+ souls spends one to fire a homing wisp 0.6 H), by Grapple (spends 3: tier 4), by Reap (all). They are the Soulreaper's currency: killing makes the weapon louder. Death tracking uses a watch list in `tick` (`_st.watch` of enemy refs and last positions within 90 px).

## Tier table (fusion tier 3: rows 3 to 6; the entry row carries the Fangs and Spellblade riders of tiers 2 and 3)

| Tier | ART | ATTACK | ABILITY (Grapple) | DASH (Chain Sweep) | ULTIMATE (Reap) | Twist (est.) |
|---|---|---|---|---|---|---|
| 3 Soul Harvest (entry) | The scythe-blade has a ghost-flame edge and a chain of spirit links; aura twinkle + glow ring; wisps drift off a kill. Entry: Fangs' Barbed Chain (exposure 3 s, bleeds) and Spellblade's Spirit Blades are NOT inherited; Souls replace them. Soul cap 4. | **Soul Harvest**: souls (cap 4); the wave is style `crescent` size 1.0, trail 3; kills pop `motes` (violet, count 6) that fly to you. | **Harvest Grapple**: the grapple's tether stays 1.5 s; the pack exposed (4 s) is also bleeding (3 ticks of 0.15 H) and each exposed enemy that dies drops a soul. | = | unlocked; `sigil` r 100 (violet) with 6 skull-less runes 0.3 s; Reap's kills drop souls. | bleed |
| 4 Reaping Hook | 3 orbit souls, gem pixel (violet). Cap 6. | **Soul Bolt**: with 3+ souls each swing spends one: a homing wisp (`WeaponProjectile` style `orb`, size 0.9, `homing` 2.0, 0.6 H = 2.2, `chain 1`, speed 220, life 1.0). | **Reaping Hook**: the grapple spends 3 souls (if available) to chain through 3 more enemies within 60 px of each (each 0.8 H = 2.9, exposes 4 s, a `bolt` fx between); each jump pulls them 60 px toward the chain's end. | **Spectral Chains**: the sweep is a `streak` (width 7) and leaves chains: for 1.5 s enemies within 30 px of the path are rooted (slow 0.2) and take 0.4 H. | = | lifesteal |
| 5 Soul Tide | 5 orbit souls, ghost trail. Cap 8. | = | = | = | **Stage 2 Soul Tide**: after the rain, every soul you hold flies out as a homing wisp (0.8 H = 2.9 each, `homing` 3.0, pierce 1, up to 8) in a ring (`ripple` r 100 rings 2 first); you also summon 2 Ghost Reapers (aura `kind "reapers"`, 2 spectral figures at r 50, 6 s) that each sweep a 120-degree arc every 1.0 s (0.6 H = 2.2 quiet, `slash` fx); every kill in this window adds a soul back. | thunder |
| 6 Grim Reaper | Halo ring (a ring of 8 souls), 12 wisps, tip star; hooded phantom behind you (aura). Cap 12. | **Finisher** every 6th swing: a Reaping cut: `cut` r 22 + `slash` r 50: 1.0 H and enemies below 20% health are executed (non-boss) and drop 2 souls. | = | = | **FINALE + TRANSFORMATION Grim Reaper (12 s)**: you become Death: for 12 s the Ghost Reapers (2) stay, a giant spectral scythe (aura `kind "scythe"`, r 90) sweeps a full circle around you every 1.5 s (1.0 H = 3.6, quiet, aoe, a `slash` r 90 fx), enemies below 25% health are executed (non-boss: instant kill, a soul each), and EVERY exposed enemy within 140 px is feared: it slows to 0.5. When it ends: Reap Harvest: all souls you hold detonate in a final `flash` r 85 + `ripple` r 170 rings 4 + `pillar` height 150: everything in 170 px takes 0.2 H x souls (min 1.0 H = 3.6, max 12 souls: 8.6) and is stunned 0.8 s. Shake 8, `Sfx ultimate` + `boss_roar` quiet. | chain |

Caps (H = 3.60): attack soul wisps 0.6 H per swing (with souls) = +0.6 H avg when stocked (cap +40%: the wisp deals 0.5 H: tune `SR_BOLT_MULT := 0.5`); ability hook 3 x 0.8 H extra = +2.4 H; dash 0.4 H; ultimate: tide 8 x 0.8 H + reapers 6 x 0.6 H x 2 + scythe 8 x 1.0 H + finale 8.6 H on a central target about 35 H vs today 5.0 + 5.0 + 4.5 x 3 = ~24 H (+45%): inside Ancient k = 52 H. Execute only on non-boss enemies below 20/25% health (low-health thresholds are small to avoid trivialising packs).

## What makes this feel like Ancient
Two parents combined: the chains of the Fangs become the soul link and the blade-orbit of the Spellblade becomes the wisps, spirit reapers and a spectral scythe. A currency (souls) ties every verb together and the finale spends it all. Compared with Mythic Spellblade (spirit blades orbit you and attack), the souls are earned by killing, spent for effect, and the transformation includes executions and fear.

## Rules for the implementer
- `items/weapons/tiers/soulreaper.gd` (`preload("chainfangs.gd")` for chain/yank/jump helpers; the Fangs' Execution finisher is replaced by the Soulreaper's own rows).
- `soulreaper.gd` edits: `attack()` wisp, soul counting through `tick` and `on_hit` (record the hit enemy; when it becomes invalid within 0.6 s the kill is credited), `ability()` hook chain via the module (`ability(w)` after the old, using `_st.souls`), `dash_attack()` roots, `ultimate()` inherited: stage 2 at press + 0.6 + 0.3 + 2.6 s = ~3.5 s, the transformation at 4.0 s, the finale at 16.0 s.
- Public aura vars: `n_souls: int`, `phase: float`, `reapers: int`, `scythe_r: float` (0 when off, else 90); host sets in `tick`.
- Constants: `SR_SOUL_CAP := [0, 0, 4, 6, 8, 12]`, `SR_BOLT_COST := 1`, `SR_BOLT_MULT := 0.5`, `SR_HOOK_COST := 3`, `SR_HOOK_JUMPS := 3`, `SR_HOOK_MULT := 0.8`, `SR_TIDE_MULT := 0.8`, `SR_REAPERS := 2`, `SR_REAPER_SECS := 6.0`, `SR_REAPER_MULT := 0.6`, `SR_EXECUTE := 0.20`, `SR_EXECUTE_ULT := 0.25`, `SR_REAP_SECS := 12.0`, `SR_SCYTHE_EVERY := 1.5`, `SR_SCYTHE_R := 90.0`, `SR_SCYTHE_MULT := 1.0`, `SR_FINALE_PER_SOUL := 0.2`, `SR_FINISHER_EVERY := 6`.
- Execute: `!e.is_in_group("boss") and e.health <= e.max_health * frac` then lethal damage; credit a soul.
- Multiplayer: souls, reapers and scythe through aura vars; wisps are net projectiles (cap 12). Performance: transformation ~25 fx/s, <= 20 projectiles.

## How to test (section `soulreaper`)
1. Entry: tier 3: kill a dummy (hp 1) in melee: aura `n_souls == 1`; cap 4 at tier 3 (give 6 kills: 4).
2. Soul Bolt: tier 4 with 3 souls: a swing spawns a homing projectile (style `orb`) and the count drops by 1; the hook with 3 souls hits 3 extra dummies.
3. Soul Tide: tier 5 ultimate with 5 souls: >= 5 wisps at ~3.5 s and aura `reapers == 2` for ~6 s; tier 4 none.
4. Grim Reaper: tier 6: `scythe_r == 90` for ~12 s with a `slash` r 90 fx every ~1.5 s; a dummy at 20% health is executed (a boss stand-in is not).
5. Reap Harvest: at ~16 s `flash` r 85; a dummy at 120 px takes >= 3.6 and is stunned.
6. Draw smoke; Chain Fangs unaffected.
