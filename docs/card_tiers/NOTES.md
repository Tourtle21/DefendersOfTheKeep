# Implementer notes (deviations from the designs)

- charm, tier 5 Contagion: a charmed enemy infects a neighbour wherever it stands (the design limited carriers to 1.3 r of the spell, which made chains along a row impossible and contradicted its own test); the cap of 6 infections per cast still bounds it.
- charm, tiers 2+: the spell node now stays alive (tier 2 for 1 s) so the hearts can be drawn; only tier 3+ keeps charming.
- WeaponFx draw_flight is additive on top of the old plain shot (as in the conventions); the test file is `tools/tests/tier_abilities.gd` (one section per card, `-- only=<card id>` runs one), because `tools/tests/card_tiers.gd` already existed for another purpose.
- sandstorm/blizzard/lava/poison zones, aegis, flare ... all spell abilities follow the designs; the points below are the places where the code differs:
- spells that did not live past their landing (charm, mass conversion tier 2, meteor shower tier 2+, frostfire tier 4+, solar burst tier 5+) now live longer so their art and abilities can run: charm tier 2 1.0 s, mass conversion tier 2 1.5 s, meteor shower `duration + 3.0` (craters fade 2.5 s; the extinction meteor lands at duration + 2.0), frostfire tier 4+ 3.0 s.
- `Spell.draw_flight` / `SpellArt.draw_flight` is additive on the plain shot (as the conventions say); the old fireball tier rings stay.
- stasis tier 5 rewind and the war cry speed boost: `Enemy._charmed` caps the speed boost at 1.15x (`minf(charm_power, 1.15)`, as the charm design said), so the war cry's 25% faster is 15%.
- mass conversion: a `copy` cast still spreads its conversion (only the honour guards are skipped).
- poison cloud tier 6: the cloud stays up to 7 s past its end while plagued enemies are alive (`SpellTiers.keep_alive`), so the small clouds can be released.
- slow patches (`Hazard`) and the zone slows (`SpellTiers.keep_slow`) no longer overwrite a stronger stun already on an enemy (freezes, burials, stuns survive the steady chill).
- `Game.mark_mult(e)` is the single source for temporary damage marks (toxic 1.2, fractured 1.25, brittle 1.5); `Enemy.apply_traits` reads it.
- `WeaponUtil.ground_strike` has an optional `on_hit` callable (crystal spikes use it to expose); `WeaponProjectile` can chill (`slow_mult` / `slow_secs`).
- the balance test (`tools/tests/balance.gd`) was not re-run for the stasis tier 6 time break (15% of max health); watch it in playtests and lower `SpellTiers.STASIS_BREAK` to 0.10 if needed.
