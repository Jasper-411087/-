# 3026：放學前的解碼戰

Godot 4.3（GL Compatibility）開發的直立式 4K 節奏遊戲。按鍵：D / F / J / K。
規格書：`docs/遊戲設計規格書.pdf`

## 目錄結構
- `scenes/` 場景　`scripts/` 腳本（`autoload/` 為全域單例）
- `assets/` 音訊、圖片、字型　`data/` 譜面等資料　`docs/` 文件

## 執行
用 Godot 4.3+ 開啟 `project.godot`，按 F5。

## 架構
- `GameState`（autoload）：血量、分數、各判定數值（起始值）
- `SceneManager`（autoload）：`go_to("menu" | "level_select" | "game" | "result")`
- `scripts/game.gd`：遊戲主邏輯（計時、輸入、判定、HUD）；`note_field.gd` 只負責繪製 4 軌
- `data/charts/phaseN.json`：譜面 `{"t": 秒, "lane": 0~3}`，目前為**測試用隨機譜面**
- 音檔放 `assets/audio/phaseN.ogg`，存在時會自動播放

## 待辦
- Hold / 滑動音符（Phase 2、3）、Boss 圖與動畫、音效、正式譜面
- 確認 Bad 對 Boss 血量的數值（見 `game_state.gd` 的 TODO）
