extends Control
## 遊戲畫面（占位）：之後在此實作 4 軌音符、判定、Boss 血量。


func _ready() -> void:
	$Title.text = "Phase %d（占位）" % GameState.current_phase
	$Buttons/Finish.pressed.connect(func(): SceneManager.go_to("result"))
	$Buttons/Back.pressed.connect(func(): SceneManager.go_to("level_select"))
