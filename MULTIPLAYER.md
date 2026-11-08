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
