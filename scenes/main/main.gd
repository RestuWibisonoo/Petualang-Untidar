class_name MainScene
extends WorldBase

## main.gd
## Main entry level controller for Petualang Untidar.
## Inherits from WorldBase for level management, spawn points, Y-sort, and HUD.


func _ready() -> void:
	super._ready()
	print("[MainScene] Main game entry loaded successfully.")
