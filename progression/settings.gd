class_name Settings
extends RefCounted
## The player's settings: each of music and sound has a Volume and can be Muted, the two
## independent of each other. Kept in one ConfigFile in user://,
## next to Progress's but apart from it. Main owns the one Settings, applies it and saves it on
## every change; the buses hold only what apply() last gave them.

const PATH := "user://settings.cfg"
const VERSION := 1
const META_SECTION := "meta"
const AUDIO_SECTION := "audio"
const VERSION_KEY := "version"
const MUSIC_MUTED_KEY := "music_muted"
const SOUND_MUTED_KEY := "sound_muted"
const MUSIC_VOLUME_KEY := "music_volume"
const SOUND_VOLUME_KEY := "sound_volume"
## A Volume's steps run from 0, silent, to FULL_VOLUME, the mix as set in code: a volume only ever
## makes its bus quieter, never louder than the players' own levels.
const FULL_VOLUME := 10
## The buses of default_bus_layout.tres, under Master: the soundtrack plays on one and every Sfx
## player on the other. tests/test_settings.gd and tests/test_sfx.gd guard the layout and the
## players against these names.
const MUSIC_BUS := &"Music"
const SOUND_BUS := &"SFX"

var music_muted := false
var sound_muted := false
var music_volume := FULL_VOLUME
var sound_volume := FULL_VOLUME


## The settings saved at path, or both unmuted at full volume when the file is missing, unreadable
## or of another version (with a warning for the latter two). A mute that is no bool loads unmuted;
## a volume that is missing or no int loads full, and one outside 0..FULL_VOLUME is clamped into it,
## so a file saved before volumes existed keeps its mutes at full volume.
static func load_file(path: String = PATH) -> Settings:
	var settings := Settings.new()
	if not FileAccess.file_exists(path):
		return settings
	var config := ConfigFile.new()
	var error := _load_quietly(config, path)
	if error != OK:
		push_warning("Settings: cannot read %s (%s), starting unmuted" % [path, error_string(error)])
		return settings
	var version: Variant = config.get_value(META_SECTION, VERSION_KEY, 0)
	# The type first: GDScript cannot compare a String or an Array with an int.
	if not (version is int and version == VERSION):
		push_warning("Settings: %s has version %s, not %d, starting unmuted" % [path, version, VERSION])
		return settings
	settings.music_muted = _mute_at(config, MUSIC_MUTED_KEY)
	settings.sound_muted = _mute_at(config, SOUND_MUTED_KEY)
	settings.music_volume = _volume_at(config, MUSIC_VOLUME_KEY)
	settings.sound_volume = _volume_at(config, SOUND_VOLUME_KEY)
	return settings


## Writes both mutes and both volumes to path; returns whether it succeeded, with a warning when it did not.
func save(path: String = PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, VERSION_KEY, VERSION)
	config.set_value(AUDIO_SECTION, MUSIC_MUTED_KEY, music_muted)
	config.set_value(AUDIO_SECTION, SOUND_MUTED_KEY, sound_muted)
	config.set_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, music_volume)
	config.set_value(AUDIO_SECTION, SOUND_VOLUME_KEY, sound_volume)
	var error := config.save(path)
	if error != OK:
		push_warning("Settings: cannot write %s (%s)" % [path, error_string(error)])
		return false
	return true


## ConfigFile logs a file it cannot parse as an engine error. A bad settings file is not one: the
## game starts unmuted and load_file's warning says why, so the engine's line is held back.
static func _load_quietly(config: ConfigFile, path: String) -> Error:
	var printed := Engine.print_error_messages
	Engine.print_error_messages = false
	var error := config.load(path)
	Engine.print_error_messages = printed
	return error


## The mute config stores under key, or unmuted when it stores none or something that is no bool.
static func _mute_at(config: ConfigFile, key: String) -> bool:
	var muted: Variant = config.get_value(AUDIO_SECTION, key, false)
	return muted is bool and muted


## The volume config stores under key, clamped into 0..FULL_VOLUME, or full when it stores none or
## something that is no int.
static func _volume_at(config: ConfigFile, key: String) -> int:
	var volume: Variant = config.get_value(AUDIO_SECTION, key, FULL_VOLUME)
	return clampi(volume, 0, FULL_VOLUME) if volume is int else FULL_VOLUME


## Puts each bus's volume and mute on it. A muted bus still plays its players, so the soundtrack
## carries on underneath and unmuting never restarts it; a muted bus keeps its volume.
func apply() -> void:
	_apply_to(MUSIC_BUS, music_volume, music_muted)
	_apply_to(SOUND_BUS, sound_volume, sound_muted)


## bus's volume: MUSIC_BUS's or SOUND_BUS's.
func volume_of(bus: StringName) -> int:
	return music_volume if bus == MUSIC_BUS else sound_volume


## Sets bus's volume, clamped into 0..FULL_VOLUME. Puts nothing on the bus: apply() does.
func set_volume(bus: StringName, value: int) -> void:
	if bus == MUSIC_BUS:
		music_volume = clampi(value, 0, FULL_VOLUME)
	else:
		sound_volume = clampi(value, 0, FULL_VOLUME)


## Whether bus is muted: MUSIC_BUS's or SOUND_BUS's.
func is_muted(bus: StringName) -> bool:
	return music_muted if bus == MUSIC_BUS else sound_muted


## A step's share of full amplitude, in dB: 0 dB at FULL_VOLUME, -inf (silent) at 0.
static func volume_db(volume: int) -> float:
	return linear_to_db(float(volume) / FULL_VOLUME)


static func _apply_to(bus: StringName, volume: int, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, volume_db(volume))
	AudioServer.set_bus_mute(index, muted)
