// Minimal static server for the Flutter web build, plus a proxy to the API.
//
// This exists so the whole stack can run as native Windows processes. Inside
// WSL, Caddy does both jobs — but a WireGuard tunnel on this machine swallows
// traffic to WSL's virtual subnet, so the browser cannot reach it. Native
// Windows loopback is unaffected by that route.
//
// Serving the app and proxying /api from the SAME origin also keeps the client
// on same-origin requests, exactly as Caddy does in production, so nothing in
// the app has to know it is running differently.
//
// No dependencies on purpose: node built-ins only.
const http = require('node:http');
const net = require('node:net');
const fs = require('node:fs');
const path = require('node:path');

const PORT = Number(process.env.WEB_PORT || 8081);
const API = process.env.API_ORIGIN || 'http://127.0.0.1:3000';
const ROOT = path.resolve(__dirname, '..', 'build', 'web');

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
  // /api and /ws belong to the API service; everything else is the app.
  if (req.url.startsWith('/api') || req.url.startsWith('/ws')) {
    const target = new URL(req.url, API);
    const proxied = http.request(
      {
        hostname: target.hostname,
        port: target.port,
        path: target.pathname + target.search,
        method: req.method,
        headers: { ...req.headers, host: target.host },
      },
      (upstream) => {
        res.writeHead(upstream.statusCode || 502, upstream.headers);
        upstream.pipe(res);
      },
    );
    proxied.on('error', (error) => {
      res.writeHead(502, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'api_unreachable', detail: error.message }));
    });
    req.pipe(proxied);
    return;
  }

  const requested = decodeURIComponent(req.url.split('?')[0]);
  let filePath = path.join(ROOT, requested === '/' ? 'index.html' : requested);

  // Keep every response inside the build directory.
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403).end('forbidden');
    return;
  }

  fs.stat(filePath, (error, stat) => {
    // Unknown paths fall back to index.html so deep links work in the SPA.
    if (error || !stat.isFile()) filePath = path.join(ROOT, 'index.html');
    const type = TYPES[path.extname(filePath).toLowerCase()] ?? 'application/octet-stream';
    res.writeHead(200, { 'content-type': type, 'cache-control': 'no-cache' });
    fs.createReadStream(filePath).pipe(res);
  });
});

// WebSocket upgrades (the live alert feed) have to be forwarded by hand.
//
// A raw TCP relay, not http.request: parsing and re-emitting the frames broke
// client→server masking ("Invalid WebSocket frame: MASK must be set" on the
// API side), which killed the socket on the first message. Replaying the
// handshake bytes verbatim and splicing the two sockets together means this
// proxy never interprets a single frame.
server.on('upgrade', (req, socket, head) => {
  const target = new URL(API);
  const upstream = net.connect(Number(target.port || 80), target.hostname, () => {
    const headerLines = [];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      headerLines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
    }
    upstream.write(
      `GET ${req.url} HTTP/1.1\r\n${headerLines.join('\r\n')}\r\n\r\n`,
    );
    if (head?.length) upstream.write(head);
    socket.pipe(upstream);
    upstream.pipe(socket);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});

// All interfaces, not loopback only: on this machine a VPN client blocks
// browser connections to 127.0.0.1 while curl sails through, so the app is
// also reachable via the LAN address (http://<lan-ip>:8081). Local testing
// scaffolding — production is Caddy on the server.
server.listen(PORT, () => {
  console.log(`app  http://localhost:${PORT} (and this machine's LAN IP)`);
  console.log(`api  proxied to ${API}`);
  console.log(`root ${ROOT}`);
});
