extends Node
## 全域遊戲狀態與起始值（Autoload: GameState）
## 數值來源：規格書「屬性設定」「遊戲規則與勝敗條件」

const LANES := 4
const PLAYER_HP_MAX := 100   # 範圍 0~100
const START_SCORE := 0
const LAST_PHASE := 3

# 各關 Boss 起始血量（Phase 1/2/3）
const BOSS_HP := {1: 200, 2: 400, 3: 700}
const BOSS_NAMES := {1: "異星矽基寄生體", 2: "機械狂暴巨獸", 3: "異形主腦"}
const PHASE_SCENES := {1: "外層防火牆", 2: "超算機房", 3: "邏輯核心"}

# 判定視窗（秒）：與實際音樂時間差的絕對值 ±70ms / ±110ms / ±135ms，超過即 Miss
const WINDOW := {"perfect": 0.070, "good": 0.110, "bad": 0.135}

# 判定對玩家血量的變化：Perfect +1 / Good 0 / Bad -1 / Miss -5
const PLAYER_HP_DELTA := {"perfect": 1, "good": 0, "bad": -1, "miss": -5}
# 判定對 Boss 血量的變化：Perfect -1 / Good -1 / Bad 不變 / Miss +1（上限為該關 Boss 血量）
const BOSS_HP_DELTA := {"perfect": -1, "good": -1, "bad": 0, "miss": 1}
# 分數：Perfect +100 / Good +50 / Bad +10 / Miss 0
const SCORE_DELTA := {"perfect": 100, "good": 50, "bad": 10, "miss": 0}

# 劇情：每關「之前」播放的劇情鍵；通關第 3 關後播 ending
const STORY_BEFORE := {1: "opening", 2: "after1", 3: "after2"}
const STORY_ENDING := "ending"

var current_phase: int = 1
var player_hp: int = PLAYER_HP_MAX
var boss_hp: int = BOSS_HP[1]
var score: int = START_SCORE
var combo: int = 0
var max_combo: int = 0
var counts := {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
var total_objects: int = 0  # 總物量（Tap 1、Hold 頭+尾 2），由 game.gd 載入譜面時設定
var cleared: bool = false   # 本局是否通關（結算畫面用）
var story_key: String = "opening"  # 劇情畫面要播放的段落


## 以指定關卡重設所有起始值
func reset(phase: int = current_phase) -> void:
	current_phase = phase
	player_hp = PLAYER_HP_MAX
	boss_hp = BOSS_HP[phase]
	score = START_SCORE
	combo = 0
	max_combo = 0
	counts = {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
	cleared = false


## 依秒數差決定判定；超過 Bad 視窗回傳 ""
func grade_for(diff: float) -> String:
	diff = absf(diff)
	if diff <= WINDOW["perfect"]:
		return "perfect"
	if diff <= WINDOW["good"]:
		return "good"
	if diff <= WINDOW["bad"]:
		return "bad"
	return ""


## 套用一次判定（grade: perfect/good/bad/miss）
func apply_judgement(grade: String) -> void:
	player_hp = clampi(player_hp + PLAYER_HP_DELTA[grade], 0, PLAYER_HP_MAX)
	boss_hp = clampi(boss_hp + BOSS_HP_DELTA[grade], 0, BOSS_HP[current_phase])
	score += SCORE_DELTA[grade]
	counts[grade] += 1
	if grade == "perfect" or grade == "good":
		combo += 1
		max_combo = maxi(max_combo, combo)
	else:
		combo = 0


## 準確率 = 總分 / (總物量 × 100)，回傳 0~1
func accuracy() -> float:
	if total_objects <= 0:
		return 0.0
	return float(score) / float(total_objects * SCORE_DELTA["perfect"])


## 通關：音樂播完時 Boss 血量 ≤ 0 且玩家血量 > 0
func is_cleared() -> bool:
	return boss_hp <= 0 and player_hp > 0


func is_failed() -> bool:
	return player_hp <= 0
