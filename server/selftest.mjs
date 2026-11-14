// Checks that a running relayer is healthy and can settle a transfer.
//
//   node server/relayer.mjs            (in one terminal)
//   node server/selftest.mjs           (in another)  [URL=http://host:port]
//
// In dry-run mode this proves the HTTP flow. In --live mode it sends two
// tiny real testnet transfers and prints their nearblocks.io links.

const URL_BASE = process.env.URL || "http://127.0.0.1:8787";

async function call(method, path, body) {
  const r = await fetch(URL_BASE + path, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { code: r.status, data: await r.json() };
}

function check(name, ok, extra = "") {
  console.log(`${ok ? "PASS" : "FAIL"}  ${name} ${extra}`);
  if (!ok) process.exitCode = 1;
}

try {
  const health = await call("GET", "/health");
  check("health", health.data.ok === true);

  const status = await call("GET", "/status");
  check("status", ["dry-run", "testnet"].includes(status.data.mode), `mode=${status.data.mode} network=${status.data.network} account=${status.data.account}`);

  const ledger = { "selftest-a": 50, "selftest-b": 10 };
  const genesis = await call("POST", "/genesis", { ledger });
  check("genesis creates sub-accounts", genesis.data.ok === true, `created=${genesis.data.created}`);

  const settle = await call("POST", "/settle", { day: 0, flows: [{ from: "selftest-a", to: "selftest-b", amount: 3 }], ledger });
  check("settle one transfer", settle.data.ok === true && settle.data.txs.length === 1);
  for (const t of settle.data.txs) {
    console.log(`      ${t.from} -> ${t.to}  ${t.amount} coins  ${t.url || (t.hash ? t.hash : "(dry run, nothing signed)")}`);
  }

  const bad = await call("POST", "/settle", { day: 0, flows: [{ from: "x", to: "y", amount: -5 }, { from: 1, to: "y", amount: 2 }], ledger: {} });
  check("rejects malformed flows", bad.data.ok === true && bad.data.txs.length === 0);
} catch (e) {
  console.log(`FAIL  could not reach ${URL_BASE}: ${e.message}`);
  console.log("      Start the relayer first:  node server/relayer.mjs");
  process.exitCode = 1;
}
