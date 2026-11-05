extends Control
## 遊戲畫面：讀譜、計時、輸入判定、HUD、暫停。
## 支援 Tap、Hold、雙押（同一時間多個音符）。滑動音符（Phase 3）之後擴充。

signal finished  # 測試工具可連接此訊號以攔截場景切換

const ChartLoader = preload("res://scripts/chart_loader.gd")
const LANE_ACTIONS := ["lane_d", "lane_f", "lane_j", "lane_k"]
# 判定視窗（秒）：與音符時間差的絕對值
const WINDOW_PERFECT := 0.05
const WINDOW_GOOD := 0.10
const WINDOW_BAD := 0.15
const LEAD_IN := 1.0   # 開始前的緩衝時間
const END_DELAY := 1.5 # 最後一個音符後等待

@onready var note_field: Control = $NoteField
@onready var player_hp_bar: ProgressBar = $HUD/PlayerHP
@onready var boss_hp_bar: ProgressBar = $HUD/BossHP
@onready var score_label: Label = $HUD/Score
@onready var combo_label: Label = $HUD/Combo
@onready var progress_bar: ProgressBar = $HUD/Progress
@onready var phase_label: Label = $HUD/PhaseLabel
@onready var pause_menu: Control = $PauseMenu

var notes: Array = []
var song_time := -LEAD_IN
var song_length := 0.0
var running := false
var audio_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暫停時仍可接收 Esc
	GameState.reset(GameState.current_phase)
	var chart := ChartLoader.load_chart(GameState.current_phase)
	for n in chart["notes"]:
		notes.append({
			"t": float(n["t"]),
			"lane": int(n["lane"]),
			"len": float(n.get("len", 0.0)),
			"done": false,     # 已完全結束（含 Hold 尾端）
			"holding": false,  # Hold 頭已擊中、正在按住
		})
	note_field.notes = notes
	var last_end := 0.0
	for n in notes:
		last_end = maxf(last_end, n["t"] + n["len"])
	song_length = last_end + END_DELAY

	player_hp_bar.max_value = GameState.PLAYER_HP_MAX
	boss_hp_bar.max_value = GameState.BOSS_HP[GameState.current_phase]
	progress_bar.max_value = maxf(song_length, 0.01)
	phase_label.text = "Phase %d" % GameState.current_phase
	$HUD/Back.pressed.connect(func(): SceneManager.go_to("level_select"))
	$PauseMenu/Buttons/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Buttons/Quit.pressed.connect(func(): SceneManager.go_to("level_select"))
	pause_menu.visible = false

	# 有音檔就播放（沒有也能用計時器跑）
	var audio_path: String = chart.get("audio", "")
	if audio_path != "" and ResourceLoader.exists(audio_path):
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = load(audio_path)
		audio_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(audio_player)
	running = true
	_refresh_hud()


func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	var prev := song_time
	song_time += delta
	if audio_player and prev < 0.0 and song_time >= 0.0:
		audio_player.play()

	for n in notes:
		if n["done"]:
			continue
		if n["holding"]:
			_update_hold(n)
		elif song_time - n["t"] > WINDOW_BAD:
			# 超過 Bad 視窗仍未擊中 → Miss
			n["done"] = true
			_judge("miss")

	if GameState.is_cleared() or GameState.is_failed() or song_time >= song_length:
		_finish()
		return

	note_field.song_time = song_time
	for i in 4:
		note_field.lane_pressed[i] = Input.is_action_pressed(LANE_ACTIONS[i])
	note_field.queue_redraw()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not get_tree().paused)
		return
	if get_tree().paused:
		return
	for i in 4:
		if event.is_action_pressed(LANE_ACTIONS[i]) and not event.is_echo():
			_hit_lane(i)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_menu.visible = value


func _hit_lane(lane: int) -> void:
	# 取該軌最接近的未判定音符（同軌可能有多個，取時間差最小者）
	var best: Dictionary = {}
	var best_diff := INF
	for n in notes:
		if n["done"] or n["holding"] or n["lane"] != lane:
			continue
		var diff := absf(n["t"] - song_time)
		if diff < best_diff:
			best = n
			best_diff = diff
		if n["t"] - song_time > WINDOW_BAD:
			break  # notes 已排序，之後更遠
	if best.is_empty() or best_diff > WINDOW_BAD:
		return  # 空按不判定
	if best["len"] > 0.0:
		best["holding"] = true  # Hold：頭判定後持續按住
	else:
		best["done"] = true
	if best_diff <= WINDOW_PERFECT:
		_judge("perfect")
	elif best_diff <= WINDOW_GOOD:
		_judge("good")
	else:
		_judge("bad")


## Hold 尾端判定：撐到尾端（容許提早放開 WINDOW_GOOD）= Perfect；太早放開 = Bad
func _update_hold(n: Dictionary) -> void:
	var end_time: float = n["t"] + n["len"]
	var pressed := Input.is_action_pressed(LANE_ACTIONS[n["lane"]])
	if song_time >= end_time or (not pressed and song_time >= end_time - WINDOW_GOOD):
		n["done"] = true
		n["holding"] = false
		_judge("perfect")
	elif not pressed:
		n["done"] = true
		n["holding"] = false
		_judge("bad")


func _judge(grade: String) -> void:
	GameState.apply_judgement(grade)
	note_field.last_grade = grade
	_refresh_hud()


func _refresh_hud() -> void:
	player_hp_bar.value = GameState.player_hp
	boss_hp_bar.value = GameState.boss_hp
	score_label.text = "分數 %d" % GameState.score
	combo_label.text = "%d COMBO" % GameState.combo if GameState.combo > 1 else ""
	progress_bar.value = clampf(song_time, 0.0, song_length)


func _finish() -> void:
	running = false
	if audio_player:
		audio_player.stop()
	GameState.cleared = GameState.is_cleared()
	finished.emit()
	if finished.get_connections().is_empty():
		SceneManager.go_to("result")
