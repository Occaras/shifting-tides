class_name ControlsNaming
extends RefCounted
## How the controls are named to the player: a label for each action, and the keys the Input Map
## binds to it, read at runtime so a rebinding in project.godot shows without an edit here. Every
## key the player is shown is a Keycap named by key_name. The Controls overlay shows every label's
## keys, and the HUD's Controls legend, a hint's tokens and the title show first keys.

## The label of every Input Map action a player presses, in the order the overlay lists them;
## actions with one label share a row. The steps go left, up, down, right, so MOVE's first keys
## and every cluster of its keys read as a row of arrows does (← ↑ ↓ →). tests/test_controls_naming.gd
## fails when an action project.godot declares has no label here and is not in HIDDEN.
const LABELS: Dictionary[StringName, String] = {
	&"step_left": "MOVE", &"step_up": "MOVE", &"step_down": "MOVE", &"step_right": "MOVE",
	&"wait": "WAIT",
	&"undo": "UNDO",
	&"restart": "RESTART",
	&"menu": "MENU",
	&"ui_accept": "CONFIRM",
	&"toggle_music": "MUSIC",
	&"toggle_sound": "SOUND",
	&"show_controls": "CONTROLS",
	&"show_tides": "TIDES",
	&"show_settings": "SETTINGS",
}
## The actions project.godot declares that get no row, each on purpose. ui_cancel (Esc) only
## closes the Controls overlay and the Settings panel, as the keys that open them do.
const HIDDEN: Array[StringName] = [&"ui_cancel"]
## The actions the Controls legend names, in its order. Menu is left to the Controls overlay.
const LEGEND_ACTIONS: Array[StringName] = [&"undo", &"restart"]
## Keys named shorter than the engine names them, to fit a keycap. Every other key is its engine
## name in capitals.
const SHORT_NAMES: Dictionary[Key, String] = {KEY_SLASH: "/", KEY_PERIOD: ".", KEY_ESCAPE: "ESC"}


## Every label once, in LABELS order.
static func labels() -> Array[String]:
	var result: Array[String] = []
	for action in LABELS:
		if not result.has(LABELS[action]):
			result.append(LABELS[action])
	return result


## The keys bound to label's actions, in binding order, each once.
static func keys(label: String) -> Array[Key]:
	var result: Array[Key] = []
	for action in _actions(label):
		for key in _keys(action):
			if not result.has(key):
				result.append(key)
	return result


## label's keys as clusters, one per binding: the nth cluster is the nth key of each of label's
## actions, in LABELS order, for every n that each action has. MOVE has two: the arrows and WASD.
static func clusters(label: String) -> Array[Array]:
	var bound: Array[Array] = []
	for action in _actions(label):
		bound.append(_keys(action))
	var result: Array[Array] = []
	var n := 0
	while not bound.is_empty() and bound.all(func(action_keys: Array) -> bool: return n < action_keys.size()):
		var cluster: Array[Key] = []
		for action_keys in bound:
			cluster.append(action_keys[n])
		result.append(cluster)
		n += 1
	return result


## The keys a hint's token draws: the first key of each action whose label is the token in
## capitals, in LABELS order. [wait] is Space; [move] is the four arrows, never WASD. Empty for a
## token that names no label.
static func token_keys(token: String) -> Array[Key]:
	var result: Array[Key] = []
	for action in _actions(token.to_upper()):
		var action_keys := _keys(action)
		if not action_keys.is_empty():
			result.append(action_keys[0])
	return result


## action's first key, or KEY_NONE when nothing is bound to it.
static func first_key(action: StringName) -> Key:
	var action_keys := _keys(action)
	return action_keys[0] if not action_keys.is_empty() else KEY_NONE


## key as a keycap names it: its short name, or its engine name in capitals.
static func key_name(key: Key) -> String:
	return SHORT_NAMES.get(key, OS.get_keycode_string(key).to_upper())


## The actions with label, in LABELS order.
static func _actions(label: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for action in LABELS:
		if LABELS[action] == label:
			result.append(action)
	return result


## The keys bound to action, in binding order.
static func _keys(action: StringName) -> Array[Key]:
	var result: Array[Key] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append((event as InputEventKey).physical_keycode)
	return result
