#!/bin/bash
# Start a local co-op test: one host window and N-1 clients on this machine.
#   ./mp_run.sh        2 players
#   ./mp_run.sh 4      4 players
# Set GODOT_BIN if Godot is not at the default path. On a real LAN, run the game normally,
# press P, "Host co-op game" on one computer and pick the game from the list on the others.
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
PLAYER_COUNT="${1:-2}"
COLUMNS=$((PLAYER_COUNT < 4 ? PLAYER_COUNT : 4))
ROWS=$(( (PLAYER_COUNT + COLUMNS - 1) / COLUMNS ))
WINDOW_WIDTH=$((1920 / COLUMNS))
WINDOW_HEIGHT=$((1000 / ROWS))

"$GODOT_BIN" --path "$PROJECT_DIR" --resolution "${WINDOW_WIDTH}x${WINDOW_HEIGHT}" --position 0,45 -- host name=Host &
for ((PEER_INDEX = 1; PEER_INDEX < PLAYER_COUNT; PEER_INDEX++)); do
    sleep 1.5
    COLUMN=$((PEER_INDEX % COLUMNS))
    ROW=$((PEER_INDEX / COLUMNS))
    "$GODOT_BIN" --path "$PROJECT_DIR" --resolution "${WINDOW_WIDTH}x${WINDOW_HEIGHT}" --position "$((COLUMN * WINDOW_WIDTH)),$((45 + ROW * WINDOW_HEIGHT))" -- join=127.0.0.1 "name=P$((PEER_INDEX + 1))" &
done
wait
