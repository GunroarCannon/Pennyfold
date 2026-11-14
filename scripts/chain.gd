## Autoload "Chain": puts the town's money on NEAR without the player ever
## seeing a wallet popup. Every coin movement in Economy is recorded; at the
## end of each game day the net flows between wallets are sent to the
## relayer (server/relayer.mjs), which signs NEAR transfers between the
## town's sub-accounts (one per shop, townsperson, treasury, quest escrow
## and the player). If no relayer is running, the game keeps a local ledger
## and says so in the HUD.
## Relayer URL: env FOLDED_RELAYER, arg --relayer=, default localhost:8787.
extends Node

signal status_changed

var url := "http://127.0.0.1:8787"
## "offline" (no relayer), "dry-run" (relayer signs nothing) or "testnet".
var mode := "offline"
var network := ""
var root_account := ""
var day_log: Array = []
var pending: Array = []
var last_error := ""
var genesis_done := false
## The player's own wallet, once the relayer has confirmed it ("" = guest).
var linked_account := ""
var linked_ok := false
## Human-readable result of the last link attempt, shown on the title screen.
var link_note := ""
var _queue: Array = []
var _http: HTTPRequest
var _busy := false
var _main: Node


func _ready() -> void:
	var env := OS.get_environment("FOLDED_RELAYER")
	if env != "":
		url = env
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relayer="):
			url = a.substr(10)
	if OS.has_feature("web"):
		# In the browser the page is normally served by the relayer itself (same
		# origin). ?relayer=http://host:port points it somewhere else.
		var q := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('relayer') || ''"))
		url = q if q != "" else str(JavaScriptBridge.eval("window.location.origin"))
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	Economy.transferred.connect(_on_transfer)


var _retry := 0.0


## While no relayer answers, look again every few seconds so starting it after
## the game works too.
func _process(delta: float) -> void:
	_poll_web()
	if mode != "offline" or _main == null:
		return
	_retry -= delta
	if _retry <= 0.0:
		_retry = 8.0
		if not _busy and _queue.is_empty():
			_send("GET", "/status", {}, "status")


func attach(main: Node) -> void:
	_main = main
	pending.clear()
	day_log.clear()
	genesis_done = false
	_send("GET", "/status", {}, "status")


## Ask the relayer to check the player's wallet. Winnings paid to the player in
## a settlement then go to this account. A failure only leaves the player a guest.
func link(account: String) -> void:
	linked_ok = false
	linked_account = account
	if account == "":
		link_note = ""
		status_changed.emit()
		return
	if not Game.valid_account(account):
		link_note = "That does not look like a testnet account (name.testnet)."
		status_changed.emit()
		return
	link_note = "Checking %s..." % account
	status_changed.emit()
	_send("POST", "/link", {"account_id": account}, "link")


func _on_transfer(from_id: String, to_id: String, amount: int, memo: String) -> void:
	if amount <= 0 or from_id == to_id:
		return
	pending.append({"from": from_id, "to": to_id, "amount": amount, "memo": memo})


## Nets the day's transfers per pair of wallets and sends them for settlement.
func end_of_day(day: int) -> void:
	var raw := pending.size()
	var net := {}
	for t in pending:
		var a: String = t["from"]
		var b: String = t["to"]
		var key := a + "|" + b if a < b else b + "|" + a
		var sgn := 1 if a < b else -1
		net[key] = int(net.get(key, 0)) + int(t["amount"]) * sgn
	pending.clear()
	var flows: Array = []
	for key in net:
		var v := int(net[key])
		if v == 0:
			continue
		var ab: PackedStringArray = String(key).split("|")
		flows.append({"from": ab[0] if v > 0 else ab[1], "to": ab[1] if v > 0 else ab[0], "amount": absi(v)})
	var entry := {"day": day, "raw": raw, "flows": flows.size(), "status": "local", "txs": []}
	day_log.append(entry)
	if mode == "offline":
		status_changed.emit()
		return
	entry["status"] = "sending"
	_send("POST", "/settle", {"day": day, "flows": flows, "ledger": _ledger(), "player_account": linked_account if linked_ok else ""}, "settle", entry)
	status_changed.emit()


func _ledger() -> Dictionary:
	var out := {}
	for id in Economy.wallets:
		out[id] = int(Economy.wallets[id]["coins"])
	return out


## One short line for the HUD chip.
func chip_text() -> String:
	var who := ("  [%s]" % linked_account) if linked_ok else ""
	return _chip_core() + who


func _chip_core() -> String:
	match mode:
		"offline":
			return "Offline ledger"
		"dry-run":
			return "NEAR dry run - %d queued" % pending.size()
	var last := -1
	for e in day_log:
		if e["status"] == "settled":
			last = int(e["day"])
	for e in day_log:
		if e["status"] == "sending":
			return "NEAR %s - settling..." % network
	return "NEAR %s - %s" % [network, "day %d settled" % last if last >= 0 else "linked"]


func explorer_base() -> String:
	return "https://testnet.nearblocks.io"


## Settle everything that happened so far right now (a game day lasts minutes).
func settle_now(main: Node) -> void:
	if mode == "offline":
		Economy.message.emit("No relayer found at %s. Start one with: node server/relayer.mjs" % url)
		_send("GET", "/status", {}, "status")
		return
	if pending.is_empty():
		Economy.message.emit("Nothing to settle yet. Buy, sell or get paid first, then settle the day.")
		return
	Economy.message.emit("Settling the town's coin flows on NEAR...")
	end_of_day(main.day_number())


func open_explorer() -> void:
	if mode != "testnet" or root_account in ["", "(none)"]:
		Economy.message.emit("Live testnet mode is off. Run the relayer with --live and keys in server/.env, then transactions get explorer links.")
		return
	OS.shell_open("%s/address/%s" % [explorer_base(), root_account])


func open_last_tx() -> void:
	for i in range(day_log.size() - 1, -1, -1):
		for t in day_log[i].get("txs", []):
			if typeof(t) == TYPE_DICTIONARY and String(t.get("hash", "")) != "":
				OS.shell_open("%s/txns/%s" % [explorer_base(), t["hash"]])
				return
	Economy.message.emit("No on-chain transaction yet. Press Settle day now in the ledger (Tab) after some trading.")


func summary() -> String:
	match mode:
		"offline":
			return "Ledger: local only (no relayer)"
		"dry-run":
			return "NEAR relayer: dry run, nothing signed"
	var last := "no day settled yet"
	for i in range(day_log.size() - 1, -1, -1):
		if day_log[i]["status"] == "settled":
			last = "day %d settled, %d transfers" % [int(day_log[i]["day"]), int(day_log[i]["flows"])]
			break
	return "NEAR %s: %s" % [network, last]


func _send(method: String, path: String, body: Dictionary, kind: String, entry: Dictionary = {}) -> void:
	_queue.append([method, path, body, kind, entry])
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	var job: Array = _queue.pop_front()
	_busy = true
	if OS.has_feature("web"):
		_web_fetch(job)
		return
	var m := HTTPClient.METHOD_GET if job[0] == "GET" else HTTPClient.METHOD_POST
	var headers := PackedStringArray(["Content-Type: application/json"]) if m == HTTPClient.METHOD_POST else PackedStringArray()
	_http.set_meta("job", job)
	var err := _http.request(url + job[1], headers, m, JSON.stringify(job[2]) if m == HTTPClient.METHOD_POST else "")
	if err != OK:
		_busy = false
		_fail(job, "request error %d" % err)


## In the browser the request goes through the page's own fetch(), which does
## not depend on the game's frame rate or on the wasm HTTP client.
var _web_id := 0
var _web_job: Array = []


func _web_fetch(job: Array) -> void:
	_web_id += 1
	_web_job = job
	var body := JSON.stringify(job[2]) if job[0] == "POST" else ""
	var js := "window._ff = window._ff || {}; window._ff[%d] = {done: false};" % _web_id
	js += "fetch(%s, {method: %s%s}).then(function(r){ return r.text().then(function(t){ window._ff[%d] = {done: true, code: r.status, body: t}; }); })" % [
		JSON.stringify(url + job[1]), JSON.stringify(job[0]),
		(", headers: {'Content-Type': 'application/json'}, body: %s" % JSON.stringify(body)) if job[0] == "POST" else "", _web_id]
	js += ".catch(function(e){ window._ff[%d] = {done: true, code: 0, body: String(e)}; });" % _web_id
	JavaScriptBridge.eval(js, true)


func _poll_web() -> void:
	if _web_job.is_empty():
		return
	if not bool(JavaScriptBridge.eval("window._ff[%d].done" % _web_id, true)):
		return
	var code := int(JavaScriptBridge.eval("window._ff[%d].code" % _web_id, true))
	var text := str(JavaScriptBridge.eval("window._ff[%d].body" % _web_id, true))
	var job := _web_job
	_web_job = []
	_handle(job, HTTPRequest.RESULT_SUCCESS if code > 0 else HTTPRequest.RESULT_CANT_CONNECT, code, text)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle(_http.get_meta("job"), result, code, body.get_string_from_utf8())


func _handle(job: Array, result: int, code: int, text: String) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		print("[Chain] http result=%d code=%d" % [result, code])
		_fail(job, "relayer unreachable" if result != HTTPRequest.RESULT_SUCCESS else "HTTP %d" % code)
		_pump()
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail(job, "bad reply")
		_pump()
		return
	match String(job[3]):
		"status":
			print("[Chain] relayer at %s: %s" % [url, str(data)])
			mode = String(data.get("mode", "dry-run"))
			network = String(data.get("network", "testnet"))
			root_account = String(data.get("account", ""))
			Economy.message.emit("Town ledger linked to NEAR %s (%s)." % [network, mode])
			_send("POST", "/genesis", {"ledger": _ledger()}, "genesis")
			if Game.account != "" and not linked_ok:
				link(Game.account)
		"genesis":
			genesis_done = true
		"link":
			linked_ok = bool(data.get("ok", false))
			link_note = ("Linked %s. Winnings paid to you settle there." % linked_account) if linked_ok else str(data.get("note", "Could not verify that account. Playing as a guest."))
			if not linked_ok:
				linked_account = ""
		"settle":
			var entry: Dictionary = job[4]
			entry["status"] = "settled" if data.get("ok", false) else "failed"
			entry["txs"] = data.get("txs", [])
			if entry["status"] == "settled":
				Economy.message.emit("Day %d settled on NEAR: %d transfers." % [int(entry["day"]), int(entry["flows"])])
	status_changed.emit()
	_pump()


func _fail(job: Array, why: String) -> void:
	last_error = why
	print("[Chain] %s failed: %s (%s)" % [job[3], why, url])
	if job[3] == "link":
		linked_ok = false
		link_note = "No relayer to check the account yet. Playing as a guest."
	if job[3] == "status":
		mode = "offline"
	elif job[3] == "settle":
		job[4]["status"] = "failed"
	status_changed.emit()
