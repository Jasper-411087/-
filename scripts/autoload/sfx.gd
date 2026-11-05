extends Node
## 音效（Autoload: Sfx）
## 預設用程式合成占位音效。要換正式音檔：把檔案放到 assets/audio/sfx/<名稱>.ogg（或 .wav），
## 名稱見 NAMES，存在時會優先使用。

const RATE := 22050
const NAMES := ["perfect", "good", "bad", "miss", "clear", "fail"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in NAMES:
		_streams[n] = _load_custom(n)
		if _streams[n] == null:
			_streams[n] = _synth(n)


func play(sfx_name: String, volume_db: float = -6.0) -> void:
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func _load_custom(sfx_name: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/sfx/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _synth(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"perfect": return _tone([1320.0], 0.09)
		"good": return _tone([990.0], 0.09)
		"bad": return _tone([440.0], 0.10, 0.4)
		"miss": return _tone([160.0], 0.18, 0.5, true)
		"clear": return _tone([523.0, 659.0, 784.0, 1047.0], 0.18)
		"fail": return _tone([392.0, 330.0, 262.0, 196.0], 0.22)
	return null


## 依序播放 freqs 各 dur 秒的衰減音；noisy>0 混入雜訊；square 使用方波
func _tone(freqs: Array, dur: float, noisy: float = 0.0, square: bool = false) -> AudioStreamWAV:
	var per := int(RATE * dur)
	var total := per * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for k in freqs.size():
		for i in per:
			var t := float(i) / RATE
			var env := exp(-t * (5.0 / dur)) * minf(1.0, float(i) / 40.0)
			var s := sin(TAU * freqs[k] * t)
			if square:
				s = signf(s) * 0.6
			s = s * (1.0 - noisy) + randf_range(-1.0, 1.0) * noisy
			data.encode_s16((k * per + i) * 2, int(clampf(s * env, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
