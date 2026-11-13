class_name SettingsPanel
extends CanvasLayer
## The Settings panel: a music and a sound Volume slider, which show_settings opens and closes over
## any screen. Open, it takes every press, as the Controls overlay does, except the mutes, which pass
## to Main and still work. Up and down pick a row, left and right move its slider a step. It keeps
## no settings of its own: it draws Main's and asks Main for each change with volume_changed.

## Asks for bus's volume to become volume: Main sets it, applies it, saves it and calls refresh.
signal volume_changed(bus: StringName, volume: int)

const SHOW_INPUT := &"show_settings"
## Closes the panel, as show_settings does: Esc.
const CLOSE_INPUT := &"ui_cancel"
## The steps' inputs: the move keys, so the arrows and WASD both work.
const PREVIOUS_ROW_INPUT := &"step_up"
const NEXT_ROW_INPUT := &"step_down"
const QUIETER_INPUT := &"step_left"
const LOUDER_INPUT := &"step_right"
## The presses an open panel lets through: the mutes, which Main answers on every screen.
const PASSING_INPUTS: Array[StringName] = [Main.TOGGLE_MUSIC_INPUT, Main.TOGGLE_SOUND_INPUT]
## Each row's bus and its label, top to bottom.
const ROWS: Dictionary[StringName, String] = {Settings.MUSIC_BUS: "MUSIC", Settings.SOUND_BUS: "SOUND"}
## The tag a muted row shows.
const MUTED := "MUTED"
## hud_theme.tres's styles for a row's label and for the dimmer MUTED tag.
const LABEL_STYLE := &"HudName"
const TAG_STYLE := &"HudLegend"
const STEP_ON := preload("res://assets/generated/ui/volume_step_on.png")
const STEP_OFF := preload("res://assets/generated/ui/volume_step_off.png")
## The marker beside the selected row: the right arrow's light icon, which reads on the panel's ink
## face (the hint cap's own arrow is ink).
const MARKER := preload("res://assets/generated/hud/keycap_arrow_right_legend.png")
const STEP_GAP := 1

## The Controls overlay: neither opens over the other. Set in the editor by whoever owns both.
@export var controls: ControlsOverlay
## Main's settings, which the panel draws and never writes. Set by Main before the panel opens.
var settings: Settings
## The selected row's bus.
var selected := Settings.MUSIC_BUS

## Four columns: a row's marker, label, steps and MUTED tag. _ready adds a row per ROWS entry.
@onready var grid: GridContainer = %Grid
var _markers: Dictionary[StringName, TextureRect] = {}
var _steps: Dictionary[StringName, Array] = {}
var _tags: Dictionary[StringName, Label] = {}


func _ready() -> void:
	for bus in ROWS:
		var marker := TextureRect.new()
		marker.texture = MARKER
		marker.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_markers[bus] = marker
		grid.add_child(marker)
		grid.add_child(_label(ROWS[bus], LABEL_STYLE))
		var steps := HBoxContainer.new()
		steps.add_theme_constant_override("separation", STEP_GAP)
		var rects: Array[TextureRect] = []
		for step in Settings.FULL_VOLUME:
			var rect := TextureRect.new()
			rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			steps.add_child(rect)
			rects.append(rect)
		_steps[bus] = rects
		grid.add_child(steps)
		_tags[bus] = _label(MUTED, TAG_STYLE)
		grid.add_child(_tags[bus])
	refresh()


## Redraws every row from settings: the marker on the selected row, each slider's lit steps and
## each MUTED tag. A hidden cell would shift the grid, so what is off is clear, not hidden.
func refresh() -> void:
	for bus in ROWS:
		_markers[bus].self_modulate.a = 1.0 if bus == selected else 0.0
		var volume := settings.volume_of(bus) if settings != null else Settings.FULL_VOLUME
		var rects: Array = _steps[bus]
		for step in rects.size():
			(rects[step] as TextureRect).texture = STEP_ON if step < volume else STEP_OFF
		_tags[bus].self_modulate.a = 1.0 if settings != null and settings.is_muted(bus) else 0.0


## How many of bus's slider steps are lit.
func lit_steps(bus: StringName) -> int:
	return (_steps[bus] as Array).filter(func(rect: TextureRect) -> bool: return rect.texture == STEP_ON).size()


## Whether bus's row shows its MUTED tag.
func shows_muted(bus: StringName) -> bool:
	return _tags[bus].self_modulate.a > 0.0


## Whether bus's row is marked as the selected one.
func shows_selected(bus: StringName) -> bool:
	return _markers[bus].self_modulate.a > 0.0


func open() -> void:
	refresh()
	show()


## _input runs before Level, the select and Main see an event; Main's scene puts the panel after
## the Controls overlay, so the panel sees each event first. Open, it takes every event but the
## mutes; closed, show_settings opens it unless the overlay is up, and everything else passes.
func _input(event: InputEvent) -> void:
	if visible:
		if PASSING_INPUTS.any(func(input: StringName) -> bool: return event.is_action(input)):
			return
		if event.is_action_pressed(SHOW_INPUT) or event.is_action_pressed(CLOSE_INPUT):
			hide()
		elif event.is_action_pressed(PREVIOUS_ROW_INPUT):
			_select(-1)
		elif event.is_action_pressed(NEXT_ROW_INPUT):
			_select(1)
		elif event.is_action_pressed(QUIETER_INPUT):
			_nudge(-1)
		elif event.is_action_pressed(LOUDER_INPUT):
			_nudge(1)
	elif event.is_action_pressed(SHOW_INPUT) and not (controls != null and controls.visible):
		open()
	else:
		return
	get_viewport().set_input_as_handled()


## Moves the selection by rows, stopping at the top and bottom.
func _select(by: int) -> void:
	var buses := ROWS.keys()
	selected = buses[clampi(buses.find(selected) + by, 0, buses.size() - 1)]
	refresh()


## Asks for the selected slider one step up or down; nothing at its ends.
func _nudge(by: int) -> void:
	if settings == null:
		return
	var volume := settings.volume_of(selected)
	var next := clampi(volume + by, 0, Settings.FULL_VOLUME)
	if next != volume:
		volume_changed.emit(selected, next)


static func _label(text: String, style: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = style
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
