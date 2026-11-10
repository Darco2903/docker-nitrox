#!/usr/bin/env bash
# Downloads Subnautica into GAME_DIR when it is missing, or updates it with UPDATE_ON_START=true
set -euo pipefail

GAME_DIR="${GAME_DIR:-/data/subnautica}"

if [[ ! -f "$GAME_DIR/Subnautica_Data/Managed/Assembly-CSharp.dll" || "${UPDATE_ON_START:-false}" == "true" ]]; then
    : "${STEAM_USER:?STEAM_USER must be set (Subnautica cannot be downloaded anonymously)}"
    echo "Downloading/updating Subnautica into $GAME_DIR..."
    /home/steam/steamcmd/steamcmd.sh \
        +@sSteamCmdForcePlatformType windows \
        +force_install_dir "$GAME_DIR" \
        +login "$STEAM_USER" \
        +app_update 264710 validate \
        +quit
fi
