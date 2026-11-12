# 3026：放學前的解碼戰

Godot 4.3（GL Compatibility）開發的直立式 4K 節奏遊戲。按鍵：D / F / J / K。
規格書：`docs/遊戲設計規格書.pdf`　規格書第二、三部分程式相關草稿：`docs/規格書草稿_第二三部分.md`

## 目錄結構
- `scenes/` 場景　`scripts/` 腳本（`autoload/` 為全域單例）
- `assets/` 音訊、圖片、字型　`data/` 譜面、劇情等資料　`docs/` 文件

## 執行
用 Godot 4.3+ 開啟 `project.godot`，按 F5。

## 遊戲流程（規格書圖 2-1，單線劇情、不設選關）
主選單 → 開場故事 → 第一關 → 過場一 → 第二關 → 過場二 → 第三關 → 故事結尾
每關結束進結算畫面：通關 → 下一段劇情；失敗 → 重新挑戰該關。

## 架構
- `GameState`（autoload）：血量、分數、判定範圍（±70/110/135ms）、各判定數值、準確率
- `SceneManager`（autoload）：場景切換與劇情流程（`new_game()`、`start_phase(n)`、`play_story(key)`）
- `Sfx`（autoload）：音效（程式合成占位，可放正式音檔覆蓋）
- `Settings`（autoload）：玩家設定（流速），存在 `user://settings.cfg`
- `scripts/game.gd`：遊玩流程（倒數 3 秒、音樂時間同步、判定、勝敗檢查、HUD）
- `scripts/note_field.gd`：繪製 4 軌與音符　`scripts/boss.gd`：Boss 占位圖與動畫
- `scripts/story.gd`：劇情過場，文字在 `data/story.json`（可直接改；每頁可加 `"image"` 背景圖）
- `data/charts/phaseN.json`：譜面 `{"t": 秒, "lane": 0~3, "len": Hold 長度秒}`，由 MIDI 自動產生（可再手動修改）
- `assets/audio/phaseN.ogg`：背景音樂，由 `assets/music_src/*.mid` 合成；以音樂長度作為關卡長度

## 音樂與譜面（MIDI）
- MIDI 來源：The Mutopia Project，授權與來源截圖見 `docs/素材來源/`（《夏》《月光》為 CC BY-SA，需標示出處）
- `tools/build_music.sh [1|2|3]`：由 MIDI 同時產生音檔與譜面（需 python3、fluidsynth、ffmpeg）
- `tools/midi_to_chart.py --info 檔案.mid` 查看 MIDI；各關密度、多押、Hold 規則在該檔 `PHASES`
- 採音規則：依段落強度（音符密度＋力度）調整密度，溫和段落較疏、高潮較密；
  雙押左右手各一、三押相鄰三軌；快速段落避免同軌連打並優先換手；Hold 時優先用另一隻手
- 想換段落或速度：改 `build_music.sh` 最後三行的 start / end / speed 再重跑

## 操作
- D F J K：四軌　Esc：暫停（流速／繼續／重新挑戰／回主選單）
- 流速：主選單或暫停選單的「－ ＋」調整（3.0 ~ 20.0）
- 判定顯示：Good / Bad 會在下方顯示 FAST（按太早）或 LATE（按太晚）
- Hold：按住期間每半拍 +1 combo；太早放開判 Bad
- 劇情：Enter／空白鍵／滑鼠左鍵 下一頁，Esc 跳過
- 開發捷徑：主選單按 F1 / F2 / F3 直接進入該關

## 待辦
- 實際試玩三關，手動微調自動產生的譜面
- Boss 正式美術、劇情插圖、正式音效、字型

## 工具
- `tools/gen_charts.sh`：產生隨機測試譜面（**會覆蓋**正式譜面，僅供測試）（Phase 1 Tap；Phase 2 加 Hold、雙/三押；Phase 3 加對拍、四押）
- 自動驗證（無畫面；完美擊打三關都要通關、不按三關都要失敗，結束碼 0 = 通過）：
  `Godot_console.exe --headless --path . res://tools/autoplay_test.tscn`
