const http = require('http');
const net = require('net');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '2333', 10);
const LAVALINK_PORT = parseInt(process.env.LAVALINK_INTERNAL_PORT || '2334', 10);
const LAVALINK_PASSWORD = process.env.LAVALINK_PASSWORD || process.env.PASS || 'youshallnotpass';

const HTML_PATH = path.join(__dirname, 'public', 'index.html');
let cachedHtml = '';

try {
  cachedHtml = fs.readFileSync(HTML_PATH, 'utf8');
} catch (e) {
  cachedHtml = '<h1>Lavalink Live Status</h1>';
}

function proxyHttpRequest(req, res) {
  const options = {
    host: '127.0.0.1',
    port: LAVALINK_PORT,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: `127.0.0.1:${LAVALINK_PORT}` }
  };

  const pReq = http.request(options, (pRes) => {
    res.writeHead(pRes.statusCode, pRes.headers);
    pRes.pipe(res);
  });

  pReq.on('error', (err) => {
    res.writeHead(503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      error: 'Lavalink service initializing or unavailable',
      detail: err.message
    }));
  });

  req.pipe(pReq);
}

function fetchLavalinkStats(callback) {
  const options = {
    host: '127.0.0.1',
    port: LAVALINK_PORT,
    path: '/v4/stats',
    method: 'GET',
    headers: {
      'Authorization': LAVALINK_PASSWORD
    },
    timeout: 2500
  };

  const req = http.request(options, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      if (res.statusCode === 200) {
        try {
          const stats = JSON.parse(body);
          return callback(null, stats);
        } catch (e) {
          return callback(e);
        }
      }
      callback(new Error(`Status ${res.statusCode}`));
    });
  });

  req.on('timeout', () => {
    req.destroy();
    callback(new Error('Timeout'));
  });

  req.on('error', (err) => {
    callback(err);
  });

  req.end();
}

const server = http.createServer((req, res) => {
  const urlPath = req.url.split('?')[0];

  // Route: /api/stats (Used by frontend live polling)
  if (urlPath === '/api/stats') {
    fetchLavalinkStats((err, stats) => {
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache'
      });

      if (err || !stats) {
        return res.end(JSON.stringify({
          status: 'starting',
          message: 'Lavalink is starting up...',
          passwordPlaceholder: LAVALINK_PASSWORD
        }));
      }

      res.end(JSON.stringify({
        status: 'online',
        players: stats.players || 0,
        playingPlayers: stats.playingPlayers || 0,
        uptime: Math.floor((stats.uptime || 0) / 1000),
        cpu: {
          cores: stats.cpu?.cores || 1,
          systemLoad: (stats.cpu?.systemLoad || 0) * 100,
          lavalinkLoad: (stats.cpu?.lavalinkLoad || 0) * 100
        },
        memory: {
          free: Math.round((stats.memory?.free || 0) / (1024 * 1024)),
          used: Math.round((stats.memory?.used || 0) / (1024 * 1024)),
          allocated: Math.round((stats.memory?.allocated || 0) / (1024 * 1024)),
          reservable: Math.round((stats.memory?.reservable || 0) / (1024 * 1024))
        },
        passwordPlaceholder: LAVALINK_PASSWORD
      }));
    });
    return;
  }

  // Route: / or /index.html (Serve dashboard when accessed via browser)
  const isBrowser = (req.headers['accept'] && req.headers['accept'].includes('text/html')) && !req.headers['authorization'];
  if ((urlPath === '/' || urlPath === '/index.html') && isBrowser) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(cachedHtml);
  }

  // All other requests (e.g. /v4/*, /version, etc.) are forwarded directly to Lavalink
  proxyHttpRequest(req, res);
});

// Proxy WebSocket upgrades (/v4/websocket, etc.) directly to Lavalink
server.on('upgrade', (req, socket, head) => {
  const proxySocket = net.connect(LAVALINK_PORT, '127.0.0.1', () => {
    let rawReq = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      rawReq += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
    }
    rawReq += '\r\n';
    proxySocket.write(rawReq);
    if (head && head.length > 0) {
      proxySocket.write(head);
    }
    socket.pipe(proxySocket);
    proxySocket.pipe(socket);
  });

  proxySocket.on('error', (err) => {
    socket.destroy();
  });

  socket.on('error', (err) => {
    proxySocket.destroy();
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[INFO] Web dashboard & reverse proxy listening on port ${PORT}`);
  console.log(`[INFO] Forwarding backend bot traffic to internal Lavalink port ${LAVALINK_PORT}`);
});
