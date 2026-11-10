# Nitrox server image

Docker image for a [Nitrox](https://github.com/SubnauticaNitrox/Nitrox) (Subnautica multiplayer) dedicated server.

The Nitrox server needs Subnautica's game files. These are **not** in the image. On first start, the container downloads them with steamcmd into a volume, using a Steam account that owns the game. Later starts reuse the files from the volume.

## Requirements

- Docker
- A Steam account that owns Subnautica (anonymous login can't download it)
- An `amd64` host, or a host that can emulate it (see [ARM hosts](#arm-hosts))

## Build

```sh
docker build --platform linux/amd64 -t nitrox .
```

The latest Nitrox release is installed by default. To pin a version:

```sh
docker build --platform linux/amd64 --build-arg NITROX_RELEASE=tags/1.8.1.0 -t nitrox .
```

## First run

Create a volume for your Steam login. It can be shared with other steamcmd-based containers (see [Sharing the Steam login](#sharing-the-steam-login)):

```sh
docker volume create steam-youruser
```

Run the container **interactively** the first time, so steamcmd can ask for your password and Steam Guard code:

```sh
docker run -it --name nitrox --platform linux/amd64 --stop-timeout 60 \
  -e STEAM_USER=youruser \
  -v steam-youruser:/home/steam/Steam/config \
  -v subnautica:/data/subnautica \
  -v nitrox-saves:/home/steam/.config/Nitrox \
  -p 11000:11000/udp \
  nitrox
```

The container then:

1. Logs in to Steam. Your password and Steam Guard code are asked for once; after that the login token stays cached in the `steam-youruser` volume.
2. Downloads Subnautica (a few GB) into the `subnautica` volume.
3. Starts the Nitrox server.

Detach without stopping the server with `Ctrl-P` then `Ctrl-Q`.

## Later runs

The login is now cached, so the container can run in the background:

```sh
docker start nitrox
```

Or create a fresh container with the same volumes, adding `-d`:

```sh
docker run -d -it --name nitrox --platform linux/amd64 --stop-timeout 60 \
  -e STEAM_USER=youruser \
  -v steam-youruser:/home/steam/Steam/config \
  -v subnautica:/data/subnautica \
  -v nitrox-saves:/home/steam/.config/Nitrox \
  -p 11000:11000/udp \
  nitrox
```

Keep `-it`: the Nitrox server reads console commands from stdin.

## Server console

```sh
docker attach nitrox
```

Type Nitrox commands (e.g. `save`, `list`), then detach with `Ctrl-P` `Ctrl-Q`.

## Stopping

`docker stop nitrox` (or `docker compose down`) saves the world before the server exits. The entrypoint catches Docker's stop signal and sends `stop` to the server console, just like typing it yourself.

This is needed because Nitrox's own signal handling lets .NET kill the process before it saves. Running the server some other way (e.g. overriding the entrypoint) loses everything since the last autosave on `docker stop`.

Docker force-kills the container if it hasn't exited by the stop timeout. The default is 10 s, so the commands above use `--stop-timeout 60`, and `compose.yaml` sets `stop_grace_period: 60s`. Raise it if your world takes longer to save.

## Configuration

### Environment variables

| Variable          | Default            | Description                                                                 |
| ----------------- | ------------------ | --------------------------------------------------------------------------- |
| `STEAM_USER`      | —                  | Steam account that owns Subnautica. Needed whenever the game is downloaded. |
| `UPDATE_ON_START` | `false`            | `true` makes steamcmd check for and apply game updates on every start.      |
| `GAME_DIR`        | `/data/subnautica` | Where the game files are installed and read from.                           |

The game is downloaded when `GAME_DIR` has no `Subnautica_Data/Managed/Assembly-CSharp.dll`, or when `UPDATE_ON_START=true`.

### Volumes

| Path                         | Contents                                    |
| ---------------------------- | ------------------------------------------- |
| `/home/steam/Steam/config`   | steamcmd login token (`config.vdf`)         |
| `/data/subnautica`           | Subnautica game files                       |
| `/home/steam/.config/Nitrox` | Nitrox data: worlds/saves and server config |

### Ports

| Port        | Description   |
| ----------- | ------------- |
| `11000/udp` | Nitrox server |

## Docker Compose

`compose.yaml` builds the image and wires up the same volumes and port as the `docker run` commands above.

1. Set your Steam account:
   ```sh
   cp .env.example .env   # then edit STEAM_USER
   ```
2. Create the shared Steam login volume. Its name is derived from `STEAM_USER`:
   ```sh
   docker volume create steam-youruser
   ```
3. First start, interactively, so steamcmd can ask for your password and Steam Guard code:
   ```sh
   docker compose run --rm nitrox
   ```
   Once the game has downloaded and the server is up, type `stop` to exit.
4. From then on, run it in the background:
   ```sh
   docker compose up -d
   docker attach nitrox     # server console; detach with Ctrl-P Ctrl-Q
   docker compose down      # saves the world, then stops
   ```

Notes:

- The Steam volume is `external`, so Compose uses `steam-<STEAM_USER>` as-is instead of creating a per-project copy. This is what lets other projects share it.
- The game and saves volumes are named `subnautica` and `nitrox-saves`, the same as in the `docker run` commands, so you can switch between Compose and `docker run` without losing data.
- If you already did the login with `docker run`, skip step 3.

## Sharing the Steam login

The Steam volume holds only steamcmd's `config` directory, the folder with the cached login token. Caches, logs and lock files stay in each container, so the volume can be shared:

- **One volume per Steam account**, e.g. `steam-youruser`, `steam-otheraccount`. Mount the right one in each container.
- **Other images** must mount it at their own steamcmd config path and run as the same user ID. `cm2network/steamcmd`-based images use `/home/steam/Steam/config` with UID `1000`, so they work as-is.
- If two containers log in with the same account at the same moment, both rewrite `config.vdf` and the last write wins. This should be harmless, but if a container ever loses its login, stagger the startups.

## With the server manager

The server manager runs this image with its own entrypoint, shared by all its game images, and
`/server.sh` as the command. `server.sh` installs the game if needed, then runs the server in the
foreground, console on stdin and output on stdout. The manager's entrypoint handles the console,
the log and the `stop` on `docker stop`, so this image's `entrypoint.sh` is only for running it
alone.

In the manager, the Nitrox volume is a host folder, `/opt/nitrox/<name>/server`, so its file
manager can edit the worlds and `server.cfg`. The game and Steam volumes stay volumes. See
`deploy/games/compose.yml` in the server manager repo.

The manager's console isn't a terminal, so steamcmd can't ask for the password there. Do the first
Steam login with a one-off run of `install-game.sh`, which also downloads the game into the
manager's `subnautica` volume (Nitrox section of the manager's `SETUP.md`):

```sh
docker compose -f deploy/games/compose.yml run --rm --user 1000:1000 --entrypoint /install-game.sh game-nitrox-<name>
```

| Script            | Role                                                                                    |
| ----------------- | --------------------------------------------------------------------------------------- |
| `install-game.sh` | Downloads or updates Subnautica (steamcmd)                                              |
| `server.sh`       | `install-game.sh`, then the server in the foreground                                    |
| `entrypoint.sh`   | Alone: `install-game.sh` on the terminal, then `server.sh` with `stop` on `docker stop` |

## Updating

- **Subnautica:** start once with `-e UPDATE_ON_START=true`, or keep it enabled.
- **Nitrox:** rebuild the image (`--no-cache` to pick up a new `latest`, or bump `NITROX_RELEASE`), then recreate the container. Game files, saves and login stay in the volumes. Nitrox clients must run the same Nitrox version as the server.

## ARM hosts

steamcmd only exists for x86, so the image is `amd64`-only.

- **Apple Silicon (Docker Desktop):** works through emulation; keep `--platform linux/amd64`.
- **ARM Linux servers:** install qemu/binfmt emulation (e.g. `docker run --privileged --rm tonistiigi/binfmt --install amd64`).

## Troubleshooting

- **`STEAM_USER must be set`:** the game files are missing (or `UPDATE_ON_START=true`) and no account was given.
- **steamcmd asks for a password in a background container:** the login isn't cached yet, or the token expired. Run once interactively with `-it` (without `-d`) and log in again.
- **`No subscription`:** the account doesn't own Subnautica.
- **Server can't find the game:** the entrypoint sets `SUBNAUTICA_INSTALLATION_PATH` to `GAME_DIR`. Check that `GAME_DIR` contains `Subnautica_Data/`:
  ```sh
  docker run --rm -v subnautica:/data/subnautica --entrypoint ls nitrox /data/subnautica
  ```
