extends Control


func _ready() -> void:
	$Buttons/Start.pressed.connect(func(): SceneManager.go_to("level_select"))
	$Buttons/Quit.pressed.connect(func(): get_tree().quit())
