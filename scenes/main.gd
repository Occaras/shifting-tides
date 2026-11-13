class_name Main
extends Node2D
## The project's main scene and the flow between screens: the title, the level select, the one
## Level being played, and the LevelComplete card after a win, which then starts the next level
## (or returns to the select after the last). Nothing is instantiated or freed between levels.

enum Mode { TITLE, SELECT, PLAYING, COMPLETE }

## Returns to the select from a level or from the card, and to the title from the select.
const MENU_INPUT := &"menu"
## Mute and unmute music and sound, on every screen.
const TOGGLE_MUSIC_INPUT := &"toggle_music"
const TOGGLE_SOUND_INPUT := &"toggle_sound"
## The notice each toggle shows.
const MUSIC_OFF := "MUSIC OFF"
const MUSIC_ON := "MUSIC ON"
const SOUND_OFF := "SOUND OFF"
const SOUND_ON := "SOUND ON"
## Seconds between the win and the card, for the win pose.
const WIN_POSE_SECONDS := 0.4
## Seconds the card shows before the next level starts.
const CARD_SECONDS := 1.6
## A few mix periods of the audio driver. A freed player's playback stays in the AudioServer until
## the mix thread retires it, which takes real time (stop() and extra frames do not do it);
## quitting sooner reports leaked ObjectDB instances and resources still in use at exit.
const AUDIO_DRAIN_MSEC := 100

## Where progress is loaded from and saved to; set before Main enters the tree (tests use a
## scratch path).
var save_path := Progress.PATH
## Where the settings are loaded from and saved to; set before Main enters the tree, as save_path.
var settings_path := Settings.PATH
## The level files to offer, in level order; set before Main enters the tree (tests inject a bad
## one). A file that does not load is left out with an error.
var level_paths := LevelLoader.level_paths()
var mode := Mode.TITLE
## The levels that loaded, in level_paths order.
var levels: Array[LevelData] = []
var progress: Progress
## The player's mutes and volumes: loaded and applied in _enter_tree, saved on every change.
var settings: Settings
## Index into levels of the level being played, or last played.
var current := 0
## Whether this run has opened the tide guide by itself yet: it does once, the first time the first
## level starts while it is unbeaten.
var _offered_tide_guide := false
## The running (or last) win pose and card beat, which ends in the advance; public so tests can
## custom_step it.
var beat: Tween

@onready var level: Level = %Level
@onready var level_select: LevelSelect = %LevelSelect
@onready var level_complete: LevelComplete = %LevelComplete
@onready var title: TitleScreen = %Title
@onready var music: AudioStreamPlayer = $Music
@onready var notice: Notice = %Notice
@onready var controls: ControlsOverlay = %ControlsOverlay
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var sfx: Sfx = $Sfx


## Before any child enters the tree, so the saved mutes are on their buses before Music autoplays.
func _enter_tree() -> void:
	settings = Settings.load_file(settings_path)
	settings.apply()


func _ready() -> void:
	for path in level_paths:
		var loaded := LevelLoader.load_playable(path)
		if loaded != null:
			levels.append(loaded)
	progress = Progress.load_file(save_path)
	_warn_of_bests_below_par()
	level.action_resolved.connect(_on_action_resolved)
	level_select.level_chosen.connect(_on_level_chosen)
	title.left.connect(_on_title_left)
	settings_panel.settings = settings
	settings_panel.refresh()
	settings_panel.volume_changed.connect(_on_volume_changed)
	_enter_title()


## The game quits by freeing Main, its current scene, with the soundtrack playing: stop it and let
## the mix thread retire the playback. A Main that tests and smokes add to root is not the current
## scene and skips the wait; the tools that free one drain once themselves before they quit.
func _exit_tree() -> void:
	music.stop()
	if get_tree().current_scene == self:
		drain_audio()


## Call before quit when a freed player may still have been playing: see AUDIO_DRAIN_MSEC.
static func drain_audio() -> void:
	OS.delay_msec(AUDIO_DRAIN_MSEC)


## Level and the title see each event first; each takes only its own inputs, so the toggles reach
## here from every screen, and menu from the select, a level or the card.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_MUSIC_INPUT):
		settings.music_muted = not settings.music_muted
		_confirm_toggle(MUSIC_OFF if settings.music_muted else MUSIC_ON)
	elif event.is_action_pressed(TOGGLE_SOUND_INPUT):
		settings.sound_muted = not settings.sound_muted
		_confirm_toggle(SOUND_OFF if settings.sound_muted else SOUND_ON)
	elif mode != Mode.TITLE and event.is_action_pressed(MENU_INPUT):
		if mode == Mode.SELECT:
			_enter_title()
		else:
			_enter_select(current)
	else:
		return
	get_viewport().set_input_as_handled()


## Every transition comes through here: it sets mode and takes down whatever next does not show,
## so each _enter_* starts only its own mode. The title, the select and the card each belong to one
## mode. The level is on screen and running in PLAYING and COMPLETE (its last glide finishes under
## the card) and takes input only in PLAYING; off screen it is stopped, and so is the beat. PLAYING
## leaves the beat be, for _advance enters it from the beat's last step.
func _change_mode(next: Mode) -> void:
	mode = next
	if next != Mode.TITLE:
		title.close()
	if next != Mode.SELECT:
		level_select.hide()
	if next != Mode.COMPLETE:
		level_complete.hide()
	match next:
		Mode.TITLE, Mode.SELECT:
			if beat:
				beat.kill()
			level.hide()
			level.process_mode = Node.PROCESS_MODE_DISABLED
		Mode.PLAYING, Mode.COMPLETE:
			level.process_mode = Node.PROCESS_MODE_INHERIT
			level.set_process_unhandled_input(next == Mode.PLAYING)


## Opens the title at rest.
func _enter_title() -> void:
	_change_mode(Mode.TITLE)
	title.open()


## Shows the select refreshed from progress, focused at once on index (or the highest unlocked
## level below it). A Space held over from play arrives as echoes, which the slots ignore.
func _enter_select(index: int) -> void:
	_change_mode(Mode.SELECT)
	level_select.setup(levels, progress)
	level_select.show()
	level_select.focus_level(index)


## Sets up levels[current] and shows it. Hiding the select drops its focus, so Space is a wait
## again. The first level, unbeaten, opens the tide guide over itself once a run.
func _enter_playing() -> void:
	_change_mode(Mode.PLAYING)
	level.setup(levels[current])
	level.show()
	if current == 0 and not _offered_tide_guide and progress.best_for(levels[0].id) == Progress.UNBEATEN:
		_offered_tide_guide = true
		controls.open(ControlsOverlay.Page.TIDES)


## Records and saves the win, then runs the beat: the win pose, the card, the advance. Level locks
## its own actions after a win but still takes restart, so its input is off for the card.
func _enter_complete(actions: int) -> void:
	_change_mode(Mode.COMPLETE)
	var is_new_best := progress.record(levels[current].id, actions)
	progress.save(save_path)
	beat = create_tween()
	beat.tween_interval(WIN_POSE_SECONDS)
	beat.tween_callback(level_complete.show_result.bind(levels[current], actions, is_new_best))
	beat.tween_interval(CARD_SECONDS)
	beat.tween_callback(_advance)


func _advance() -> void:
	if current + 1 < levels.size():
		current += 1
		_enter_playing()
	else:
		_enter_select(current)


func _on_level_chosen(index: int) -> void:
	current = index
	_enter_playing()


## The wave has wiped the title: the select opens focused on the first unbeaten level.
func _on_title_left() -> void:
	_enter_select(progress.first_unbeaten(levels))


func _on_action_resolved(result: Rules.Result) -> void:
	if mode == Mode.PLAYING and result.outcome == Rules.Outcome.WON:
		_enter_complete(result.state.tick)


## After a toggle changed settings: applies and saves them, and confirms the change with
## confirmation as a notice.
func _confirm_toggle(confirmation: String) -> void:
	_settings_changed()
	notice.show_text(confirmation)


## The Settings panel asked for bus's volume: it is applied and saved at once, as a mute is, and a
## sound change is previewed with a footstep at the new volume. Music is already playing.
func _on_volume_changed(bus: StringName, volume: int) -> void:
	settings.set_volume(bus, volume)
	_settings_changed()
	if bus == Settings.SOUND_BUS and not settings.is_muted(bus):
		sfx.play(Sfx.Event.FOOTSTEP)


## Every settings change ends here: on the buses, saved at once, and redrawn on the panel.
func _settings_changed() -> void:
	settings.apply()
	settings.save(settings_path)
	settings_panel.refresh()


## A best below par means the save or the par is wrong (the solver finds none), so it warns naming
## the level and keeps the best as stored.
func _warn_of_bests_below_par() -> void:
	for i in levels.size():
		var best := progress.best_for(levels[i].id)
		if best != Progress.UNBEATEN and best < levels[i].par:
			push_warning("Main: the stored best for %s is %d, below its par of %d" % [levels[i].name, best, levels[i].par])
