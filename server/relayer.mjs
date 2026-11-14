// Pennyfold NEAR relayer. No dependencies (Node 18+).
//
// The game sends the town's coin flows here; the relayer mirrors them on
// NEAR as real transfers between sub-accounts of one root account:
//   bakery-0.<root>, npc-3.<root>, board.<root>, player.<root>, ...
// Players never see a wallet. Keys for sub-accounts are derived from the
// root key and the wallet id, so nothing extra has to be stored.
//
// Modes:
//   dry-run  (default)  logs what it would sign, sends nothing.
//   testnet             only with NEAR_ACCOUNT + NEAR_PRIVATE_KEY set AND
//                       the --live flag. Signs and sends real transactions.
//
//   node server/relayer.mjs            # dry run
//   node server/relayer.mjs --live     # testnet, reads server/.env
//
// Endpoints: GET /status, GET /health, POST /genesis {ledger}, POST /settle
// {day, flows, ledger}, GET /accounts.
//
// It also serves the Godot web export (default ../build/web, or WEB_DIR) from
// the same origin, so the browser build talks to it with no CORS or mixed
// content trouble:  node server/relayer.mjs  ->  http://127.0.0.1:8787/
// Set HOST=0.0.0.0 to reach it from another device.

import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
loadEnv(path.join(HERE, ".env"));

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const WEB_DIR = path.resolve(process.env.WEB_DIR || path.join(HERE, "..", "build", "web"));
const MIME = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream",
  ".png": "image/png", ".json": "application/json", ".css": "text/css", ".ico": "image/x-icon", ".svg": "image/svg+xml",
  ".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav", ".ttf": "font/ttf", ".otf": "font/otf",
};
const NETWORK = process.env.NEAR_NETWORK || "testnet";
const RPC = process.env.NEAR_RPC || (NETWORK === "mainnet" ? "" : "https://test.rpc.fastnear.com");
const ROOT = process.env.NEAR_ACCOUNT || "";
const ROOT_KEY = process.env.NEAR_PRIVATE_KEY || "";
const LIVE = process.argv.includes("--live") && ROOT && ROOT_KEY && NETWORK === "testnet";
const MODE = LIVE ? "testnet" : "dry-run";
// 1 game coin = 0.0001 NEAR. Each sub-account also gets a small base for
// storage and gas.
const YOCTO = 10n ** 24n;
const COIN = YOCTO / 10000n;
const BASE = YOCTO / 100n;
const STATE_FILE = path.join(HERE, "state.json");

const state = fs.existsSync(STATE_FILE) ? JSON.parse(fs.readFileSync(STATE_FILE, "utf8")) : { accounts: {}, days: [] };
const save = () => { if (LIVE) fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2)); };
const dryAccounts = new Set();

if (NETWORK === "mainnet") {
  console.error("Refusing to run on mainnet.");
  process.exit(1);
}

// ---------- base58 ----------
const B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
function b58encode(buf) {
  let n = BigInt("0x" + (Buffer.from(buf).toString("hex") || "0"));
  let out = "";
  while (n > 0n) { out = B58[Number(n % 58n)] + out; n /= 58n; }
  for (const b of buf) { if (b === 0) out = "1" + out; else break; }
  return out;
}
function b58decode(str) {
  let n = 0n;
  for (const c of str) {
    const i = B58.indexOf(c);
    if (i < 0) throw new Error("bad base58");
    n = n * 58n + BigInt(i);
  }
  let hex = n.toString(16);
  if (hex.length % 2) hex = "0" + hex;
  const body = n === 0n ? Buffer.alloc(0) : Buffer.from(hex, "hex");
  let zeros = 0;
  for (const c of str) { if (c === "1") zeros++; else break; }
  return Buffer.concat([Buffer.alloc(zeros), body]);
}

// ---------- keys ----------
const PKCS8 = Buffer.from("302e020100300506032b657004220420", "hex");
function keyFromSeed(seed) {
  const priv = crypto.createPrivateKey({ key: Buffer.concat([PKCS8, seed]), format: "der", type: "pkcs8" });
  const pub = crypto.createPublicKey(priv).export({ format: "der", type: "spki" }).subarray(-32);
  return { priv, pub, seed };
}
function rootKey() {
  const raw = b58decode(ROOT_KEY.replace(/^ed25519:/, ""));
  return keyFromSeed(raw.subarray(0, 32));
}
// Sub-account keys: sha256(root seed + wallet id). Deterministic, never stored.
function walletKey(id) {
  const root = rootKey();
  return keyFromSeed(crypto.createHash("sha256").update(root.seed).update("folded-fists:" + id).digest());
}
function accountFor(id) {
  const clean = id.toLowerCase().replace(/[^a-z0-9-]/g, "-").replace(/^-+|-+$/g, "") || "w";
  return `${clean}.${ROOT || "town.testnet"}`;
}

// ---------- borsh ----------
class W {
  constructor() { this.parts = []; }
  u8(v) { this.parts.push(Buffer.from([v])); }
  u32(v) { const b = Buffer.alloc(4); b.writeUInt32LE(v); this.parts.push(b); }
  u64(v) { const b = Buffer.alloc(8); b.writeBigUInt64LE(BigInt(v)); this.parts.push(b); }
  u128(v) { const b = Buffer.alloc(16); let x = BigInt(v); for (let i = 0; i < 16; i++) { b[i] = Number(x & 0xffn); x >>= 8n; } this.parts.push(b); }
  bytes(b) { this.parts.push(Buffer.from(b)); }
  str(s) { const b = Buffer.from(s, "utf8"); this.u32(b.length); this.parts.push(b); }
  out() { return Buffer.concat(this.parts); }
}
// Actions: 0 CreateAccount, 3 Transfer, 5 AddKey (full access).
function serializeTx({ signer, pub, nonce, receiver, blockHash, actions }) {
  const w = new W();
  w.str(signer);
  w.u8(0); w.bytes(pub);
  w.u64(nonce);
  w.str(receiver);
  w.bytes(blockHash);
  w.u32(actions.length);
  for (const a of actions) {
    if (a.type === "create") { w.u8(0); }
    else if (a.type === "transfer") { w.u8(3); w.u128(a.deposit); }
    else if (a.type === "addkey") { w.u8(5); w.u8(0); w.bytes(a.pub); w.u64(0); w.u8(1); }
  }
  return w.out();
}

// ---------- rpc ----------
async function rpc(method, params) {
  const r = await fetch(RPC, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: "ff", method, params }),
  });
  const j = await r.json();
  if (j.error) throw new Error(JSON.stringify(j.error));
  return j.result;
}
const nonces = {};
async function signAndSend(signer, key, receiver, actions) {
  const pubStr = "ed25519:" + b58encode(key.pub);
  const ak = await rpc("query", { request_type: "view_access_key", finality: "final", account_id: signer, public_key: pubStr });
  const nonce = Math.max(Number(ak.nonce), nonces[signer] || 0) + 1;
  nonces[signer] = nonce;
  const tx = serializeTx({ signer, pub: key.pub, nonce, receiver, blockHash: b58decode(ak.block_hash), actions });
  const hash = crypto.createHash("sha256").update(tx).digest();
  const sig = crypto.sign(null, hash, key.priv);
  const signed = Buffer.concat([tx, Buffer.from([0]), sig]);
  const res = await rpc("send_tx", { signed_tx_base64: signed.toString("base64"), wait_until: "INCLUDED" });
  return res?.transaction?.hash || b58encode(hash);
}
async function exists(account) {
  try { await rpc("query", { request_type: "view_account", finality: "final", account_id: account }); return true; }
  catch { return false; }
}

// ---------- town ----------
async function ensureAccount(id, coins) {
  const account = accountFor(id);
  if (state.accounts[id] || dryAccounts.has(id)) return { account, created: false };
  const deposit = BASE + COIN * BigInt(Math.max(0, coins));
  if (!LIVE) {
    // Dry-run accounts live in memory only, so a later --live run still creates them.
    console.log(`[dry-run] create ${account} with ${coins} coins (${deposit} yocto)`);
    dryAccounts.add(id);
    return { account, created: true };
  }
  if (!(await exists(account))) {
    const k = walletKey(id);
    const hash = await signAndSend(ROOT, rootKey(), account, [{ type: "create" }, { type: "transfer", deposit }, { type: "addkey", pub: k.pub }]);
    console.log(`created ${account}  tx ${hash}`);
  }
  state.accounts[id] = { account };
  save();
  return { account, created: true };
}

async function settle(day, flows, ledger) {
  const txs = [];
  for (const f of flows) {
    await ensureAccount(f.from, ledger?.[f.from] ?? 0);
    await ensureAccount(f.to, ledger?.[f.to] ?? 0);
    const from = accountFor(f.from);
    const to = accountFor(f.to);
    const deposit = COIN * BigInt(f.amount);
    if (!LIVE) {
      console.log(`[dry-run] day ${day}: ${from} -> ${to}  ${f.amount} coins`);
      txs.push({ from, to, amount: f.amount, hash: "" });
      continue;
    }
    try {
      const hash = await signAndSend(from, walletKey(f.from), to, [{ type: "transfer", deposit }]);
      txs.push({ from, to, amount: f.amount, hash, url: `https://testnet.nearblocks.io/txns/${hash}` });
    } catch (e) {
      txs.push({ from, to, amount: f.amount, error: String(e.message || e).slice(0, 200) });
    }
  }
  state.days.push({ day, flows: flows.length, txs: txs.map((t) => t.hash || t.error || "dry") });
  save();
  return txs;
}

// ---------- http ----------
function send(res, code, obj) {
  res.writeHead(code, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  });
  res.end(JSON.stringify(obj));
}
function serveStatic(req, res) {
  const url = new URL(req.url, "http://x");
  let rel = decodeURIComponent(url.pathname);
  if (rel === "/") rel = "/index.html";
  const file = path.normalize(path.join(WEB_DIR, rel));
  if (!file.startsWith(WEB_DIR) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    const hint = fs.existsSync(WEB_DIR) ? "not found" : `web build not found at ${WEB_DIR}. Export the Godot Web preset to build/web first (see README).`;
    return send(res, 404, { error: hint });
  }
  res.writeHead(200, {
    "Content-Type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
    "Cache-Control": "no-cache",
  });
  fs.createReadStream(file).pipe(res);
}
async function body(req) {
  let data = "";
  for await (const chunk of req) { data += chunk; if (data.length > 1e6) throw new Error("too big"); }
  return data ? JSON.parse(data) : {};
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") return send(res, 204, {});
    if (req.method === "GET" && req.url === "/health") return send(res, 200, { ok: true });
    if (req.method === "GET" && req.url === "/status") {
      return send(res, 200, { mode: MODE, network: NETWORK, account: ROOT || "(none)", coin_yocto: COIN.toString(), live: LIVE, explorer: "https://testnet.nearblocks.io" });
    }
    if (req.method === "GET" && req.url === "/accounts") {
      return send(res, 200, LIVE ? state.accounts : Object.fromEntries([...dryAccounts].map((id) => [id, { account: accountFor(id), dry: true }])));
    }
    if (req.method === "POST" && req.url === "/genesis") {
      const { ledger = {} } = await body(req);
      const made = [];
      for (const [id, coins] of Object.entries(ledger)) {
        const r = await ensureAccount(id, Number(coins));
        if (r.created) made.push(r.account);
      }
      return send(res, 200, { ok: true, created: made.length });
    }
    if (req.method === "POST" && req.url === "/settle") {
      const { day = 0, flows = [], ledger = {} } = await body(req);
      const clean = flows.filter((f) => f && typeof f.from === "string" && typeof f.to === "string" && Number.isInteger(f.amount) && f.amount > 0 && f.amount < 100000);
      const txs = await settle(day, clean, ledger);
      return send(res, 200, { ok: txs.every((t) => !t.error), txs });
    }
    if (req.method === "GET" || req.method === "HEAD") return serveStatic(req, res);
    send(res, 404, { error: "not found" });
  } catch (e) {
    send(res, 500, { error: String(e.message || e) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Pennyfold relayer on http://${HOST}:${PORT}  mode=${MODE}  network=${NETWORK}  root=${ROOT || "(none)"}`);
  console.log(fs.existsSync(WEB_DIR) ? `Serving the web build from ${WEB_DIR}  ->  open http://${HOST}:${PORT}/` : `(no web build at ${WEB_DIR}; the game can still use this relayer from the desktop build)`);
  if (!LIVE) console.log("Dry run: nothing is signed. Set NEAR_ACCOUNT and NEAR_PRIVATE_KEY in server/.env and pass --live to use testnet.");
});

function loadEnv(file) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^"|"$/g, "");
  }
}
