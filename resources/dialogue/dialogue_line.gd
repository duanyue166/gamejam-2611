class_name DialogueLine
extends Resource

## Leave empty for narration.
@export var speaker: DialogueCharacter
@export_multiline var text: String
## Leave empty to use the character's default portrait.
@export var portrait_id: StringName
