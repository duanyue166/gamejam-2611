class_name DialogueCharacter
extends Resource

const DEFAULT_PORTRAIT := &"default"

@export var id: StringName
@export var display_name: String
## Use "default" for the portrait shown when a line leaves its portrait ID empty.
@export var portraits: Dictionary[StringName, Texture2D] = {}


func get_portrait(portrait_id: StringName) -> Texture2D:
	var portrait := portraits.get(portrait_id) as Texture2D
	if portrait != null:
		return portrait
	return portraits.get(DEFAULT_PORTRAIT)
