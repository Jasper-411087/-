extends Control
## 遊戲畫面：讀譜、計時、輸入判定、HUD。
## 目前只支援 Tap；Hold / 滑動音符（Phase 2、3）之後擴充。

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
@onready var progress_bar: ProgressBar = $HUD/Progress
@onready var phase_label: Label = $HUD/PhaseLabel

var notes: Array = []
var song_time := -LEAD_IN
var song_length := 0.0
var running := false
var audio_player: AudioStreamPlayer


func _ready() -> void:
	GameState.reset(GameState.current_phase)
	var chart := ChartLoader.load_chart(GameState.current_phase)
	for n in chart["notes"]:
		notes.append({"t": float(n["t"]), "lane": int(n["lane"]), "done": false})
	note_field.notes = notes
	song_length = (notes.back()["t"] if notes.size() > 0 else 0.0) + END_DELAY

	player_hp_bar.max_value = GameState.PLAYER_HP_MAX
	boss_hp_bar.max_value = GameState.BOSS_HP[GameState.current_phase]
	progress_bar.max_value = maxf(song_length, 0.01)
	phase_label.text = "Phase %d" % GameState.current_phase
	$HUD/Back.pressed.connect(func(): SceneManager.go_to("level_select"))

	# 有音檔就播放（沒有也能用計時器跑）
	var audio_path: String = chart.get("audio", "")
	if audio_path != "" and ResourceLoader.exists(audio_path):
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = load(audio_path)
		add_child(audio_player)
	running = true
	_refresh_hud()


func _process(delta: float) -> void:
	if not running:
		return
	var prev := song_time
	song_time += delta
	if audio_player and prev < 0.0 and song_time >= 0.0:
		audio_player.play()

	# 超過 Bad 視窗仍未擊中 → Miss
	for n in notes:
		if not n["done"] and song_time - n["t"] > WINDOW_BAD:
			n["done"] = true
			_judge("miss")

	if GameState.is_cleared() or GameState.is_failed() or song_time >= song_length:
		_finish()
		return

	note_field.song_time = song_time
	for i in 4:
		note_field.lane_pressed[i] = Input.is_action_pressed(LANE_ACTIONS[i])
	note_field.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	for i in 4:
		if event.is_action_pressed(LANE_ACTIONS[i]) and not event.is_echo():
			_hit_lane(i)


func _hit_lane(lane: int) -> void:
	# 取該軌最接近的未判定音符
	var best: Dictionary = {}
	var best_diff := INF
	for n in notes:
		if n["done"] or n["lane"] != lane:
			continue
		var diff := absf(n["t"] - song_time)
		if diff < best_diff:
			best = n
			best_diff = diff
		if n["t"] - song_time > WINDOW_BAD:
			break  # notes 已排序，之後更遠
	if best.is_empty() or best_diff > WINDOW_BAD:
		return  # 空按不判定
	best["done"] = true
	if best_diff <= WINDOW_PERFECT:
		_judge("perfect")
	elif best_diff <= WINDOW_GOOD:
		_judge("good")
	else:
		_judge("bad")


func _judge(grade: String) -> void:
	GameState.apply_judgement(grade)
	note_field.last_grade = grade
	_refresh_hud()


func _refresh_hud() -> void:
	player_hp_bar.value = GameState.player_hp
	boss_hp_bar.value = GameState.boss_hp
	score_label.text = "分數 %d" % GameState.score
	progress_bar.value = clampf(song_time, 0.0, song_length)


func _finish() -> void:
	running = false
	if audio_player:
		audio_player.stop()
	GameState.cleared = GameState.is_cleared()
	SceneManager.go_to("result")
