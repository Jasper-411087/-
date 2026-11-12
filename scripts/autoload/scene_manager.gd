extends Node
## 場景切換（Autoload: SceneManager）
## 流程（規格書圖 2-1，單線劇情、不設選關）：
## 主選單 → 開場故事 → 第一關 → 過場一 → 第二關 → 過場二 → 第三關 → 故事結尾
## 每關結束先進結算畫面：通關 → 下一段劇情；失敗 → 重新挑戰該關

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"story": "res://scenes/story.tscn",
	"game": "res://scenes/game.tscn",
	"result": "res://scenes/result.tscn",
}


func go_to(scene_name: String) -> void:
	if not SCENES.has(scene_name):
		push_error("Unknown scene: %s" % scene_name)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_name])


## 播放某段劇情
func play_story(key: String) -> void:
	GameState.story_key = key
	go_to("story")


## 從頭開始（開場故事 → 第一關）
func new_game() -> void:
	GameState.reset(1)
	play_story(GameState.STORY_BEFORE[1])


## 直接開始某關（重新挑戰、開發測試用）
func start_phase(phase: int) -> void:
	GameState.reset(phase)
	go_to("game")


## 劇情播完後：開場/過場 → 進入對應關卡；結尾 → 回主選單
func story_finished(key: String) -> void:
	for phase in GameState.STORY_BEFORE:
		if GameState.STORY_BEFORE[phase] == key:
			start_phase(phase)
			return
	go_to("menu")


## 結算後通關 → 下一段劇情
func continue_after_clear() -> void:
	var next: int = GameState.current_phase + 1
	if next > GameState.LAST_PHASE:
		play_story(GameState.STORY_ENDING)
	else:
		play_story(GameState.STORY_BEFORE[next])
