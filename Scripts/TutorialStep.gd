# TutorialStep.gd
class_name TutorialStep
extends Resource

@export var text: String = ""
@export var target_path: NodePath = ""   # node to point at, relative to the popup
@export var arrow_offset: Vector2 = Vector2.ZERO  # fine-tune arrow tip position
