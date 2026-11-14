// Two fake clients join, move, chat. Run: node selftest_world.mjs (starts its own server on :8799)
import { spawn } from "node:child_process";
import net from "node:net";
import crypto from "node:crypto";
const srv = spawn("node", ["world_server.mjs"], { env: { ...process.env, PORT: "8799", SEED: "42" }, stdio: "ignore" });
await new Promise((r) => setTimeout(r, 500));
function client(name) {
  return new Promise((res) => {
    const s = net.connect(8799, "127.0.0.1");
    const msgs = [];
    s.write("GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: " + crypto.randomBytes(16).toString("base64") + "\r\nSec-WebSocket-Version: 13\r\n\r\n");
    let up = false;
    s.on("data", (d) => {
      let b = d;
      if (!up) { up = true; b = d.subarray(d.indexOf("\r\n\r\n") + 4); s.send = (o) => { const p = Buffer.from(JSON.stringify(o)); const m = crypto.randomBytes(4); s.write(Buffer.concat([Buffer.from([0x81, 0x80 | p.length]), m, Buffer.from(p.map((x, i) => x ^ m[i % 4]))])); }; res({ s, msgs, name }); }
      while (b.length > 1) { let l = b[1], o = 2; if (l === 126) { l = b.readUInt16BE(2); o = 4; } msgs.push(JSON.parse(b.subarray(o, o + l).toString())); b = b.subarray(o + l); }
    });
  });
}
const a = await client("A"); a.s.send({ t: "hello", name: "Ann", look: { hat: 1 } });
await new Promise((r) => setTimeout(r, 150));
const b = await client("B"); b.s.send({ t: "hello", name: "Bob", look: {} });
await new Promise((r) => setTimeout(r, 150));
a.s.send({ t: "pos", x: 10, y: 20, dx: 1, dy: 0 }); a.s.send({ t: "chat", text: "hi" });
await new Promise((r) => setTimeout(r, 300));
const ok = [
  b.msgs.find((m) => m.t === "welcome")?.seed === 42,
  b.msgs.find((m) => m.t === "welcome")?.players[0]?.name === "Ann",
  a.msgs.some((m) => m.t === "join" && m.name === "Bob"),
  b.msgs.some((m) => m.t === "state" && m.p[0][1] === 10),
  a.msgs.some((m) => m.t === "state") === false,
  b.msgs.some((m) => m.t === "chat" && m.text === "hi"),
  a.msgs.some((m) => m.t === "chat" && m.text === "hi"),
];
console.log(ok.every(Boolean) ? "PASS" : "FAIL " + JSON.stringify(ok));
srv.kill(); process.exit(ok.every(Boolean) ? 0 : 1);
