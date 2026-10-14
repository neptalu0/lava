#!/usr/bin/env bash
set -e

# Ensure Java runtime is available (fallback for Node/Python buildpacks)
if ! command -v java >/dev/null 2>&1; then
    echo "[INFO] Java runtime not detected. Fetching portable OpenJDK 17 JRE..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)   JDK_ARCH="x64" ;;
        aarch64|arm64)  JDK_ARCH="aarch64" ;;
        *)              JDK_ARCH="x64" ;;
    esac

    mkdir -p jre
    if [ ! -f "jre/bin/java" ]; then
        JRE_TAR="jre17.tar.gz"
        JRE_URL="https://api.adoptium.net/v3/binary/latest/17/ga/linux/${JDK_ARCH}/jre/hotspot/normal/eclipse"
        echo "[INFO] Downloading JRE from $JRE_URL..."
        if command -v curl >/dev/null 2>&1; then
            curl -sSL "$JRE_URL" -o "$JRE_TAR"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$JRE_URL" -O "$JRE_TAR"
        else
            echo "[ERROR] Neither curl nor wget is available." >&2
            exit 1
        fi
        echo "[INFO] Extracting JRE..."
        tar -xzf "$JRE_TAR" -C jre --strip-components=1
        rm -f "$JRE_TAR"
        echo "[INFO] Portable JRE ready."
    fi
    export JAVA_HOME="$PWD/jre"
    export PATH="$PWD/jre/bin:$PATH"
fi

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
