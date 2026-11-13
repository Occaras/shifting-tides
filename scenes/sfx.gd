class_name Sfx
extends Node
## The game's one SFX player (spec #52): one editor-placed AudioStreamPlayer child per Event,
## named after it (Footstep, Shell, ...), each on its path_for stream with max_polyphony 3 so a
## sound still ringing layers under the next. play(event) is the only entry point.

## The five game moments that have a sound.
enum Event { FOOTSTEP, SHELL, SPLASH, WAVE, WIN }

const DIR := "res://assets/audio/sfx/"
## What event_for returns for an outcome with no sound.
const NO_EVENT := -1

## Every player's volume, applied in _ready. On top of each file's own level this is the whole mix:
## each player is on the SFX bus (Settings.SOUND_BUS, set in sfx.tscn), which adds no gain: it only
## mutes and turns the sound Volume down from this level.
@export var volume_db := -6.0
## The Level whose action_resolved outcomes this plays; set in the editor by whoever owns both.
@export var level: Level

## Each Event's player, indexed by the Event; resolved once in _ready.
var _players: Array[AudioStreamPlayer] = []


## An Event's file: its name lowercased.
static func path_for(event: Event) -> String:
	return DIR + _name_of(event).to_lower() + ".wav"


## The Event an action's outcome sounds as, or NO_EVENT for none. Every tick is one beat, so a
## wait or a drift is a footstep; a take replaces that beat with the shell. An ignored off-board
## step costs no tick and gets no beat. On a win the last step's shell is not also played.
static func event_for(result: Rules.Result) -> int:
	match result.outcome:
		Rules.Outcome.WON:
			return Event.WIN
		Rules.Outcome.DROWNED:
			return Event.SPLASH
		Rules.Outcome.WAVE:
			return Event.WAVE
		Rules.Outcome.MOVED:
			return Event.SHELL if result.took_shell else Event.FOOTSTEP
	return NO_EVENT


func _ready() -> void:
	for event: Event in Event.values():
		var player := get_node(_name_of(event).capitalize()) as AudioStreamPlayer
		player.volume_db = volume_db
		_players.append(player)
	if level != null:
		level.action_resolved.connect(_on_action_resolved)


func play(event: Event) -> void:
	_players[event].play()


func _on_action_resolved(result: Rules.Result) -> void:
	var event := event_for(result)
	if event != NO_EVENT:
		play(event as Event)


## The one place an Event's name is spelled: its enum key. Its file and its player derive from it.
static func _name_of(event: Event) -> String:
	return Event.keys()[event] as String
