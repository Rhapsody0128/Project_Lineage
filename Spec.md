# Spec.md(技術規格,給 AI 助理讀)

分層原則、資料夾對照、戰鬥元件拆分見 [CLAUDE.md](CLAUDE.md)。這份文件補完 CLAUDE.md
沒展開的細節:戰報事件合約、戰鬥數值公式、驗證方式、Unity 移植對照、已知待辦。
遊戲設計概念見 [遊戲企劃設定總整理.md](遊戲企劃設定總整理.md)。

## 一、戰報事件合約(System/battle ↔ Scenes/Battle)

`Battle.start()` 一次性跑完整場模擬,每發生一件事呼叫 `log_event(dict)` 存進
`battle_log: Array[Dictionary]`。事件必須自帶當下快照數值(死傷人數、剩餘兵力等),
因為模擬跑完後物件狀態已是最終值,場景端不能事後回頭讀「目前狀態」。

`battle.gd._play_battle_log()` 事後依序重播(`await`/Tween/動畫),純粹播放結果,不影響
模擬。新增事件型別時:

- 型別放 `event.type`(String)
- 需要對應畫面節點的欄位放 `BattleParty` 物件本身當 Dictionary key(不要只存名字字串,
  否則畫面端沒辦法定位是哪個節點)
- `Battle._format_event()` 補純文字除錯版
- `battle.gd` 的 `match` 補畫面處理分支

## 二、戰鬥數值細節

- 戰場:`GRID_COLS=12`(左右)、`GRID_ROWS=6`(上下),正面棋盤,無斜角投影。我方沿
  最左列、敵方沿最右列置中部署,相向而行。
- 行動(`BattleParty.action()`):`search_enemy()` 找格子曼哈頓距離最近的敵人;權重表
  抽 `ActionType`(ATTACK/DAZE/SKILL 固定各 25,ESCAPE 只在 `hp_ratio<50%` 才列入,
  CONFUSE 保留但抽選池暫關);在攻擊範圍(距離 ≤1)內才出手,否則改移動。
- 移動:`BASE_MOVE_STEPS=2`,敏捷每滿 `AGILITY_PER_EXTRA_STEP=25` 多走 1 格;可穿過
  己方存活角色,只有敵方存活角色擋路,被擋會側移繞路(`_next_step()`);整趟只記一筆
  `move` 事件(含完整 `path`),畫面端連續播放不逐格停頓。
- 閃避:`judge_dodge()`,防禦方 AGI vs 攻擊方 DEX(借用 `perception` 欄位)。
  `dodge_rate = clamp(50 + (防禦AGI-攻擊DEX)*0.225, 5, 95)`,雙方數值 0~200,兩極值都
  保留 5% 保底。

## 三、驗證方式

```
GODOT="/d/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --editor --quit-after 10          # 全專案語法掃描
"$GODOT" --headless --script res://_test_xxx.gd       # 需要時才手動驗證 System 邏輯
```

預設寫完邏輯就好,不用主動寫 `_test_*.gd` 自證——留給使用者實際跑遊戲測試,拿到回報
再針對性 debug。真的需要單獨驗證某段 System 邏輯時才寫,檔名 `_test_` 開頭,驗完必刪,
不留在專案裡。

## 四、Unity → Godot 移植備忘(舊 Unity 專案 `Project_Lineage/`)

- `Guid` → `Util.generate_uuid()`
- C# `Random` 雙重位移寫法有 bug(`Next(min,max)+min`)→ 改用 `randi_range`/
  `randf_range`(整數 `[min,max)`、浮點 `[min,max]` 四捨五入到小數點後2位)
- GDScript 不支援多載 → `getSkillList(weapon)`/`getSkillList(rank)` 改成
  `get_skill_list_by_weapon()`/`get_skill_list_by_rank()`
- 移除死碼:`TroopController`/`PartyController`/`SoldierController` 各自建立過從未使用
  的多餘隨機物件
- 修正拼字:`poistionSkillType`→`position_skill_type`、`Soilder`→`Soldier`、
  `emeny`→`enemies`、`ratioToRankToRank`→`rank_from_ratio`
- `Skill.range` → `skill_range`(避免蓋掉內建 `range()`)

## 五、已知待辦

- `Skill.skill_range` 已存在但未使用,`_in_attack_range()` 固定「相鄰即可」,還沒依
  射程做遠程攻擊判定
- 陣形(`Formation`)只有一種寫死的方陣,尚未支援玩家自訂編隊
- 個性/特質(`System/trait/`)只有資料模型(名稱+描述+正負中性)與抽樣池(目盲/勇猛/
  膽小三選二),機制效果(命中率/AI 傾向等)尚未接上
- 血統/學院/婚姻/城鎮/英靈殿等企劃概念尚無對應 System 模組
- CONFUSE(叛變攻擊己方)機制已寫好但抽選池暫時關閉,等魅惑狀態系統接上再開放
- 專案尚無獨立 DEX 屬性,閃避公式暫借用 `perception` 欄位代替
- `Hero.age` 目前只是產生時隨機指定的靜態數值,尚無老化/死亡/婚姻等生命週期機制
