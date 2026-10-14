#!/usr/bin/env bash
set -e

LAVALINK_JAR="Lavalink.jar"
DEFAULT_LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"

# Download Lavalink.jar if not present
if [ ! -f "$LAVALINK_JAR" ]; then
    echo "[INFO] Lavalink.jar not found. Downloading latest release..."
    DOWNLOAD_URL="${LAVALINK_DOWNLOAD_URL:-$DEFAULT_LAVALINK_URL}"
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$DOWNLOAD_URL" -o "$LAVALINK_JAR"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$DOWNLOAD_URL" -O "$LAVALINK_JAR"
    else
        echo "[ERROR] Neither curl nor wget is available to download Lavalink.jar." >&2
        exit 1
    fi
    echo "[INFO] Lavalink.jar downloaded successfully."
fi

# Set default heap limits if not provided in environment
if [ -z "$JAVA_OPTS" ]; then
    JAVA_OPTS="-Xmx${JVM_HEAP:-512M} -Xms${JVM_INITIAL_HEAP:-256M} -XX:+UseG1GC"
fi

echo "[INFO] Starting Lavalink on port ${PORT:-2333} with options: $JAVA_OPTS"
exec java $JAVA_OPTS -Dserver.port="${PORT:-2333}" -jar "$LAVALINK_JAR"
