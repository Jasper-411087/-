## 讀取譜面 JSON：{"phase", "bpm", "audio", "notes": [{"t": 秒, "lane": 0~3}]}

static func load_chart(phase: int) -> Dictionary:
	var path := "res://data/charts/phase%d.json" % phase
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Chart not found: %s" % path)
		return {"notes": []}
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid chart: %s" % path)
		return {"notes": []}
	data["notes"].sort_custom(func(a, b): return a["t"] < b["t"])
	return data
