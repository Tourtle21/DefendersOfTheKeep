# Weapon tiers: implementation notes (deviations from the designs, and how things were built)

## Sword and Pickaxe use the one shared weapon path (no Tool facade)
The design (_SCALING.md 5.2) asked for a facade on `items/item.gd`. That was dropped: `Tool` (items/item.gd) now `extends Weapon`.
- It gets everything every weapon gets from `items/weapons/weapon.gd`: cooldowns and their Forge / skill scaling, `Game.weapon_power` as `WeaponUtil.power`,
  twist, `_claim()` (which sets `WeaponUtil.owner`), `use_ability` / `use_dash` / `use_ultimate` (unlock check, cooldown, sound, shake, the `pre_<verb>` and
  `<verb>` tier hooks), `cd_info`, the aura (`WeaponAura.attach`), `tick`, `verb()`, `fx()`, `pulse_around`, `ground_strike`, `cursor_target`.
- The sword and pickaxe verbs are now ordinary `ability()`, `dash_attack()` and `ultimate()` overrides that call `WeaponUtil.hit`, `WeaponFx` (via `fx()`),
  `pulse_around` and `WeaponUtil.ground_strike`, exactly like the code-drawn weapons.
- The only differences are the two things that really differ, each a small virtual in the base class: `_attach_visual()` (the Tool's scene is the picture, no code
  sprite; `WeaponArt` icons are for the HUD/codex only) and `_follow()` / `_orient()` (the hand's animation keeps the position and rotation). The basic attack is still the
  animation's Hitbox (`Enemy.take_damage`, a fixed `SWORD_HIT`); `Tool.use_item()` runs the same `pre_attack` / `attack` hooks without a cooldown.
- The tier modules for them (`items/weapons/tiers/sword.gd`, `pickaxe.gd`) use the same contract as every other module. Two Sword-only hooks (`whirl_scale`, `whirl_pulse`)
  are called from `Tool.ability()` through `WeaponTiers.run`, nothing else is special. The Pickaxe's strike centre is `w.cursor_target(80)` taken in `pre_ability`.
- Nothing special is needed by the other implementers: write the module the same way for every weapon.

## Module contract (as built)
- Entry points of a module never `await` (a coroutine called through `callv` is an error): a verb that waits starts a helper coroutine by a direct call
  (`_foo(w)`); `WeaponTiers.pause(w, secs)` waits and re-claims the shared `WeaponUtil` statics, returning false if the weapon is gone.
- Extra hooks used so far: `pre_attack`, `pre_ability`, `release` (hold abilities), `release_item` (the Bow), `finale` (the Bow's Arrow Storm), `rain_point` (Spear Rain).
- `WeaponUtil.hit(..., aoe, quiet)`: `quiet` skips twist, tier hook and hit-stop. `WeaponUtil.rain(..., each)`: an optional callable per strike point.
- Tests: `tools/tests/wt_base.gd` is the shared base (daylight, keep towers removed so they do not shoot the dummies, pad-cursor aiming because a headless mouse cannot be warped);
  `weapon_tiers_tools.gd` (Sword, Pickaxe), `weapon_tiers_basic.gd` (the base weapons, `-- only=<id>`).

## Deviations
- Torch: the Sunburst light bonus is applied inside `torch.gd` (`150 + [0,0,20,20,20,40][tier-1]`) instead of a second `LightSource`; the light radius bonus per tier is applied by re-scaling the weapon's `GlowLight`.
- Spear / Bow / Hammer / Whip / Scimitar / Daggers: where a design says to edit the old script, the edit is guarded by `weapon_id` (fused weapons that extend the base script keep their old behaviour unless their own module changes it).
- Whip test: dummies in the tests do not move (physics off), so a pull is not measured as movement; the Implosion is checked by its damage and `vortex` fx instead.
