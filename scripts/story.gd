extends Control
## 劇情過場：逐頁顯示 data/story.json 中 GameState.story_key 的段落（打字機效果）。
## 每頁可選欄位："speaker"（標題）、"image"（背景圖路徑，例如 res://assets/images/story/opening1.png）。
## 操作：Enter / 空白鍵 / 滑鼠左鍵 = 下一頁（打字中則先顯示全文）；Esc 或「跳過」= 略過整段。

const STORY_PATH := "res://data/story.json"
const CHARS_PER_SEC := 40.0

@onready var bg_image: TextureRect = $BgImage
@onready var speaker_label: Label = $Box/Speaker
@onready var text_label: Label = $Box/Text
@onready var hint_label: Label = $Box/Hint
@onready var page_label: Label = $Page

var key := ""
var pages: Array = []
var index := 0
var _shown := 0.0


func _ready() -> void:
	key = GameState.story_key
	pages = _load_pages(key)
	$Skip.pressed.connect(_finish)
	if pages.is_empty():
		_finish.call_deferred()
		return
	_show_page(0)


func _load_pages(k: String) -> Array:
	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		push_error("Story not found: %s" % STORY_PATH)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has(k):
		push_error("Story key missing: %s" % k)
		return []
	return data[k]


func _show_page(i: int) -> void:
	index = i
	var p: Dictionary = pages[i]
	speaker_label.text = p.get("speaker", "")
	speaker_label.visible = speaker_label.text != ""
	text_label.text = p.get("text", "")
	text_label.visible_characters = 0
	_shown = 0.0
	var img: String = p.get("image", "")
	if img != "" and ResourceLoader.exists(img):
		bg_image.texture = load(img)
	page_label.text = "%d / %d" % [i + 1, pages.size()]
	hint_label.visible = false


func _process(delta: float) -> void:
	var total := text_label.get_total_character_count()
	if text_label.visible_characters < total:
		_shown += delta * CHARS_PER_SEC
		text_label.visible_characters = mini(int(_shown), total)
	else:
		hint_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	# 先標記輸入已處理，再換頁／離開：換場景後此節點已不在場景樹，get_viewport() 會是 null
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if pages.is_empty():
		return
	if text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters = text_label.get_total_character_count()  # 先顯示全文
		return
	if index + 1 < pages.size():
		_show_page(index + 1)
	else:
		_finish()


func _finish() -> void:
	set_process_unhandled_input(false)
	SceneManager.story_finished(key)
