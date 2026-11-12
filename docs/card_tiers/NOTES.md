# Implementer notes (deviations from the designs)

- charm, tier 5 Contagion: a charmed enemy infects a neighbour wherever it stands (the design limited carriers to 1.3 r of the spell, which made chains along a row impossible and contradicted its own test); the cap of 6 infections per cast still bounds it.
- charm, tiers 2+: the spell node now stays alive (tier 2 for 1 s) so the hearts can be drawn; only tier 3+ keeps charming.
- WeaponFx draw_flight is additive on top of the old plain shot (as in the conventions); the test file is `tools/tests/tier_abilities.gd` (one section per card, `-- only=<card id>` runs one), because `tools/tests/card_tiers.gd` already existed for another purpose.
