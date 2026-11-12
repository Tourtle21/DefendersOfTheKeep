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

## Fused weapons, mid rarity (implementer 2): chainfangs, rapier, bulwark, knightblade, lance, quakepick, rimelance, sultanguard, dragoonpike, bogstaff, magmamaul, spellblade, tempest
Shared helpers: `items/weapons/tiers/wt_kit.gd` (tether, pull/shove, execute, near_segment, nearest_n, settle). Tests: `tools/tests/weapon_tiers_fusions_a.gd` and `_b.gd` (`-- only=<id>`).
Where a design asked for something the old scripts cannot give a module, the old script got a one-line hook (`WeaponTiers.run(self, "<hook>", ...)`) or a small guarded edit.
- Chain Fangs: Dragnet waits for the Hunt to settle (`Kit.settle`) instead of computing the end from a target count.
- Rapier: new hooks `fleche` and `stab` (the Rapier overrides `use_ability`, so the generic `ability` hook never runs). Final Lunge starts 1.3 s after the press.
- Bulwark: Overpressure fires when the brace is FULL (`max_store`), so Juggernaut (8) would need 8; the finale hits at 4.0 s with the sigil telegraph from 3.6 s. A braced left click is a bash only when the module answers true (Juggernaut/Worldbreaker keep their maul).
- Knight's Blade: Knight's Vow keeps the old circular pulse damage (everything within 56 px, 6.0) and adds the arc's reach to 70 px, so the ultimate is never weaker than before; the design's "3.0 H per arc" would have been a nerf on one target. Vanguard Dash makes the next two strikes big through `_st.big_left`.
- Siege Lance: the vault "hop" is a scale pulse of the hand sprite plus a shadow ellipse in the aura (the hand rotates with the aim, so a vertical rise is not possible). Reverb rings come 0.4 s and 0.8 s after the crash (crash lands 0.4 s after the press).
- Quake Pick: as designed.
- Rimelance: Frostbite counts every tip hit (every Rimelance hit chills) and the freeze lands one frame after the thrust (the old thrust chills right after the hit and would undo it). Glacier shatters about 6.9 s after the press.
- Sultan's Guard: the Desert Shield bash sweeps the same side as the slash, 0.5 rad off (not behind you). At most two mirages are alive per player.
- Dragoon Pike: the Pike has its own Roar finisher (not the Lance's full-line one) and borrows `lance.gd` helpers. Dragon Descent comes after the Wyrm Chase and the return blink: sigil r 80 telegraph, then the blast and the eight lances.
- Magma Maul: the second crater of the molten double slam is a `slow` patch, not a new burn patch (burn patches hurt players). Kill heat counts only hits that kill (not poison/bleed ticks).
- Spellblade: the Spellblade's own blades are drawn by its WeaponAura from `aura.data` ({ph, n, r, sp, sph, av}); the old `_draw` still draws the storm blades for Starfall (it extends the same script) until Starfall's module uses `Spellblade.draw_blades(a, c)`.
- Tempest: the Thunderhead strikes a random enemy (and charges it) when nothing is charged, because the opening Storm clap spends every charge; Stormlord's mega-clap is 3.0 per charge (twice the normal clap), absolute damage like the old clap.
- Bog Staff: `WeaponUtil.rot_mult` is applied in `WeaponUtil.bleed` for element poison (the Witch Staff can reuse `rot_add`, `rot_stacks`, `rot_burst` of tiers/bogstaff.gd). Beasts rise from kills by a direct hit (not from poison-tick kills). With Miasma the stacks cycle through bursts, so the count on one enemy rarely stays at 5.

## Weapon art per tier (items/weapons/art/, WeaponArt)
- ONE art module: `items/weapons/art/weapon_tier_art.gd` (`WeaponTierArt.image(id, tier)` -> 32x32 Image, outlined, tip up, grip bottom centre). The pixel kit is
  `weapon_paint.gd` (px, rect, disc, ring, ellipse, line, poly, diamond, gem, column, outline). Pictures are drawn at run time and cached per id:tier in `WeaponArt.icon`.
- Base weapons live in `art/base_art.gd`, fused weapons in `art/fused_art.gd`. To give a weapon its own art add `func draw_<id>(p: Paint, t: int) -> void` to one of them;
  the dispatcher finds it by name. A weapon without that function falls back to the old glow overlay of `WeaponArt._compose`.
- FUSED weapons are drawn from scratch: `draw_<fused id>` gets an empty canvas and never receives or composes the parents' icons. Optional `func size_<id>() -> int`
  gives another canvas size. Tier 1 of a weapon stays its icon file (WeaponArt returns the PNG at tier 1); tiers 2+ use the drawings, with only a faint glow at 5 and 6.
- Everything that shows a weapon calls `WeaponArt.hud_icon(id, tier, path)`: the code-drawn weapon (`Weapon._attach_visual`), the HUD inventory slot, the split-screen /
  LAN slots (`weapon_slots.gd`), and the weapon cards (codex, Forge, draws, rewards: `WeaponCard.icon`).
- Contact sheet: `tools/make_weapon_tier_art.gd -- ids=a,b out=/path.png scale=6`. Test: `tools/tests/weapon_art.gd`.

## Ancient fusions (implementer 2): witchstaff, soulreaper, starfall
- Witch Staff: Hex adds `Game.HEXED_BONUS` (meta `hexed_until`, 1.2x) to `Game.mark_mult`. The hex jump and the Pox cloud run from a death watch in `tick` (positions kept every 0.1 s), so any death of a hexed enemy counts, not only a bolt kill. Rot here has no 5-stack burst (the Bog Staff's bursts stay with the Bog Staff); `WeaponUtil.rot_mult` still raises poison ticks. Witches and ravens are drawn by the aura from `data` {w, ph, q}.
- Soulreaper: kills are credited when the enemy died within 60 px of you, was touched by one of your hits in the last 0.8 s, or was exposed (quiet hits do not call `on_hit`). The Soul Tide arrives 3.5 s after the press (the old Reap runs about 3.5 s). The Grim Reaper transformation starts at 4.0 s and the harvest at 16.0 s, as designed.
- Starfall: the old Spellblade ultimate is not awaited by Starfall's `ultimate()`, so the old star rain starts AT the press, not 5 s later; the Meteor Rain replaces it from the press, and the Cosmic Dance starts at press + 5.5 s (after the 5 s Blade Dance blades; the design said 8.5 s) and ends with the Supernova at about 17.5 s. Starfall's blades are drawn by the aura through `tiers/spellblade.gd draw_blades`.
