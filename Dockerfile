FROM cm2network/steamcmd

# "latest" or "tags/<version>" to pin a Nitrox release
ARG NITROX_RELEASE=latest

USER root
# libicuNN's version suffix changes with the Debian release, so resolve it
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    $(apt-cache search --names-only '^libicu[0-9]+$' | cut -d' ' -f1) \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mcr.microsoft.com/dotnet/runtime:9.0 /usr/share/dotnet /usr/share/dotnet
RUN ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

RUN set -e; \
    url=$(curl -fsSL "https://api.github.com/repos/SubnauticaNitrox/Nitrox/releases/${NITROX_RELEASE}" \
    | grep -o '"browser_download_url": *"[^"]*linux_x64[^"]*"' | head -n1 | cut -d'"' -f4); \
    if [ -z "$url" ]; then echo "No linux_x64 asset found for release '${NITROX_RELEASE}'"; exit 1; fi; \
    echo "Downloading $url"; \
    curl -fsSL -o /tmp/nitrox.zip "$url"; \
    unzip -q /tmp/nitrox.zip -d /opt/nitrox; \
    rm /tmp/nitrox.zip

# Pre-create mount points so named volumes are owned by steam, not root
RUN mkdir -p /data/subnautica /home/steam/Steam/config /home/steam/.config/Nitrox \
    && chown -R steam:steam /data /home/steam/Steam /home/steam/.config

COPY --chmod=755 entrypoint.sh install-game.sh server.sh /

USER steam
EXPOSE 11000/udp
VOLUME ["/data/subnautica", "/home/steam/Steam/config", "/home/steam/.config/Nitrox"]
ENTRYPOINT ["/entrypoint.sh"]
