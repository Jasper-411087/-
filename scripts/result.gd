extends Control


func _ready() -> void:
	var verdict := "通關！" if GameState.cleared else "挑戰失敗"
	$Title.text = "%s　分數：%d" % [verdict, GameState.score]
	$Buttons/Retry.pressed.connect(func(): SceneManager.go_to("game"))
	$Buttons/Menu.pressed.connect(func(): SceneManager.go_to("menu"))
