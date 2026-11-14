## The shared world. Connects to the Pennyfold world server (server/world_server.mjs)
## over WebSocket, takes the world seed and day clock from it so every player
## generates the same valley, and shows other players as live standees.
## NPCs and the economy still run on each client; only players are shared.
## If the server cannot be reached the game just plays offline.
class_name Net
extends Node

signal chat_received(who: String, text: String)

const SEND_EVERY := 0.1
const WORLD_PORT := 8788

var main: Node3D
var ws := WebSocketPeer.new()
var online := false
var my_id := 0
var seed_value := 0
var clock_value := 0.0
var typing := false
## id -> {"name", "look", "view": Standee, "pos", "target", "dir"}
var remotes := {}

var _welcomed := false
var _opened := false
var _send_t := 0.0
var _last_sent := Vector2(1e9, 1e9)
var _last_dir := Vector2.ZERO
var _heartbeat := 0.0
var _box: LineEdit


## The server address: --world=ws://host:port, window.pennyfold.world, or on the
## web the page's own host. Desktop plays offline unless --world= is given.
static func default_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--world="):
			return a.substr(8)
		if a == "--offline":
			return ""
	if OS.has_feature("web"):
		var v := str(JavaScriptBridge.eval("(window.pennyfold && window.pennyfold.world) || ''"))
		if v != "":
			return v
		var host := str(JavaScriptBridge.eval("location.hostname"))
		var secure := bool(JavaScriptBridge.eval("location.protocol === 'https:'"))
		return ("wss://%s/world" % host) if secure else ("ws://%s:%d" % [host, WORLD_PORT])
	return ""


## Connects and waits for the server's welcome. Returns false (play offline) on
## no address, no answer within `timeout` seconds, or a refusal.
func join(m: Node3D, timeout := 4.0) -> bool:
	main = m
	var url := default_url()
	if url == "":
		return false
	if ws.connect_to_url(url) != OK:
		return false
	var t := 0.0
	while t < timeout and not _welcomed:
		await get_tree().process_frame
		t += get_process_delta_time()
		_pump()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not _opened:
			_opened = true
			_send({"t": "hello", "name": _name(), "look": _hero()})
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
	if not _welcomed:
		ws.close()
		return false
	online = true
	return true


func _ready() -> void:
	_build_chat()


func _name() -> String:
	return str(Game.hero.get("name", "Traveller"))


## Only plain numbers cross the wire; each client rebuilds the look from them.
func _hero() -> Dictionary:
	var h: Dictionary = Game.hero
	return {"skin": int(h.get("skin", 0)), "hair": int(h.get("hair", 0)), "cloth": int(h.get("cloth", 0)), "style": int(h.get("style", 0)), "equip": (h.get("equip", {}) as Dictionary).duplicate()}


func send_look() -> void:
	if online:
		_send({"t": "look", "name": _name(), "look": _hero()})


func _send(o: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(o))


func _pump() -> void:
	ws.poll()
	while ws.get_available_packet_count() > 0:
		var v: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if v is Dictionary:
			_on(v)


func _on(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"welcome":
			my_id = int(m["id"])
			seed_value = int(m["seed"])
			clock_value = float(m["clock"])
			_welcomed = true
			print("[Net] joined as #%d, seed %d, %d others" % [my_id, seed_value, (m.get("players", []) as Array).size()])
			for p in m.get("players", []):
				_add_remote(p)
		"join":
			_add_remote(m)
			_log("%s joined the town." % str(m.get("name", "Someone")))
		"leave":
			var r: Dictionary = remotes.get(int(m["id"]), {})
			if not r.is_empty():
				_log("%s left." % r["name"])
				_drop(int(m["id"]))
		"look":
			var id := int(m["id"])
			if remotes.has(id):
				var pos: Vector2 = remotes[id]["pos"]
				_drop(id)
				m["x"] = pos.x
				m["y"] = pos.y
				_add_remote(m)
		"state":
			for s in m.get("p", []):
				var r2: Dictionary = remotes.get(int(s[0]), {})
				if not r2.is_empty():
					r2["target"] = Vector2(float(s[1]), float(s[2]))
					r2["dir"] = Vector2(float(s[3]), float(s[4]))
		"chat":
			_on_chat(int(m["id"]), str(m.get("name", "?")), str(m.get("text", "")))
		"raid":
			if main != null and main.ready_done:
				main.raid_update(m)
			else:
				_pending_raid = m


func _log(text: String) -> void:
	if main != null and main.get("hud") != null:
		main.hud.add_log(text)


## Remote players that arrive before the world has finished building are queued
## in `_pending` and made once main calls `flush_pending()`.
var _pending: Array = []


var _pending_raid: Dictionary = {}


## Tells the server one of the local player's hits landed on the raid dragon.
func raid_hit(dmg: float) -> void:
	if online:
		_send({"t": "raid_hit", "dmg": dmg})


func flush_pending() -> void:
	if not _pending_raid.is_empty():
		main.raid_update(_pending_raid)
		_pending_raid = {}
	var p := _pending
	_pending = []
	for d in p:
		_add_remote(d)


func _add_remote(p: Dictionary) -> void:
	var id := int(p["id"])
	if id == my_id or remotes.has(id):
		return
	if main == null or not main.ready_done:
		_pending.append(p)
		return
	var h: Dictionary = p.get("look", {})
	var draft := {"skin": int(h.get("skin", 0)), "hair": int(h.get("hair", 0)), "cloth": int(h.get("cloth", 0)), "style": int(h.get("style", 0)), "equip": {}}
	var he: Variant = h.get("equip", {})
	if he is Dictionary:
		for slot in he:
			if Gear.ITEMS.has(str(he[slot])):  # only known items cross the wire
				draft["equip"][str(slot)] = str(he[slot])
	var nm := str(p.get("name", "Traveller"))
	var v: Standee = main._make_standee(main._bake_person(main.hero_look(draft), Vector2i(256, 320)), 1.75 if main.cute else 2.3, nm)
	v.show_hp = false
	var at := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	print("[Net] player %s appeared" % nm)
	remotes[id] = {"name": nm, "look": h, "view": v, "pos": at, "target": at, "dir": Vector2.ZERO}


func _drop(id: int) -> void:
	var r: Dictionary = remotes.get(id, {})
	if r.is_empty():
		return
	if is_instance_valid(r["view"]):
		r["view"].queue_free()
	remotes.erase(id)


func _on_chat(id: int, who: String, text: String) -> void:
	_log("%s: %s" % [who, text])
	if id == my_id:
		main.player_view.say(text, 4.0)
	elif remotes.has(id) and is_instance_valid(remotes[id]["view"]):
		remotes[id]["view"].say(text, 4.0)
	chat_received.emit(who, text)


## Called every frame by main with the local player's position and heading.
func tick(delta: float, pos: Vector2, dir: Vector2) -> void:
	if not online:
		return
	_pump()
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_lost()
		return
	_send_t += delta
	_heartbeat += delta
	if _send_t >= SEND_EVERY:
		_send_t = 0.0
		if pos.distance_to(_last_sent) > 0.5 or dir != _last_dir or _heartbeat > 1.0:
			_send({"t": "pos", "x": pos.x, "y": pos.y, "dx": dir.x, "dy": dir.y})
			_last_sent = pos
			_last_dir = dir
			_heartbeat = 0.0
	_update_remotes(delta)


func _update_remotes(delta: float) -> void:
	var right: Vector2 = main._cam_right()
	for id in remotes:
		var r: Dictionary = remotes[id]
		var v: Standee = r["view"]
		if not is_instance_valid(v):
			continue
		var before: Vector2 = r["pos"]
		var target: Vector2 = r["target"]
		r["pos"] = before.lerp(target, 1.0 - exp(-10.0 * delta))
		var step: Vector2 = r["pos"] - before
		var moving := 1.0 if step.length() > 0.02 else 0.0
		var hd: Vector2 = r["dir"] if (r["dir"] as Vector2).length() > 0.05 else step
		v.position = Bend.at(main._to3(r["pos"]))
		v.rotation.y = main.cam_yaw
		if absf(hd.dot(right)) > 0.2:
			v.facing = signf(hd.dot(right))
		main._pick_view(v, hd, moving > 0.0, true)
		v.animate(delta, moving)


func _lost() -> void:
	online = false
	for id in remotes.keys():
		_drop(id)
	_log("Lost the shared world. Playing on alone.")


# ---- chat box (Enter to talk, Enter to send, Esc to cancel) ----

func _build_chat() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_box = LineEdit.new()
	_box.placeholder_text = "Say something (Enter to send)"
	_box.max_length = 140
	_box.visible = false
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -220
	_box.offset_right = 220
	_box.offset_top = -64
	_box.offset_bottom = -28
	_box.text_submitted.connect(_submit)
	_box.gui_input.connect(_box_input)
	layer.add_child(_box)


func _unhandled_input(ev: InputEvent) -> void:
	if not online or typing or main == null or not main.ready_done:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER] and not main.hud.blocking():
		typing = true
		_box.text = ""
		_box.visible = true
		_box.grab_focus()
		get_viewport().set_input_as_handled()


func _box_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_close_box()
		_box.accept_event()


func _submit(text: String) -> void:
	var t := text.strip_edges()
	if t != "":
		_send({"t": "chat", "text": t})
	_close_box()


func _close_box() -> void:
	typing = false
	_box.visible = false
	_box.release_focus()
