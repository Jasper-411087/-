extends Control
## 主選單：開始遊戲 → 開場故事 → 第一關（規格書不設選關畫面）
## 開發測試捷徑：按 F1 / F2 / F3 直接進入該關。


func _ready() -> void:
	$Buttons/Start.pressed.connect(SceneManager.new_game)
	$Buttons/Quit.pressed.connect(func(): get_tree().quit())
	$Buttons/Start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: SceneManager.start_phase(1)
			KEY_F2: SceneManager.start_phase(2)
			KEY_F3: SceneManager.start_phase(3)
