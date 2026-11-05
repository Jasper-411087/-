extends Node
## 場景切換（Autoload: SceneManager）
## 流程：主選單 → 選關 → 遊戲畫面 → 結算畫面

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"level_select": "res://scenes/level_select.tscn",
	"game": "res://scenes/game.tscn",
	"result": "res://scenes/result.tscn",
}


func go_to(scene_name: String) -> void:
	if not SCENES.has(scene_name):
		push_error("Unknown scene: %s" % scene_name)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_name])
