extends Node
## 全域遊戲狀態（Autoload: GameState）

const LANES := 4
const MAX_PLAYER_HP := 100

# 判定：Perfect +1 / Good 0 / Bad -1 / Miss -5（玩家血量）
const HP_DELTA := {"perfect": 1, "good": 0, "bad": -1, "miss": -5}
# 分數：Perfect +100 / Good +50 / Bad +10 / Miss 0
const SCORE_DELTA := {"perfect": 100, "good": 50, "bad": 10, "miss": 0}

var player_hp: int = MAX_PLAYER_HP
var score: int = 0
var current_phase: int = 1


func reset() -> void:
	player_hp = MAX_PLAYER_HP
	score = 0
