extends Control


func _ready() -> void:
	for i in 3:
		var phase := i + 1
		get_node("Buttons/Phase%d" % phase).pressed.connect(_start_phase.bind(phase))
	$Buttons/Back.pressed.connect(func(): SceneManager.go_to("menu"))


func _start_phase(phase: int) -> void:
	GameState.reset()
	GameState.current_phase = phase
	SceneManager.go_to("game")
