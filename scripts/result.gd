extends Control


func _ready() -> void:
	$Title.text = "結算　分數：%d" % GameState.score
	$Buttons/Retry.pressed.connect(func(): SceneManager.go_to("game"))
	$Buttons/Menu.pressed.connect(func(): SceneManager.go_to("menu"))
