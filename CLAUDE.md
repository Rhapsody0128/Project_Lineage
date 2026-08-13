# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案

Godot 4.7(GL Compatibility)遊戲專案「Project L」,主場景 `Scenes/main.tscn`,視窗 1600x900。
純 GDScript,無 build/lint/test 工具鏈。

- 事件合約/戰鬥數值公式/Unity 移植對照/已知待辦等深入細節 → [Spec.md](Spec.md)
- 遊戲設計(血統/家族/婚姻/學院等企劃內容)→ [遊戲企劃設定總整理.md](遊戲企劃設定總整理.md)

## 驗證方式

```
GODOT="/d/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --editor --quit-after 10   # 全專案語法掃描
```

寫完邏輯就好,不用主動寫 `_test_*.gd` 自證——交給使用者實際跑遊戲測試,拿到回報再針對性 debug。

## 最高原則:System 管邏輯,Scenes 管畫面

- **`System/`**:所有邏輯/數值/機率/資料模型,全部 `RefCounted`,不碰場景樹、不
  `extends Control/Node2D`。「規則」(誰能打誰、傷害怎麼算、格子怎麼佔用)一律寫這裡,
  不要在場景腳本用 if/else 兜。
- **`Scenes/<場景>/`**:只做「呼叫 System 取資料 → 跑模擬 → 把結果轉成畫面(節點位置/
  動畫/文字/Tween)→ 輸入事件轉呼叫 System」,不寫規則邏輯。
- **`Scripts/`**:非戰鬥場景零散 UI 腳本。
- **`Images/`**:美術素材與對應小型 `.tscn`(角色動畫 Scene 等)。

## System/ 資料夾對照

| 資料夾 | 內容 |
|---|---|
| `hero/` | 角色(騎士本人),含 `face_path`/`age`/`traits`/`hp`(目前固定上限 600) |
| `potential/` | 六大素質(STRENGTH/VITALITY/AGILITY/PERCEPTION/INTELLIGENCE/MENTALITY) |
| `skill/` | 技能池與效果 |
| `trait/` | 角色個性/特質(`CharacterTrait`+`TraitController`,資料模型,機制未接) |
| `party/` | 小隊,由多個 `Hero` 組成(`Party.heroes`) |
| `battle/` | 自動戰鬥流程與戰報 |
| `util/` | `GameEnums`(所有列舉)、`Util`(隨機/UUID)、`level_system.gd` |

士兵/武器/陣形系統已整個移除(暫時不需要這些設計)。編制階層是
`Hero`(角色)⊂ `Party`(小隊),`BattleController.get_random_battle()` 直接拿
`Party` 對戰,每個角色各自佔一格獨立作戰(見 `System/battle/battle_hero.gd` 的
`BattleHero`,直接包一個 `Hero`)。小隊人數之後會開放玩家配置與科技研發提升,
目前寫死:1 小隊 = 6 名隨機角色(對應戰場 6 路縱隊)。原本小隊之上還有一層

## 戰鬥系統(System/battle + Scenes/Battle)

`Battle.start()` 一次性把整場戰鬥模擬完,事件存進 `battle.battle_log`;`battle.gd` 事後
依序重播,不影響模擬。事件合約細節、戰場座標/移動/閃避/勝負公式見 Spec.md 一、二。
固定跑 10 回合,總大將沿用現有隊長機制(`Party.leader`/`BattleHero.is_leader`):總大將
陣亡立即分出勝負,雙方總大將都撐過 10 回合則直接判平手,不比較雙方剩餘 HP;角色 HP 歸零
視為戰敗(`defeated` 事件)。

畫面元件已拆分單一職責:`battle.gd`(整合層,重播時連續的 `move`/`daze` 事件會併發
播放 2~3 個加速演示;`attack`/`skill` 則跟緊接在後面的 `dodge`/`damage` 反應事件
合併同時播放,不分先後拍)、`battle_board.gd`(格線/座標換算,必須是獨立節點,插在
`BoardPanel` 之後、`UnitsLayer` 之前,否則會被根節點不透明子節點蓋住)、
`battle_unit_visual.gd`(單一角色動畫/受擊反應/閃避反應/傷害飄字——未命中只晃一下,
不閃白,不再顯示技能名稱橫幅)、`battle_party_roster.gd`(頭像列,含血條、點擊頭像
開啟 `CharacterPanel`;角色行動時頭像會往戰場方向靠近一點提示輪到誰,放技能時
頭像框額外變色高亮,取代舊版頭上飄字)、`battle_log_panel.gd`(戰報文字)。

角色美術暫代:全部共用 `Images/Warrier/animated_sprite_2d.tscn`,動畫全設 loop,
`animation_finished` 不會觸發,等待動畫改用「幀數/播放速度」算時長(`wait_for_animation()`)。

角色頭像:`Images/Face/` 隨機取一張,`FaceController` 指派給 `Hero.face_path`。

## 共用 UI

`CharacterPanel`(autoload,見 `project.godot` 與 `Scenes/CharacterPanel/`)是彈出式角色
資料面板,任何場景呼叫 `CharacterPanel.open_for_hero(hero)` 即可開啟,右上角 × 關閉。

## Unity → Godot 移植備忘

`Guid` → `Util.generate_uuid()`;GDScript 無多載 → 改用 `get_skill_list_by_rank()` 這種
獨立命名;`Skill.range` → `skill_range`(避免蓋掉內建 `range()`)。完整清單見 Spec.md 四。

## 已知待辦

見 [Spec.md](Spec.md) 五。
