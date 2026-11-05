extends Node
## 全域遊戲狀態與起始值（Autoload: GameState）
## 數值來源：規格書「屬性設定」「遊戲元素與關卡設計」

const LANES := 4
const PLAYER_HP_MAX := 100   # 範圍 0~100
const START_SCORE := 0

# 各關 Boss 起始血量（Phase 1/2/3）
const BOSS_HP := {1: 200, 2: 400, 3: 700}

# 判定對玩家血量的變化：Perfect +1 / Good 0 / Bad -1 / Miss -5
const PLAYER_HP_DELTA := {"perfect": 1, "good": 0, "bad": -1, "miss": -5}
# 判定對 Boss 血量的變化：Perfect -1 / Good -1 / Bad 0 / Miss +1
# TODO: 規格書圖示字太小，Bad 對 Boss 的值（0 或 -1）待與規格書確認
const BOSS_HP_DELTA := {"perfect": -1, "good": -1, "bad": 0, "miss": 1}
# 分數：Perfect +100 / Good +50 / Bad +10 / Miss 0
const SCORE_DELTA := {"perfect": 100, "good": 50, "bad": 10, "miss": 0}

var current_phase: int = 1
var player_hp: int = PLAYER_HP_MAX
var boss_hp: int = BOSS_HP[1]
var score: int = START_SCORE
var combo: int = 0
var max_combo: int = 0
var counts := {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
var cleared: bool = false  # 本局是否通關（結算畫面用）


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


func is_cleared() -> bool:
	return boss_hp <= 0


func is_failed() -> bool:
	return player_hp <= 0
