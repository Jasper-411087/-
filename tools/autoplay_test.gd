extends Node
## 自動演奏驗證（無畫面）：godot --headless --path . res://tools/autoplay_test.tscn
## 以固定步長驅動遊戲：
##   1. 完美擊打所有音符 → Phase 1~3 都必須通關、準確率 100%
##   2. 完全不按 → Phase 1~3 都必須失敗（玩家血量歸零）
## 全部符合時結束碼為 0，否則為 1。

const STEP := 1.0 / 240.0

var game: Control
var phase := 1
var press := true      # true = 完美擊打；false = 完全不按
var finished_flag := false
var failures := 0


func _ready() -> void:
	_start()


func _start() -> void:
	GameState.current_phase = phase
	finished_flag = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.finished.connect(func(): finished_flag = true)
	game.set_process(false)  # 由本腳本以固定步長驅動


func _process(_d: float) -> void:
	if game == null:
		return
	for i in 400:
		if finished_flag:
			break
		_step()
	if not finished_flag:
		return
	var expect_clear: bool = press
	var ok: bool = GameState.cleared == expect_clear
	if press:
		ok = ok and is_equal_approx(GameState.accuracy(), 1.0)
	if not ok:
		failures += 1
	print("[%s] %s Phase %d  cleared=%s score=%d acc=%.2f%% counts=%s maxcombo=%d boss=%d hp=%d t=%.1f" % [
		"OK" if ok else "NG", "perfect" if press else "no-input", phase, GameState.cleared,
		GameState.score, GameState.accuracy() * 100.0, GameState.counts, GameState.max_combo,
		GameState.boss_hp, GameState.player_hp, game.song_time])
	for a in game.LANE_ACTIONS:
		Input.action_release(a)
	game.queue_free()
	game = null
	phase += 1
	if phase > 3:
		if not press:
			print("ALL PASSED" if failures == 0 else "%d FAILED" % failures)
			get_tree().quit(0 if failures == 0 else 1)
			return
		press = false
		phase = 1
	_start.call_deferred()


func _step() -> void:
	if press:
		for n in game.notes:
			var action: String = game.LANE_ACTIONS[n["lane"]]
			if not n["done"] and not n["holding"] and absf(n["t"] - game.song_time) < STEP:
				Input.action_press(action)
				game._hit_lane(n["lane"])
			elif n["holding"]:
				Input.action_press(action)
			elif n["done"] and Input.is_action_pressed(action):
				Input.action_release(action)
	game._process(STEP)
