# Spec.md(技術規格,給 AI 助理讀)

分層原則、資料夾對照、戰鬥元件拆分見 [CLAUDE.md](CLAUDE.md)。這份文件補完 CLAUDE.md
沒展開的細節:戰報事件合約、戰鬥數值公式、驗證方式、Unity 移植對照、已知待辦。
遊戲設計概念見 [遊戲企劃設定總整理.md](遊戲企劃設定總整理.md)。

## 一、戰報事件合約(System/battle ↔ Scenes/Battle)

`Battle.start()` 一次性跑完整場模擬,每發生一件事呼叫 `log_event(event: BattleEvent)`
存進 `battle_log: Array[BattleEvent]`。事件是型別化的 `BattleEvent` 子類別(見
`System/battle/events/`),每種事件各自一個 `class_name`,欄位固定、建構時就決定型別
(取代早期 `Array[Dictionary]` 的動態欄位設計)。事件必須自帶當下快照數值(傷害量、
剩餘 HP 等),因為模擬跑完後物件狀態已是最終值,場景端不能事後回頭讀「目前狀態」。

`BattleEvent` 基底類別欄位:`event_type`(`GameEnums.BattleEventType` enum)、
`detail: String`(選填,判定/骰值/公式全文)。子類別依需求各自加型別化欄位,例如
`AttackEvent` 有 `actor: BattleCharacter`/`actor_name: String`/`target: BattleCharacter`/
`target_name: String`——需要對應畫面節點的欄位一律放 `BattleCharacter` 物件本身(不要只存
名字字串,否則畫面端沒辦法定位是哪個節點)。

`battle.gd._play_battle_log()` 事後依序重播(`await`/Tween/動畫),純粹播放結果,不影響
模擬。新增事件型別時:

- 在 `System/battle/events/` 新增一個檔案,`extends BattleEvent`,`_init()` 呼叫
  `super._init(GameEnums.BattleEventType.XXX)` 並設定自己的型別化欄位
- `GameEnums.BattleEventType` enum 補上對應的值
- `battle.gd` 的 `match event.event_type:` 補畫面處理分支,需要存取欄位時用
  `event as XxxEvent` 轉型
- `attack`/`skill` 事件在 log 裡永遠緊接著 `dodge` 或 `damage`(`BattleCharacter.attack()`
  的實作保證),`battle.gd._play_battle_log()` 會把這兩筆合併同時播放(見四)——新增
  「攻擊類」事件時如果還是這種「動作+反應」的兩段式,直接沿用這個合併機制即可
- 事件可選帶 `detail: String`(判定/骰值/公式全文),`battle.gd._hint()` 會用
  RichTextLabel 的 `[hint=...]` 標籤包住對應戰報文字,滑鼠移過去就彈出完整說明;
  detail 內容不能含方括號 `[` `]`,會被誤判成 BBCode 標籤提早截斷

## 二、戰鬥數值細節

- 戰場:`GRID_COLS=12`(左右)、`GRID_ROWS=6`(上下),正面棋盤,無斜角投影。我方沿
  最左列、敵方沿最右列置中部署,相向而行。
- 編制:`Character`(角色)⊂ `Party`(小隊,`Party.characteres`),純組織分組,不參與戰鬥判定。
  `BattleController.get_random_battle()` → `Battle._init()` 的 `_attach_battle_characteres()`
  直接把小隊裡的角色攤平成一維陣列,每個角色各自用一個 `BattleCharacter` 包裝、各佔一格
  獨立作戰。目前寫死 1 小隊=6 名隨機角色(對應戰場 6 路縱隊),之後小隊人數會開放
  玩家配置、可被科技研發提升。
- HP:士兵/陣形系統已整個移除,角色直接有自己的 HP(`Character.hp`,上限由
  `Character.COST_HP_MAP` 依 `battle_cost.cells.size()`(佔位格數 3~7)換算:600/700/800/
  900/1000,還沒有依素質/等級計算的公式)。
  `CombatResolver.apply_damage()` 傷害直接扣 `character.hp`,歸零視為戰敗(`DefeatedEvent`)。
  `Character.hp` 跨戰鬥持續累積(`Battle._attach_battle_characteres()` 不再開戰前強制回滿),只能
  靠大地圖世界時間流逝按 `Character.HP_REGEN_PER_DAY`(目前 30/天)自然回復,見
  `Character.advance_hp_regen()`(`Scenes/Map/map.gd` 的 `_process()` 逐幀呼叫)。城鎮選單的
  「休息」選項(`Scenes/MapLocation/map_location.gd`)直接退回大地圖並強制開始播放時間,
  方便玩家停在原地等回血。
- 勝負:固定跑 `Battle.TOTAL_ROUND=10` 回合。總大將沿用現有隊長機制(`Party.leader`/
  `BattleCharacter.is_leader`):`Battle.is_decided` 判斷任一方總大將陣亡就提前結束戰鬥;
  `Battle.result`(`GameEnums.BattleResultType`)只看雙方總大將死活決定 `SELF_WIN`/
  `ENEMY_WIN`/`DRAW`,跑滿 10 回合時雙方總大將必定都還存活(否則早就提前結束),此時直接
  判 `DRAW`,不比較 HP。`self_total_hp`/`enemy_total_hp` 只保留給畫面展示用。
- 行動(`BattleCharacter.action()`,決策邏輯在 `BattleAi.take_turn()`):`BattleCharacter.search_enemy()`
  找格子曼哈頓距離最近的敵人(ATTACK/ESCAPE 用);權重表抽 `ActionType`(ATTACK/DAZE/
  SKILL 固定各 25,ESCAPE 只在 `hp_ratio<50%` 才列入,CONFUSE 保留但抽選池暫關)。基本
  攻擊(ATTACK)依武器決定攻擊距離(`GameEnums.WEAPON_BASIC_ATTACK_RANGE`:近戰劍/盾/
  匕首=1、遠程弓/法杖/捕夢網=2),在範圍內才出手,否則先往目標移動一次再重新檢查;若
  已經在射程內但距離小於射程(遠程武器才有意義,`atk_range>1`),會先用
  `BattleCharacter.kite_to_max_range()` 退到剛好等於射程再出手,拉開跟敵人的距離、不會退出
  射程外浪費這次攻擊。SKILL 改成先抽出實際要放的技能,再用
  `BattleAi._pick_aoe_primary_target()` 從存活敵人中選「以該敵人為中心可以命中最多
  目標」的一個當主要目標(單體技能命中數恆為 1,同分退化成選最近敵人,行為等同舊版);
  用該技能自己的 `Skill.skill_range` 判斷能不能出手(不是武器距離),不夠近一樣先移動、
  以該技能射程為目標距離,已經在範圍內但距離小於射程一樣會 `kite_to_max_range()` 退到
  剛好等於射程,移動後仍搆不到就不出手,不會退化亂放。技能施放權重目前直接採技能本身
  的 `base_chance`(沒有武器/陣形位置加成)。移動/尋路的實際路徑計算在
  `MovementPlanner`,`BattleCharacter.move()`/`move_away()` 只是套用結果、記事件的薄封裝。
- 傷害公式:基本攻擊與技能共用 `SkillEffectLibrary`「武器→攻擊素質/防禦素質」配對
  (`_attack_value()`/`_defense_value()`),差異只在倍率(基本攻擊 1、技能用
  `Skill.skill_ratio`);`_skill_damage()` 的封頂比例只看素質本身,倍率只放大最終傷害。
- 範圍效果:`Skill.area_shape`(SINGLE/RADIUS/LINE/SQUARE)+ `area_size` 決定
  `resolve_targets()` 算出的命中清單,範圍內每個目標各自獨立判定閃避/暴擊/傷害,
  不互相牽連。目前只有火球術是 `RADIUS, 2`,其餘都是 `SINGLE, 1`。
- 移動:`MovementPlanner.BASE_MOVE_STEPS=2`,敏捷每滿
  `MovementPlanner.AGILITY_PER_EXTRA_STEP=50` 多走 1 格;可穿過己方存活角色,只有敵方
  存活角色擋路,被擋會側移繞路;遠程武器/技能在射程內但距離小於射程時會用
  `BattleCharacter.kite_to_max_range()` 退到剛好等於射程再出手。
- 閃避:`CombatResolver.judge_dodge()`,魔法攻擊(`GameEnums.WEAPON_IS_MAGIC`)無視閃避
  必定命中;物理攻擊依防禦方 AGI vs 攻擊方 DEX 算閃避率,公式與常數見函式註解。
- 暴擊:`CombatResolver.judge_crit()`,物理、魔法攻擊都會判定,攻擊方一律吃 DEX,防禦方
  抵抗素質依攻擊種類換(物理吃 VIT、魔法吃 MEN),命中且觸發暴擊時傷害乘上
  `CombatResolver.CRIT_DAMAGE_MULTIPLIER`(1.6),公式與常數見函式註解。畫面端一般傷害
  顯示白字、暴擊顯示紅字放大。
- 技能分類:`Skill.is_passive`(開戰即套用一次或反應式觸發,不吃行動骰選)+
  `Skill.is_leader_skill`(只有隊長能用)+ `Skill.is_guard_skill`(B. 守護專用旗標,
  `CombatResolver.resolve_guard()`/`Character.knows_guard_skill()` 靠這個辨識,不是比對技能
  顯示名稱字串),`SkillLibrary` 依此分成 `_active_skills()`/`_passive_skills()`/
  `_leader_skills()` 三區,用 `SkillBuilder` 鏈式方法組裝(取代舊版 14 個位置參數的
  建構子)。`Skill.skill_type` 決定 `resolve_targets()` 挑目標的陣營(ATTACK/DEBUFF 打
  敵方、BUFF/HEAL/DEFEND 打我方),`AreaShape.ALL_ALLIES` 無視距離命中施法者+全隊。
- 素質修正:`BattleCharacter.add_stat_modifier()` 疊加暫時或永久的素質加成/減益
  (`StatModifier` 資料類別,獨立檔案),`rounds_remaining<0` 是永久(被動技能用),否則
  每 `Battle._round_end()` 倒數 1 回合、到期自動移除;同一個(素質, 倍率)重複套用只會
  刷新回合數,不會無限疊加。
- 守護(盾系被動):`CombatResolver.resolve_guard()` 在單體物理攻擊命中判定前檢查,
  周圍存活友軍裡符合條件(持盾、會守護技能、距離內)的依 VIT 換算機率頂替受擊,
  傷害再打折,公式與常數見函式註解;範圍攻擊不觸發(只擋得住單體)。

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
- GDScript 不支援多載 → `getSkillList(weapon)`/`getSkillList(rank)` 這類重載改成
  `get_skill_list_by_rank()` 等獨立命名
- 移除死碼:多個 Controller 曾各自建立過從未使用的多餘隨機物件
- 修正拼字:`poistionSkillType`→`position_skill_type`、`Soilder`→`Soldier`、
  `emeny`→`enemies`、`ratioToRankToRank`→`rank_from_ratio`
- `Skill.range` → `skill_range`(避免蓋掉內建 `range()`)

## 五、已知待辦

- 士兵(`Soldier`)、陣形(`Formation`)系統已整個移除,暫時不需要這些設計;武器
  (`GameEnums.WeaponType`)保留,但只作為攻擊距離/技能綁定的標籤,不是可拾取裝備的
  武器系統。角色 HP 現在依 `Character.COST_HP_MAP` 隨 battle_cost 格數(3~7)換算
  600/700/800/900/1000,還沒有依素質/等級計算血量的公式
- 小隊編制(`Party.characteres`)目前是寫死的隨機 6 人小隊,還沒有玩家自訂編隊 UI
- 範圍技能命中判定還沒有「目標死活以外」的地形/隊形加成
- `Scenes/Battle/battle_unit_visual.gd` 角色右下角常駐的武器類型文字是測試階段除錯用
  (`SHOW_DEBUG_WEAPON_LABEL` 開關,`WEAPON_LABEL_POSITION` 控制位置),正式美術/UI
  定案後把 `SHOW_DEBUG_WEAPON_LABEL` 改 `false` 或整段移除、改成圖示
- 個性/特質(`System/trait/`)只有資料模型(名稱+描述+正負中性)與抽樣池(目盲/勇猛/
  膽小三選二),機制效果(命中率/AI 傾向等)尚未接上
- 血統/學院/婚姻/城鎮/英靈殿等企劃概念尚無對應 System 模組
- CONFUSE(叛變攻擊己方)機制已寫好但抽選池暫時關閉,等魅惑狀態系統接上再開放
- `Character.age` 目前只是產生時隨機指定的靜態數值,尚無老化/死亡/婚姻等生命週期機制

## 六、血統國家與地理環境對照表

`GameEnums.BloodlineNation` 六國各自對應一種 `GameEnums.TerrainType`(遊戲企劃設定總整理.md
三、六國設定),`GameEnums.bloodline_nation_terrain()` 查表換算:

| 國家 | 地形 |
|---|---|
| 獅(LION) | 平原(PLAINS) |
| 鷹(EAGLE) | 森林(FOREST) |
| 豹(LEOPARD) | 沙漠(DESERT) |
| 熊(BEAR) | 山岳(MOUNTAINS) |
| 龍(DRAGON) | 孤島(ISLANDS) |
| 鹿(DEER) | 高原(PLATEAU) |

`System/map/map_object.gd` 的 `MapObject.nation` 記錄每個地點所屬國家,`terrain_type()`
包一層 `bloodline_nation_terrain()`。目前三座城鎮(獅城/雄城/鷹城)分別對應 LION/BEAR/
EAGLE;`PlayerBase`(玩家根據地)暫時借用 LION 當預設外觀,玩家還沒有可選的自身國家
血統,等那個功能接上再改成真正的選擇結果。

對話背景圖(`Images/Dialogue/`)一律靠 `GameEnums` 的路徑組字函式取檔案路徑,檔名直接對應
enum 成員名稱,不另外維護路徑陣列(降低新增/調整 enum 順序時悄悄對不上的風險):

- `town_background_path(terrain_type)` → `Images/Dialogue/Map/Town/town_<TERRAIN>.png`:
  `Scenes/MapLocation/map_location.gd` 進到 TOWN 地點選單時的整頁背景圖
  (`_update_background()`)
- `BASE_LOCATION_BACKGROUND_PATH` → `Images/Dialogue/Map/Base.png`:
  `map_location.gd` 進到 BASE 地點選單時的整頁背景圖,不分地形(玩家還沒有可選的
  自身國家血統)
- `TOWN_RESIDENTIAL_BACKGROUND_PATH` → `Images/Dialogue/Town/town_residential.png`:
  `System/event/town/town_chat_event.gd`(TownChatEvent)固定用的 Dialogue 背景,
  不分地形(聊天發生在城裡隨處可見的住宅區)
- `CASTLE_INTERIOR_BACKGROUND_PATH` → `Images/Dialogue/Castle/castle_interior.png`,見
  `System/event/base/base_leave_event.gd`,`map_location.gd` 的
  `_on_enter_base_button_pressed()` 直接切去 `base.tscn`
- `base_building_background_path(building_type)` →
  `Images/Dialogue/Base/Building/<BUILDING_TYPE>.png`,見 `System/event/base/
  base_building_event.gd`(BaseBuildingEvent):根據點的建築跳這句 Dialogue,玩家按
  「離開」選項才回 `base.tscn`——建築內部真正的內政操作介面尚未設計,目前只提供
  這個出口,不會自動彈開 `BaseActionPanel`

`Images/Dialogue/Map/Castle/castle_<TERRAIN>.png`、`Images/Dialogue/Map/Landform/
<TERRAIN>.png` 是預留的美術資源,目前尚未接上任何程式碼。

`TownGateEvent`/`TownTavernEvent` 各自已有專屬情境插畫(`town_gate.png`/
`town_tavern.png`,不分地形),不套用這套地形對照表。

## 七、休息安全性(_is_resting)

`Scenes/MapLocation/map_location.gd` 的「休息」按鈕(TOWN/BASE 共用)退回 `map.tscn` 並
直接開始播放世界時間,方便玩家停在原地等 `WorldTimeEventLibrary` 的每日回血——但玩家
角色實際上會原地站在城鎮/根據地座標上,若不處理,路過的遊蕩敵人一樣會撞上觸發
`RoamingEnemyEvent`,變成「休息」反而被打。

修法靠 `MapSessionStore.rest_requested`(一次性旗標,休息按鈕按下時設 true)+
`Scenes/Map/map.gd` 的 `_is_resting`:`map.gd._ready()` 讀到旗標後把玩家頭像
(`player_avatar.visible = false`)藏起來、`_process()` 整段跳過
`_check_roaming_encounters()`(遊蕩敵人資料照常模擬/遊蕩,只是不會撞上玩家)。玩家
主動點地圖移動(`_handle_click_to_move()` 的移動分支)視為醒來,呼叫 `_end_resting()`
恢復頭像顯示與撞敵判定;原地再點一次目前所在的 `MapObject`(重開地點選單)不算移動,
不會結束休息狀態。
