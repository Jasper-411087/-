extends Control


func _ready() -> void:
	var verdict := "通關！" if GameState.cleared else "挑戰失敗"
	$Title.text = "%s　分數：%d" % [verdict, GameState.score]
	var c: Dictionary = GameState.counts
	$Stats.text = "Perfect %d　Good %d\nBad %d　Miss %d\n最高連擊 %d" % [
		c["perfect"], c["good"], c["bad"], c["miss"], GameState.max_combo]
	$Buttons/Retry.pressed.connect(func(): SceneManager.go_to("game"))
	$Buttons/Menu.pressed.connect(func(): SceneManager.go_to("menu"))
