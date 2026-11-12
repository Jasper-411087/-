extends Control
## 結算畫面：顯示分數、準確率、各判定次數與最高連擊。
## 通關 → 「繼續」進入下一段劇情；失敗 → 「重新挑戰」該關。


func _ready() -> void:
	var phase: int = GameState.current_phase
	var verdict := "通關！" if GameState.cleared else "挑戰失敗"
	$Title.text = "Phase %d　%s" % [phase, verdict]
	$Title.modulate = Color("7cf0a8") if GameState.cleared else Color("ff6b6b")
	var c: Dictionary = GameState.counts
	$Stats.text = "分數　%d\n準確率　%.2f%%\n\nPerfect %d　Good %d　Bad %d　Miss %d\n最高連擊　%d" % [
		GameState.score, GameState.accuracy() * 100.0,
		c["perfect"], c["good"], c["bad"], c["miss"], GameState.max_combo]
	var next: Button = $Buttons/Next
	if GameState.cleared:
		next.text = "繼續劇情" if phase < GameState.LAST_PHASE else "觀看結局"
		next.pressed.connect(SceneManager.continue_after_clear)
		$Buttons/Retry.pressed.connect(SceneManager.start_phase.bind(phase))
	else:
		next.text = "重新挑戰"
		next.pressed.connect(SceneManager.start_phase.bind(phase))
		$Buttons/Retry.visible = false
	$Buttons/Menu.pressed.connect(SceneManager.go_to.bind("menu"))
	next.grab_focus()
