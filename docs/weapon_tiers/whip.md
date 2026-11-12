# Whip (`whip`, Rare, no element, H = 4.2)

## Today
- Attack Crack: `swing(0.45)`, `arc` r 46 (+-20 degrees, a narrow long arc), 1.0 H, knock 90. A hit at 34 px or more is the crack: x2.5, slow 0.5 for 0.8 s, gold `ring` r 10. An exposed target takes x2 (and loses the mark).
- Hook (tier 2, cd 6): the nearest enemy in a 110 px line is hit (1.0), yanked to you (push 330, 0.3 s), stunned 1.2 s and exposed 1.5 s; enemies within 46 px of it are also pulled (220) and slowed 0.2 for 0.8 s; a miss costs only 0.4 s. Whip Swing (cd 4): 60 px dash, hits 1.5, knock 100. Tempest Lash (tier 3): 4 pulses of r 66 every 0.28 s, 3.0 each, knock 210, stun 0.6.
- Looks: thin brown arc, gold ring, a line for the hook.

Palette: leather `Color(0.63,0.32,0.18)`, tip gold `Color(0.88,0.69,0.25)`, crack white `Color(1.0,0.97,0.90)`, copper `Color(0.80,0.50,0.30)`. Names: 2 Barbed Hook, 3 Double Crack, 4 Grapple Swing, 5 Cyclone Lash, 6 Thunder Crack.

## Tier table

| Tier | ART | ATTACK | ABILITY (Hook) | DASH (Whip Swing) | ULTIMATE (Tempest Lash) | Twist (est.) |
|---|---|---|---|---|---|---|
| 2 Barbed Hook | Aura twinkle on the tip; a visible rope: the aura draws a thin wavy line from the hand to the tip (a curve that sways with `swing`). | Cracks throw a white `burst` r 10 at the tip | **Barbed Hook**: the whole pulled pack is exposed 1.5 s (not only the target) and the hook's `streak` rope stays 0.3 s; the target also bleeds 4 ticks of 0.15 H. | - | locked | chill |
| 3 Double Crack | Tip glow (gold); the arc leaves a faint white after-curve. | **Double Crack**: every 3rd swing cracks twice: the second arc (0.12 s later) reaches r 58, the crack zone starts at 44, `slash` thin (thick 3) + `flash` r 12 at the tip; each crack in the pair hits with the usual tip rule. | = | = | unlocked; a `sigil` r 66 for 0.25 s. | chill |
| 4 Grapple Swing | 2 orbit motes (gold), gem pixel. | = | **Echo Hook**: 0.4 s after the pull a second snap collapses the pack: a `ripple` r 30 at the hook's end point hits all within 30 px for 0.8 H (3.4). | **Grapple Swing**: if an enemy is in the dash line within 90 px the dash grapples to it (you fly to 14 px before it; travel 0.14 s) instead of 60 px; the lashed enemies (pass-through) are slowed 0.5 for 1.5 s; `streak` rope drawn to the target; `Sfx whoosh` x2. | = | chain |
| 5 Cyclone Lash | 4 motes, rope ghost trail. | = | = | = | **Stage 2 Implosion**: 0.3 s after pulse 4 every enemy within 90 px is yanked to you (`push` toward, 260, 0.3 s), takes 1.0 H (4.2), exposed 2 s; a `vortex` fx (inward, r 90, count 4, life 0.5). | chain |
| 6 Thunder Crack | Halo ring, 6 motes, tip star. | **Finisher** every 6th crack: reach r 70, x1.5 on the crack, slows 0.3 for 1.0 s, white `cut` fx at the tip. | = | = | **FINALE Thunder Crack**: after the implosion 3 `bolt`s (length 80, from above at random angles) and a `flash` r 50 land on the pack's centre; `ground_strike` r 44 (0.35 s, 1.5 H = 6.3, stun 0.8); exposed enemies take x1.3. Shake 5.5, `Sfx big_hit` + `ultimate`. | lifesteal |

Caps (H = 4.2): attack avg +0.3 H; ability 4 x 0.15 H bleed + echo 0.8 H = +1.4 H (today 1.0 H + control: this is the Rare cap); dash +0 (control); ultimate: implosion 1.0 H + finale 1.5 H vs today 4 x 3.0 = 12.0 (2.9 H) = +87%.

## What makes this feel like Rare
It rewards a sequence: line up a hook, pull the pack, crack the exposed ones. Compared with Spear (Common), where each verb stands alone, the Whip's verbs feed each other and the ultimate has a setup (lashes) and a payoff (implosion then thunder). Visually it adds ropes, snaps and bolts but never fills the screen.

## Rules for the implementer
- `items/weapons/tiers/whip.gd`; `whip.gd` edits: `attack()` reach and zone from `_st.double` (use `pre_attack`: sets `_st.double = (swing_count % 3 == 0)`; the module `attack(w)` then schedules the second crack at 0.12 s calling the shared code path `_crack(reach, zone)` factored out of `attack()`), `ability()`: after the pull add bleed/expose to all pulled and the echo (timer 0.4 s), `dash_attack()`: grapple branch (target found by `enemies_in_line(o, aim, 90, 12)` nearest), `ultimate()`: unchanged; the module schedules the implosion at press + 4 x 0.28 + 0.3 = 1.42 s and the finale at +0.6 s.
- Constants: `WHIP_DOUBLE_EVERY := 3`, `WHIP_DOUBLE_R := 58.0`, `WHIP_ECHO_T := 0.4`, `WHIP_ECHO_MULT := 0.8`, `WHIP_GRAPPLE_RANGE := 90.0`, `WHIP_IMPLODE_R := 90.0`, `WHIP_IMPLODE_MULT := 1.0`, `WHIP_FINALE_MULT := 1.5`, `WHIP_FINISHER_EVERY := 6`.
- Exposure doubles the next whip crack (existing) so the Implosion deliberately sets up the finale; bosses are not pulled (`push` weak) and not stunned (`WeaponUtil.stun`).
- Tempest Lash (the fusion `tempest`) shares NAME only, not code: Whip's ult is `Weapon.pulse_around`.
- Multiplayer: the rope is drawn by the aura from `aim`, `tier` and `swing` only (no host data); everything else is fx/net nodes.
- Performance: finale about 12 fx; implosion pushes up to 20 enemies (cap the loop at 24).

## How to test (section `whip`)
1. Barbed Hook: tier 2 hook with a pack of 3 dummies within 46 px: all three exposed (`is_exposed`) and the target bleeds (health falls for >= 1 s); tier 1: only the target exposed.
2. Double Crack: tier 3, 3 swings; a dummy at 56 px is hit only by the second arc of the 3rd swing; kind `slash` seen.
3. Echo / Grapple: tier 4: a dummy at the hook end takes an extra hit at 0.4 s (>= 0.8 H); a dash with a dummy at 80 px ends within 20 px of it; tier 3 does neither.
4. Implosion: tier 5: dummies at 80 px are pulled to < 40 px of the player at 1.5 s and take 1.0 H; tier 4 stay.
5. Thunder Crack: tier 6: 3 `bolt` kinds seen, the pack centre dummy is stunned and takes >= 1.5 H extra; tier 5 not.
6. Draw smoke tiers 1-6 (rope appears from tier 2: aura exists).
