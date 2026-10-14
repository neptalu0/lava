# Lavalink Buildpack Project

A production-ready [Lavalink](https://github.com/lavalink-devs/Lavalink) v4 deployment template configured for platforms utilizing **Buildpacks** and `Procfile` process models (Heroku, Dokku, Railway, Render, Fly.io, etc.).

---

## 📁 Repository Structure

```text
lava/
├── Procfile             # Defines the web process (web: bash start.sh)
├── start.sh             # Bootstrapper (auto-downloads Lavalink.jar if absent & applies JVM flags)
├── system.properties    # Specifies Java 17 for Heroku/JVM buildpacks
├── pom.xml              # Maven packaging descriptor for Cloud Native/Paketo Java buildpacks
├── application.yml      # Lavalink v4 configuration (port & password env vars, YouTube plugin)
├── app.json             # Heroku deployment manifest & config vars definition
└── .gitignore           # Ignores runtime cache & logs
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `PORT` | `2333` | Port assigned dynamically by the PaaS / container router. |
| `LAVALINK_PASSWORD` | `youshallnotpass` | Authentication password for your Discord bot. |
| `JVM_HEAP` | `512M` | Maximum RAM allocation for the JVM (`-Xmx`). |
| `LAVALINK_DOWNLOAD_URL` | *Latest v4 release* | Optional custom URL for `Lavalink.jar` if downloading manually. |

---

## 🚀 How to Deploy

### Option A: Heroku / Dokku CLI
1. Initialize git and commit:
   ```bash
   git init
   git add .
   git commit -m "Initial Lavalink buildpack template"
   ```
2. Create your application:
   ```bash
   heroku create my-lavalink-server
   ```
3. (Optional) Set the Java buildpack if not auto-detected:
   ```bash
   heroku buildpacks:set heroku/jvm
   ```
4. Configure your password:
   ```bash
   heroku config:set LAVALINK_PASSWORD="your-strong-password"
   ```
5. Deploy:
   ```bash
   git push heroku main
   ```

### Option B: Railway / Render / Other PaaS
1. Push this folder to a GitHub repository.
2. Link the repository on your hosting dashboard.
3. The platform will automatically detect:
   - `pom.xml` / `system.properties` -> Uses **Java 17 runtime**.
   - `Procfile` -> Runs `web: bash start.sh`.
4. Set the `LAVALINK_PASSWORD` in your dashboard environment variables.

---

## 🔌 Connecting Your Discord Bot

Point your bot's Lavalink client (Wavelink, Lavalink-Client, Discord.js, etc.) to:
- **Host**: Your deployed domain (e.g., `my-lavalink-server.herokuapp.com` or `lavalink.up.railway.app`)
- **Port**: `80` (or `443` for HTTPS/WSS)
- **Password**: Whatever you set `LAVALINK_PASSWORD` to
- **Secure**: `true` (if using `https://` / `wss://`)
