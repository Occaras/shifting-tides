class_name ControlsOverlay
extends CanvasLayer
## The Controls overlay, two read-only pages over any screen: Controls, the list of every action
## with its keys as keycaps (its rows are ControlsNaming's), and Tides, the TideGuide. Each page's
## key opens the overlay on that page, flips to it from the other page and closes it on its own
## page; the steps left and right flip the page and Esc closes it. Open, it takes every press and
## pauses nothing: the screen beneath carries on and may change under it.

enum Page { CONTROLS, TIDES }

const SHOW_INPUT := &"show_controls"
const TIDES_INPUT := &"show_tides"
## Each page's key.
const PAGE_INPUTS: Dictionary[Page, StringName] = {Page.CONTROLS: SHOW_INPUT, Page.TIDES: TIDES_INPUT}
## Flip the page while the overlay is open; closed, they pass to the screen beneath.
const FLIP_INPUTS: Array[StringName] = [&"step_left", &"step_right"]
## Closes the overlay, as a page's key does on its own page: Esc.
const CLOSE_INPUT := &"ui_cancel"
## hud_theme.tres's styles for the current page's tab and the other's.
const TAB_STYLE := &"HudName"
const DIM_TAB_STYLE := &"HudLegend"
## hud_theme.tres's style for a row's label.
const LABEL_STYLE := &"HudName"
## The label whose keys show as inverted-T clusters, one per binding, not in a line.
const CLUSTERED := "MOVE"
## Where a cluster's top cap is among its keys: ControlsNaming lists the steps left, up, down,
## right, so up goes over the other three.
const CLUSTER_TOP := 1
## The gap between a row's keycaps, and between one cluster and the next.
const KEY_GAP := 2
const CLUSTER_GAP := 8
## The gap between a cluster's two rows and between the caps of its bottom row.
const CLUSTER_KEY_GAP := 1

## The page showing, or last shown while closed.
var page := Page.CONTROLS

## The Controls page. Two columns: the header row is in the scene, and _ready adds a row per
## ControlsNaming label, its label then its keys.
@onready var grid: GridContainer = %Grid
## Each page's root, and its tab's label.
@onready var pages: Dictionary[Page, Control] = {Page.CONTROLS: grid, Page.TIDES: %TideGuide}
@onready var tabs: Dictionary[Page, Label] = {Page.CONTROLS: %ControlsTab, Page.TIDES: %TidesTab}


func _ready() -> void:
	# The tab row reads as the flips: the left step's key, the tabs, the right step's key.
	var tab_row := %Tabs as HBoxContainer
	var left := Keycap.create(ControlsNaming.first_key(FLIP_INPUTS[0]), true)
	tab_row.add_child(left)
	tab_row.move_child(left, 0)
	tab_row.add_child(Keycap.create(ControlsNaming.first_key(FLIP_INPUTS[1]), true))
	_show_page()
	for label in ControlsNaming.labels():
		var entry := Label.new()
		entry.text = label
		entry.theme_type_variation = LABEL_STYLE
		entry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(entry)
		grid.add_child(_clusters(label) if label == CLUSTERED else _line(ControlsNaming.keys(label)))


## keys as caps in a line; a label with nothing bound shows an empty cell.
func _line(keys: Array[Key]) -> HBoxContainer:
	var line := _row(KEY_GAP)
	for key in keys:
		line.add_child(Keycap.create(key))
	return line


## label's clusters side by side, each an inverted T: its CLUSTER_TOP cap over the other three.
func _clusters(label: String) -> HBoxContainer:
	var clusters := _row(CLUSTER_GAP)
	for keys in ControlsNaming.clusters(label):
		var cluster := VBoxContainer.new()
		cluster.add_theme_constant_override("separation", CLUSTER_KEY_GAP)
		var top := _row(0)
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		var bottom := _row(CLUSTER_KEY_GAP)
		for i in keys.size():
			(top if i == CLUSTER_TOP else bottom).add_child(Keycap.create(keys[i]))
		cluster.add_child(top)
		cluster.add_child(bottom)
		clusters.add_child(cluster)
	return clusters


static func _row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	return row


## Opens the overlay on `to`, or shows `to` if it is already open.
func open(to: Page) -> void:
	page = to
	_show_page()
	show()


func _show_page() -> void:
	for each: Page in pages:
		pages[each].visible = each == page
		tabs[each].theme_type_variation = TAB_STYLE if each == page else DIM_TAB_STYLE


## _input runs before the select's buttons, Level and Main see an event, so an open overlay takes
## all of them here: keys and the mouse. Only the page keys, the flips and Esc do anything. Closed,
## a page key opens it on its page and everything else passes.
func _input(event: InputEvent) -> void:
	var pressed_page: Variant = null
	for each: Page in PAGE_INPUTS:
		if event.is_action_pressed(PAGE_INPUTS[each]):
			pressed_page = each
	if visible:
		if pressed_page == page or event.is_action_pressed(CLOSE_INPUT):
			hide()
		elif pressed_page != null:
			open(pressed_page)
		elif FLIP_INPUTS.any(func(flip: StringName) -> bool: return event.is_action_pressed(flip)):
			open(Page.TIDES if page == Page.CONTROLS else Page.CONTROLS)
	elif pressed_page != null:
		open(pressed_page)
	else:
		return
	get_viewport().set_input_as_handled()
