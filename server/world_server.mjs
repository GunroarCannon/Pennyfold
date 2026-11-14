// Pennyfold shared-world presence server. No dependencies (Node 18+).
//
// One persistent world: a fixed seed (saved in world.json, so every player
// generates the same valley and the same people) and a shared day clock.
// Players connect over WebSocket, see each other move, and can chat.
// NPCs are not simulated here: they run per client from the shared seed.
//
//   node server/world_server.mjs            # ws://0.0.0.0:8788
//   PORT=9000 node server/world_server.mjs
//
// Protocol (JSON text frames)
//   client -> server  {t:"hello", name, look}   first message
//                     {t:"pos", x, y, dx, dy}   ~10x per second
//                     {t:"chat", text}
//                     {t:"raid_hit", dmg}       damage dealt to the raid dragon
//   server -> client  {t:"welcome", id, seed, clock, players:[{id,name,look,x,y}]}
//                     {t:"join", id, name, look, x, y} / {t:"leave", id}
//                     {t:"state", p:[[id,x,y,dx,dy],...]}   10 Hz
//                     {t:"chat", id, name, text}
//                     {t:"raid", state:"start"|"hp"|"end", kind, hp, max, left, top, won}

import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 8788);
const HOST = process.env.HOST || "0.0.0.0";
const MAX_PLAYERS = Number(process.env.MAX_PLAYERS || 32);
const STATE_FILE = path.join(HERE, "world.json");
const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

// ---- persistent world seed ----
let world = { seed: Math.floor(Math.random() * 100000), epoch: Date.now() };
try { world = { ...world, ...JSON.parse(fs.readFileSync(STATE_FILE, "utf8")) }; }
catch { fs.writeFileSync(STATE_FILE, JSON.stringify(world)); }
if (process.env.SEED) world.seed = Number(process.env.SEED);
const DAY_SECONDS = 300; // keep in step with main.gd DAY_SECONDS
const clock = () => ((Date.now() - world.epoch) / 1000) % DAY_SECONDS;

// ---- tiny RFC 6455 framing (text frames only) ----
function encode(str) {
  const body = Buffer.from(str);
  const n = body.length;
  let head;
  if (n < 126) head = Buffer.from([0x81, n]);
  else if (n < 65536) { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 126; head.writeUInt16BE(n, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x81; head[1] = 127; head.writeBigUInt64BE(BigInt(n), 2); }
  return Buffer.concat([head, body]);
}

// Returns {frames:[{op,data}], rest:Buffer}
function decode(buf) {
  const frames = [];
  for (;;) {
    if (buf.length < 2) break;
    const op = buf[0] & 0x0f;
    const masked = (buf[1] & 0x80) !== 0;
    let len = buf[1] & 0x7f, off = 2;
    if (len === 126) { if (buf.length < 4) break; len = buf.readUInt16BE(2); off = 4; }
    else if (len === 127) { if (buf.length < 10) break; len = Number(buf.readBigUInt64BE(2)); off = 10; }
    if (len > 65536) return { frames, rest: buf, bad: true };
    const need = off + (masked ? 4 : 0) + len;
    if (buf.length < need) break;
    let data = buf.subarray(off + (masked ? 4 : 0), need);
    if (masked) {
      const mask = buf.subarray(off, off + 4);
      data = Buffer.from(data.map((b, i) => b ^ mask[i % 4]));
    }
    frames.push({ op, data });
    buf = buf.subarray(need);
  }
  return { frames, rest: buf };
}

// ---- players ----
const players = new Map(); // id -> {id, sock, name, look, x, y, dx, dy, last, chatAt}
let nextId = 1;

function send(p, obj) { if (!p.sock.destroyed) p.sock.write(encode(JSON.stringify(obj))); }
function broadcast(obj, except) { for (const p of players.values()) if (p !== except && p.joined) send(p, obj); }
const clean = (s, n) => String(s ?? "").replace(/[\u0000-\u001f]/g, "").slice(0, n);
const num = (v) => (Number.isFinite(v) ? v : 0);

function onMessage(p, raw) {
  let m;
  try { m = JSON.parse(raw); } catch { return; }
  if (m.t === "hello" && !p.joined) {
    p.name = clean(m.name, 16) || "Traveller";
    p.look = typeof m.look === "object" && m.look ? m.look : {};
    p.joined = true;
    const others = [...players.values()].filter((o) => o !== p && o.joined)
      .map((o) => ({ id: o.id, name: o.name, look: o.look, x: o.x, y: o.y }));
    send(p, { t: "welcome", id: p.id, seed: world.seed, clock: clock(), players: others });
    if (raid) send(p, raidMsg("start"));
    broadcast({ t: "join", id: p.id, name: p.name, look: p.look, x: p.x, y: p.y }, p);
    console.log(`+ ${p.name} (#${p.id}) — ${players.size} online`);
  } else if (!p.joined) {
    return;
  } else if (m.t === "pos") {
    p.x = num(m.x); p.y = num(m.y); p.dx = num(m.dx); p.dy = num(m.dy); p.dirty = true;
  } else if (m.t === "look") {
    if (typeof m.look === "object" && m.look && JSON.stringify(m.look).length < 400) {
      p.look = m.look; p.name = clean(m.name, 16) || p.name;
      broadcast({ t: "look", id: p.id, name: p.name, look: p.look }, p);
    }
  } else if (m.t === "raid_hit") {
    raidHit(p, m);
  } else if (m.t === "chat") {
    const now = Date.now();
    if (now - p.chatAt < 800) return; // rate limit
    p.chatAt = now;
    const text = clean(m.text, 140).trim();
    if (text) broadcast({ t: "chat", id: p.id, name: p.name, text }); // includes sender
    if (text) send(p, { t: "chat", id: p.id, name: p.name, text });
  }
}

function drop(p) {
  if (!players.delete(p.id)) return;
  if (p.joined) { broadcast({ t: "leave", id: p.id }); console.log(`- ${p.name} (#${p.id}) — ${players.size} online`); }
  p.sock.destroy();
}

// ---- raids: one shared dragon, every player's hits count ----
// The server owns the health pool and the damage tally; clients only report
// hits (clamped and rate limited here) and draw the dragon near its lair.
const RAID_EVERY = Number(process.env.RAID_EVERY || 480);   // seconds between raids
const RAID_LENGTH = Number(process.env.RAID_LENGTH || 240);  // seconds to bring it down
const RAID_HP = Number(process.env.RAID_HP || 900);          // per player present at the start
const KINDS = ["dragon_red", "dragon_blue", "dragon_green"];
let raid = null;           // {id, kind, hp, max, ends, dmg: Map(id -> {name, dmg})}
let raidNext = Date.now() + Number(process.env.RAID_FIRST || 90) * 1000; // first raid ~90 s after start, then every RAID_EVERY
let raidIds = 0;

const online = () => [...players.values()].filter((p) => p.joined);
function top(r) { return [...r.dmg.values()].sort((a, b) => b.dmg - a.dmg).slice(0, 5).map((e) => [e.name, Math.round(e.dmg)]); }
function raidMsg(state, extra = {}) {
  return { t: "raid", state, id: raid.id, kind: raid.kind, hp: Math.round(raid.hp), max: raid.max, left: Math.max(0, Math.round((raid.ends - Date.now()) / 1000)), top: top(raid), ...extra };
}
function startRaid() {
  const n = Math.max(1, online().length);
  raid = { id: ++raidIds, kind: KINDS[Math.floor(Math.random() * KINDS.length)], hp: RAID_HP * n, max: RAID_HP * n, ends: Date.now() + RAID_LENGTH * 1000, dmg: new Map() };
  broadcast(raidMsg("start"));
  console.log(`! raid #${raid.id}: ${raid.kind}, ${raid.max} hp`);
}
function endRaid(won) {
  broadcast(raidMsg("end", { won, hp: won ? 0 : Math.round(raid.hp) }));
  console.log(`! raid #${raid.id} ${won ? "won" : "lost"}`);
  raid = null;
  raidNext = Date.now() + RAID_EVERY * 1000;
}
function raidHit(p, m) {
  if (!raid) return;
  const now = Date.now();
  if (now - (p.hitAt || 0) < 80) return; // at most ~12 hits per second each
  p.hitAt = now;
  const d = Math.min(Math.max(num(m.dmg), 0), 60);
  if (d <= 0) return;
  raid.hp = Math.max(0, raid.hp - d);
  const e = raid.dmg.get(p.id) || { name: p.name, dmg: 0 };
  e.name = p.name; e.dmg += d; raid.dmg.set(p.id, e);
  if (raid.hp <= 0) endRaid(true);
}
setInterval(() => {
  const n = online().length;
  if (raid) {
    if (Date.now() >= raid.ends) endRaid(false);
    else if (n === 0) { raid = null; raidNext = Date.now() + RAID_EVERY * 1000; }
    else broadcast(raidMsg("hp"));
  } else if (n > 0 && Date.now() >= raidNext) startRaid();
}, 500);

// ---- http + upgrade ----
const server = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/status") {
    res.writeHead(200, { "content-type": "application/json", "access-control-allow-origin": "*" });
    res.end(JSON.stringify({ ok: true, seed: world.seed, online: online().length, raid: raid ? { kind: raid.kind, hp: Math.round(raid.hp), max: raid.max } : null }));
  } else { res.writeHead(404); res.end(); }
});

server.on("upgrade", (req, sock) => {
  const key = req.headers["sec-websocket-key"];
  if (!key || players.size >= MAX_PLAYERS) { sock.end("HTTP/1.1 503 Service Unavailable\r\n\r\n"); return; }
  const accept = crypto.createHash("sha1").update(key + GUID).digest("base64");
  sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  sock.setNoDelay(true);
  const p = { id: nextId++, sock, name: "", look: {}, x: 0, y: 0, dx: 0, dy: 0, joined: false, dirty: false, chatAt: 0 };
  players.set(p.id, p);
  let buf = Buffer.alloc(0);
  sock.on("data", (d) => {
    buf = Buffer.concat([buf, d]);
    const r = decode(buf);
    if (r.bad) return drop(p);
    buf = r.rest;
    for (const f of r.frames) {
      if (f.op === 0x8) return drop(p);
      if (f.op === 0x9) sock.write(Buffer.concat([Buffer.from([0x8a, f.data.length]), f.data])); // pong
      if (f.op === 0x1) onMessage(p, f.data.toString("utf8"));
    }
  });
  sock.on("close", () => drop(p));
  sock.on("error", () => drop(p));
});

// 10 Hz batched positions
setInterval(() => {
  const moved = [...players.values()].filter((p) => p.joined && p.dirty);
  if (!moved.length) return;
  const states = moved.map((p) => [p.id, +p.x.toFixed(1), +p.y.toFixed(1), +p.dx.toFixed(2), +p.dy.toFixed(2)]);
  moved.forEach((p) => (p.dirty = false));
  for (const p of players.values()) {
    if (!p.joined) continue;
    const mine = states.filter((s) => s[0] !== p.id);
    if (mine.length) send(p, { t: "state", p: mine });
  }
}, 100);

server.listen(PORT, HOST, () => console.log(`Pennyfold world on ws://${HOST}:${PORT}  seed ${world.seed}`));
