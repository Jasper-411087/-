extends Control
## 遊戲畫面（規格書「遊玩流程」）：
## 1. 準備：載入譜面/音樂，重設數值，倒數 3 秒後播放音樂
## 2. 每幀：取得音樂播放時間 → 處理按鍵判定 → 逾時音符判 Miss → 更新 HUD
## 3. 勝敗：玩家血量 ≤ 0 立即失敗；音樂播完時 Boss 血量 ≤ 0 即通關，否則失敗
## 支援 Tap、Hold、多押（同一時間多個音符，含對拍、四押）。

signal finished  # 測試工具可連接此訊號以攔截場景切換

const ChartLoader = preload("res://scripts/chart_loader.gd")
const LANE_ACTIONS := ["lane_d", "lane_f", "lane_j", "lane_k"]
const COUNTDOWN := 3.0  # 開始前倒數（秒）
const END_DELAY := 1.5  # 沒有音檔時：最後一個音符後等待（秒）

@onready var note_field: Control = $NoteField
@onready var player_hp_bar: ProgressBar = $HUD/PlayerPanel/PlayerHP
@onready var player_hp_value: Label = $HUD/PlayerPanel/PlayerHPValue
@onready var phase_label: Label = $HUD/PlayerPanel/PhaseLabel
@onready var boss_hp_bar: ProgressBar = $HUD/BossPanel/BossHP
@onready var boss_hp_value: Label = $HUD/BossPanel/BossHPValue
@onready var boss_name_label: Label = $HUD/BossPanel/BossName
@onready var score_label: Label = $HUD/ScorePanel/Score
@onready var accuracy_label: Label = $HUD/ScorePanel/Accuracy
@onready var progress_bar: ProgressBar = $HUD/Progress
@onready var progress_label: Label = $HUD/ProgressLabel
@onready var combo_label: Label = $HUD/Combo
@onready var countdown_label: Label = $HUD/Countdown
@onready var pause_menu: Control = $PauseMenu
@onready var boss: Control = $Boss

var notes: Array = []
var song_time := -COUNTDOWN
var song_length := 0.0
var running := false
var audio_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暫停時仍可接收 Esc
	var phase: int = GameState.current_phase
	GameState.reset(phase)
	var chart := ChartLoader.load_chart(phase)
	var objects := 0
	for n in chart["notes"]:
		var hold_len := float(n.get("len", 0.0))
		notes.append({
			"t": float(n["t"]),
			"lane": int(n["lane"]),
			"len": hold_len,
			"done": false,     # 已完全結束（含 Hold 尾端）
			"holding": false,  # Hold 頭已擊中、正在按住
		})
		objects += 2 if hold_len > 0.0 else 1  # Hold 頭、尾各算一個物量
	GameState.total_objects = objects
	note_field.notes = notes

	var last_end := 0.0
	for n in notes:
		last_end = maxf(last_end, n["t"] + n["len"])
	song_length = last_end + END_DELAY

	# 有音檔就播放，並以音樂長度為準（沒有也能用計時器跑）
	var audio_path: String = chart.get("audio", "")
	if audio_path != "" and ResourceLoader.exists(audio_path):
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = load(audio_path)
		audio_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(audio_player)
		song_length = maxf(song_length, audio_player.stream.get_length())

	player_hp_bar.max_value = GameState.PLAYER_HP_MAX
	boss_hp_bar.max_value = GameState.BOSS_HP[phase]
	progress_bar.max_value = maxf(song_length, 0.01)
	phase_label.text = "Phase %d　%s" % [phase, GameState.PHASE_SCENES[phase]]
	boss_name_label.text = GameState.BOSS_NAMES[phase]
	boss.setup(phase)
	$PauseMenu/Buttons/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Buttons/Restart.pressed.connect(SceneManager.start_phase.bind(phase))
	$PauseMenu/Buttons/Quit.pressed.connect(SceneManager.go_to.bind("menu"))
	pause_menu.visible = false
	running = true
	_refresh_hud()


func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	_advance_time(delta)

	for n in notes:
		if n["done"]:
			continue
		if n["holding"]:
			_update_hold(n)
		elif song_time - n["t"] > GameState.WINDOW["bad"]:
			# 超過判定範圍仍未被按下 → Miss（Hold 的頭尾都算 Miss）
			n["done"] = true
			_judge("miss")
			if n["len"] > 0.0:
				_judge("miss")

	if GameState.is_failed():
		_finish()
		return
	if song_time >= song_length:
		_finish()
		return

	note_field.song_time = song_time
	for i in 4:
		note_field.lane_pressed[i] = Input.is_action_pressed(LANE_ACTIONS[i])
	note_field.queue_redraw()
	_refresh_hud()


## 推進遊戲時間：音樂播放中以音樂播放位置為準（避免與音樂漂移），否則以幀時間累加
func _advance_time(delta: float) -> void:
	var prev := song_time
	if audio_player and audio_player.playing:
		var t := audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		song_time = maxf(song_time, t)  # 保持單調遞增
	else:
		song_time += delta
	if audio_player and prev < 0.0 and song_time >= 0.0 and not audio_player.playing:
		audio_player.play(song_time)


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


## 按下某軌：只判定該軌離現在最近、還沒判定的音符；附近沒有音符則不處理（空按不扣血、不加分）
func _hit_lane(lane: int) -> void:
	var best: Dictionary = {}
	var best_diff := INF
	for n in notes:
		if n["done"] or n["holding"] or n["lane"] != lane:
			continue
		var diff := absf(n["t"] - song_time)
		if diff < best_diff:
			best = n
			best_diff = diff
		if n["t"] - song_time > GameState.WINDOW["bad"]:
			break  # notes 已排序，之後更遠
	if best.is_empty():
		return
	var grade: String = GameState.grade_for(best_diff)
	if grade == "":
		return
	if best["len"] > 0.0:
		best["holding"] = true  # Hold：頭判定後持續按住
	else:
		best["done"] = true
	_judge(grade)


## Hold 尾端判定：撐到尾端（容許提早放開 Good 範圍內）= Perfect；太早放開 = Bad
func _update_hold(n: Dictionary) -> void:
	var end_time: float = n["t"] + n["len"]
	var pressed := Input.is_action_pressed(LANE_ACTIONS[n["lane"]])
	if song_time >= end_time or (not pressed and song_time >= end_time - GameState.WINDOW["good"]):
		n["done"] = true
		n["holding"] = false
		_judge("perfect")
	elif not pressed:
		n["done"] = true
		n["holding"] = false
		_judge("bad")


func _judge(grade: String) -> void:
	var boss_before: int = GameState.boss_hp
	GameState.apply_judgement(grade)
	if GameState.boss_hp < boss_before:
		boss.on_damage()
	elif GameState.boss_hp > boss_before:
		boss.on_heal()
	boss.set_broken(GameState.boss_hp <= 0)
	Sfx.play(grade)
	note_field.show_grade(grade)
	_refresh_hud()


func _refresh_hud() -> void:
	var phase: int = GameState.current_phase
	player_hp_bar.value = GameState.player_hp
	player_hp_value.text = "%d / %d" % [GameState.player_hp, GameState.PLAYER_HP_MAX]
	boss_hp_bar.value = GameState.boss_hp
	boss_hp_value.text = "%d / %d" % [GameState.boss_hp, GameState.BOSS_HP[phase]]
	score_label.text = "%d" % GameState.score
	accuracy_label.text = "準確率 %.2f%%" % (GameState.accuracy() * 100.0)
	combo_label.text = "%d COMBO" % GameState.combo if GameState.combo > 1 else ""
	var t := clampf(song_time, 0.0, song_length)
	progress_bar.value = t
	progress_label.text = "%s / %s" % [_fmt_time(t), _fmt_time(song_length)]
	if song_time < 0.0:
		countdown_label.text = "%d" % ceili(-song_time)
	elif song_time < 0.6:
		countdown_label.text = "START!"
	else:
		countdown_label.text = ""


static func _fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _finish() -> void:
	running = false
	if audio_player:
		audio_player.stop()
	GameState.cleared = GameState.is_cleared()
	_refresh_hud()
	finished.emit()
	if not finished.get_connections().is_empty():
		return  # 測試工具接手，不切場景
	Sfx.play("clear" if GameState.cleared else "fail", -3.0)
	countdown_label.text = "CLEAR!" if GameState.cleared else "FAILED"
	if GameState.cleared:
		boss.on_defeat()
	await get_tree().create_timer(1.6).timeout
	SceneManager.go_to("result")
