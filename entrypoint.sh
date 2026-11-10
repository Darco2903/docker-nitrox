#!/usr/bin/env bash
# Standalone: docker run, docker compose and docker attach. The server manager uses its own
# entrypoint instead, with server.sh as the command.
set -euo pipefail

# First, with the terminal as stdin: steamcmd may ask for the password and Steam Guard code
/install-game.sh

# Nitrox's own SIGTERM handler lets .NET kill the process before it saves, so
# instead of exec'ing the server, feed its console through a FIFO and turn
# SIGTERM/SIGINT into a `stop` command, which saves before exiting.
console=/tmp/nitrox-console
rm -f "$console" && mkfifo "$console"
# Keep a writer open so the server never sees EOF on its stdin
exec 3<>"$console"

# Installed above: no second update
UPDATE_ON_START=false /server.sh "$@" <"$console" &
server_pid=$!

trap 'echo "Received stop signal, saving and stopping server..."; echo stop >&3' TERM INT

# Forward attached console input (docker attach) to the server. The explicit <&0
# is needed: bash otherwise gives background jobs /dev/null as stdin.
cat <&0 >&3 &

# `wait` returns early when a trapped signal arrives, so keep waiting until the server exits
status=0
while kill -0 "$server_pid" 2>/dev/null; do
    wait "$server_pid" && status=0 || status=$?
done
exit "$status"
