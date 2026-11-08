class_name DungeonRoom
extends WorldBase

## DungeonRoom.gd
## Level controller for the Underground Dungeon Chamber.
## Contains the Boss Gorgon encounter, exit portal back to campus, and reward chest.

@onready var boss_enemy: BossEnemy = get_node_or_null("YSortEntities/Enemies/BossEnemy") as BossEnemy


func _ready() -> void:
	level_name = "Labirin Bawah Tanah Untidar"
	super._ready()
