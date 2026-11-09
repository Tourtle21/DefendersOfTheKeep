# Multiplayer (LAN co-op)

Host-authoritative over ENet, LAN first. One player hosts, up to three join.

## Play it

- Same computer, several windows: `./mp_run.sh 3` (host + 2 clients).
- Real LAN: on one computer press **P**, **Host co-op game** (it shows the address friends can use).
  On the others press **P**: games on the network are listed automatically, click to join (or type the
  host's address). Command line: `-- host name=Alex` and `-- join=192.168.0.54 name=Sam`.
- Ports: 24680 (UDP, game) and 24681 (UDP, discovery).

## How it works

The host runs the whole game. Clients send input (move, aim, buttons) and commands (enter the keep, cast a
card, repair, fuse...). Clients do not simulate anything: they show what the host sends.

- `core/net.gd` connection, lobby, input, commands, the small per-player snapshot (position, hp, weapons,
  carried items, cooldowns), LAN discovery.
- `core/replication.gd` (autoload `Rep`) replicates everything else **automatically**:
  - nodes in the group `net` are spawned on clients as puppets (real scene or script, logic switched off),
    synced and smoothed, and freed when the host frees them,
  - one-shot effects (`WeaponFx.spawn`, `DamageNumber.spawn`, `Sfx.play`, `Game.announce`) are mirrored,
  - every public variable of the `Game` autoload is synced (exclusions: `Game.NET_SKIP`).
- `net/client_view.gd` the client's screen: puppets, the keep UI, the Forge, the cooldown HUD.

## THE RULES FOR NEW CONTENT (so it works in multiplayer without extra code)

1. **Gameplay node** (enemy, structure, projectile, pickup, scenery with state...): `add_to_group("net")` in `_ready`.
   Nothing else is needed.
2. **State**: every PUBLIC variable (no leading underscore) is synced, only when it changes. Make a variable
   host-only by naming it `_like_this` or listing it in `const NET_SKIP := ["name"]`.
   Dictionaries/arrays are fine as long as they hold no Objects (nodes, resources).
3. **Visuals** must be derivable from the synced variables. A puppet does not run `_process` /
   `_physics_process` / input. Animation clocks named `age` or `_age` tick locally on puppets; for anything
   else write `func net_tick(delta)`. `_draw` is re-run every frame on puppets.
4. **`_ready` side effects** that must not run on clients (like freeing the oldest structure): guard with
   `if !Rep.is_puppet(self)`.
5. **Effects and sounds** go through `WeaponFx.spawn`, `DamageNumber.spawn`, `Sfx.play` (mirrored for you).
   A new one-shot kind: call `Rep.event("my_kind", [args])` on the host and handle it in `Rep._handle_event`.
6. **Game state** (the `Game` autoload): just add a public variable. Keep host-only things in `Game.NET_SKIP`.
7. **Player actions that change the world** (a new keep button, a new interaction): add a command in
   `Net.net_command` that calls the same `Game` function the single-player UI calls. Clients never change
   state themselves.
8. **Node types that are purely local** (UI, camera, a one-shot effect that is mirrored as an event):
   `add_to_group("net_local")`.

`tools/tests/net_coverage.gd` fails when a gameplay node in a fully populated world is neither replicated
nor `net_local`, so forgetting rule 1 is caught. `tools/tests/rep_host.gd` + `rep_client.gd` prove replication
end to end (including a throw-away new content type, `tools/tests/fixtures/new_thing.gd`).

## Known limits

- The client's own avatar is simulated by the host from its input (fine on a LAN; no client-side prediction).
- Per-player progress (Shards, unlocks) belongs to the host only, by design: clients play with the host's unlocks and skills and earn nothing of their own.
- Player avatars are simple markers with a name and weapon, not the full player scene.

Night: `Game.night_level` is synced like every Game variable; the client view draws the same dark overlay and a light on your own
player. Lights (torch, flare, glowing buildings) replicate as normal gameplay nodes; the shroud and what defences see is host-side.

## Forge storage: LAN clients and split screen share ONE set of rules (keep them in sync)

Weapons can be dropped into the forge (shared by the whole team) and fused or combined together with the ones you hold.
LAN clients and local split-screen players must behave **exactly the same**, so both go through the same code:

- **Rules (host side, `core/net.gd`)**: `Net.forge_toggle_store(pl, src, idx)` drops a held weapon into the forge or takes a
  stored one out; `Net.forge_craft(pl, a_src, a_idx, b_src, b_idx)` fuses or combines any two (held `"held"` / stored `"store"`);
  `Net.forge_remove_held` keeps a sensible weapon equipped. The costs and tier locks come from `Game.forge_preview(ea, eb)`.
- **Layout (client side, `ui/forge/forge_layout.gd`)**: the list of held + stored weapons grouped by type (common first) and the
  preview text. Used by `ui/base/local_forge_ui.gd` (split screen, controller) and `net/client_view.gd` (LAN, mouse).
- **LAN wiring**: the client sends the commands `forge_store` and `forge_craft`; the stored weapons reach clients in the snapshot
  key `store` (a slow key). **Send a copy** (`Game._forge_store.duplicate()`): the slow part is only resent when it differs from
  the last one, and the same array edited in place never looks different.
- **State**: `Game._forge_store` is host-only (leading underscore), cleared at the start of every run, at most `FORGE_STORE_MAX`.
- **If you change the forge** (new action, new rule): change `Net.forge_*` / `Game.forge_preview` once, then check both the split-screen
  screen and the LAN client screen. The player-1 forge (`ui/forge/forge_ui.gd`) has the same features but works on the HUD slots.
- Test: `tools/tests/net_forge_host.gd` + `net_forge_client.gd` (LAN), and the split-screen forge checks listed in the README.

## Local split screen (2 to 4 players)

- Start from the main menu: **Local co-op**. The connect screen (`ui/base/local_lobby.gd`) assigns controllers to slots: A joins,
  B leaves, Enter joins the keyboard (always player 1, it owns the mouse), Start begins. `Game._local_devices` = slot -> controller id.
- `world/split_screen.gd`: one `SubViewport` per player sharing the world (`world_2d`), each with its own camera; the layout follows the
  window. Player 1's HUD layers are pointed at player 1's view with `CanvasLayer.custom_viewport`; controls anchored to the window's edges
  are re-pinned to the view's size (`_pin_all`).
- `world/local_players.gd`: players 2 to 4 are co-op **avatars** (the same kind a LAN client gets), driven by their controller through
  `Net.apply_input_state`. So everything that works for a LAN client works for them.
- Their screens: `ui/base/local_keep_ui.gd` (hand, mana, cursor, cast, merge, repair, upgrades, chest draft) and
  `ui/base/local_forge_ui.gd`. `core/pad.gd` keeps controller 0 (or the keyboard) for player 1 only while split (`Pad.enter_split`).
- Only one player can be in a tower at a time (`Game.tower_taken`), for walking in, LAN, split screen and the tower jump.
- Difficulty: `Game.team_scale(per)` counts every player (LAN and split screen). Waves use 0.75, bosses 0.8, shared mana regen 0.35.
- Menus (pause, rewards, drafts) go through player 1; any controller can also drive them.

## Controller
`core/pad.gd` (autoload `Pad`). Outside: sticks move and aim, RT attack, LT ability, A interact, B dash, X switch weapon, Y ultimate,
Start pause. In a tower: A leaves, the right stick moves a cursor, LB / RB pick a card, RT places it (or jumps to a lit tower), LT / B
put it back. Menus: d-pad + A / B, LB / RB switch tabs (`ui/cards/menu_pad.gd`; only the top-most menu reacts).
Gameplay code asks `Pad.world_mouse(self)` instead of `get_global_mouse_position()` and `Pad.view_transform(vp)` instead of
`vp.get_canvas_transform()`, so a co-op client (and a split-screen view) gets the stick-aimed point like any other aim.

## Card Fuser
The Card Fuser (`Net.CARD_FUSER_POS`, across the keep from the Forge) fuses two cards of the shared hand. The rules are `Game.fuse_preview` / `Game.fuse_hand`; clients send `card_fuse {a, b}` (hand positions) and the host checks they stand within 50 px. The snapshot carries `near_fuser` per player and `fuser` (slow key); the client screen is `fuser_box` in `net/client_view.gd`. Local split-screen players 2-4 open their own screen with d-pad up (`ui/base/local_fuser_ui.gd`, same rules through `Net.card_fuse`).

## HUD parity
The LAN client's HUD (`net/client_view.gd`), player 1's and the split-screen players' (`ui/base/local_hud.gd`, `ui/base/local_keep_ui.gd`) share one layout: the resource line top-left, the keep bar top-centre, the health bar top-right, the weapon slots bottom-left (`ui/hud/weapon_slots.gd`), the ability panel bottom-right, and Repair / upgrade cards in the keep. Change one, change the others.
