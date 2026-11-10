#!/usr/bin/env bash
# Installs the game if needed, then runs the Nitrox server in the foreground: console commands on
# stdin, output on stdout. The command of the server manager's entrypoint, which owns the console.
set -euo pipefail

/install-game.sh

export SUBNAUTICA_INSTALLATION_PATH="${GAME_DIR:-/data/subnautica}"
exec dotnet /opt/nitrox/Nitrox.Server.Subnautica.dll "$@"
