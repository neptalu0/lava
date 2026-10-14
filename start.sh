#!/usr/bin/env bash
set -e

# Helper function to download files with fallback to Node.js or Python
download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    elif command -v node >/dev/null 2>&1; then
        node -e '
const fs = require("fs");
const https = require("https");
const http = require("http");

function fetchUrl(url, dest) {
  const client = url.startsWith("https") ? https : http;
  client.get(url, (res) => {
    if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
      return fetchUrl(res.headers.location, dest);
    }
    if (res.statusCode !== 200) {
      console.error("[ERROR] HTTP download failed with status " + res.statusCode);
      process.exit(1);
    }
    const file = fs.createWriteStream(dest);
    res.pipe(file);
    file.on("finish", () => file.close());
  }).on("error", (err) => {
    console.error("[ERROR] Download failed: " + err.message);
    process.exit(1);
  });
}
fetchUrl(process.argv[1], process.argv[2]);
' "$url" "$dest"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import urllib.request, sys; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])" "$url" "$dest"
    elif command -v python >/dev/null 2>&1; then
        python -c "import urllib.request, sys; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])" "$url" "$dest"
    else
        echo "[ERROR] Neither curl, wget, node, nor python is available to download files." >&2
        exit 1
    fi
}

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
        download_file "$JRE_URL" "$JRE_TAR"
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
    download_file "$DOWNLOAD_URL" "$LAVALINK_JAR"
    echo "[INFO] Lavalink.jar downloaded successfully."
fi

# Set default heap limits if not provided in environment
if [ -z "$JAVA_OPTS" ]; then
    JAVA_OPTS="-Xmx${JVM_HEAP:-512M} -Xms${JVM_INITIAL_HEAP:-256M} -XX:+UseG1GC"
fi

echo "[INFO] Starting Lavalink on port ${PORT:-2333} with options: $JAVA_OPTS"
exec java $JAVA_OPTS -Dserver.port="${PORT:-2333}" -jar "$LAVALINK_JAR"
