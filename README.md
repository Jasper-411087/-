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
- `scripts/game.gd`：遊玩流程（倒數 3 秒、音樂時間同步、判定、勝敗檢查、HUD）
- `scripts/note_field.gd`：繪製 4 軌與音符　`scripts/boss.gd`：Boss 占位圖與動畫
- `scripts/story.gd`：劇情過場，文字在 `data/story.json`（可直接改；每頁可加 `"image"` 背景圖）
- `data/charts/phaseN.json`：譜面 `{"t": 秒, "lane": 0~3, "len": Hold 長度秒}`，目前為**測試用隨機譜面**
- 音檔放 `assets/audio/phaseN.ogg`，存在時會自動播放，且以音樂長度作為關卡長度

## 操作
- D F J K：四軌　Esc：暫停（繼續／重新挑戰／回主選單）
- 劇情：Enter／空白鍵／滑鼠左鍵 下一頁，Esc 跳過
- 開發捷徑：主選單按 F1 / F2 / F3 直接進入該關

## 待辦
- 正式譜面與音樂（巴哈《D小調觸技曲》、維瓦第《四季・夏》第三樂章、貝多芬《月光》第三樂章）
- Boss 正式美術、劇情插圖、正式音效、字型
- Hold 尾端判定規則待組內確認（目前：撐到尾端 Perfect、提早放開 Bad；頭 Miss 則頭尾各算一次 Miss）

## 工具
- `tools/gen_charts.sh`：重新產生測試譜面（Phase 1 Tap；Phase 2 加 Hold、雙/三押；Phase 3 加對拍、四押）
- 自動驗證（無畫面；完美擊打三關都要通關、不按三關都要失敗，結束碼 0 = 通過）：
  `Godot_console.exe --headless --path . res://tools/autoplay_test.tscn`
