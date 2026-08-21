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
- **`Scripts/`**:非戰鬥場景零散 UI 腳本,含 `Autoload/`(全域單例,例如 `BattleReportStore`/
  `SceneHandoffStore`——負責場景間資料交接/session 狀態,不是戰鬥規則,所以放這裡而不是
  `System/`)與 `UI/`(共用畫面小工具,例如 `UiStyle` 的邊框樣式 helper)。不是 autoload、
  也不是 UI 元件的零散共用資料類別(例如 `SceneHandoff` 信封)直接放 `Scripts/` 這層,
  不要塞進 `Autoload/`——那個子資料夾只放真的註冊進 `project.godot` 的單例。
- **`Images/`**:美術素材與對應小型 `.tscn`(角色動畫 Scene 等)。

## System/ 資料夾對照

| 資料夾 | 內容 |
|---|---|
| `character/` | 角色(騎士本人),含 `face_path`/`age`/`traits`/`hp`(目前固定上限 600);`aging_rule.gd`/`character_death_controller.gd` 是老年/死亡規則,見下方「老年與死亡」 |
| `potential/` | 六大素質(STRENGTH/VITALITY/AGILITY/DEXTERITY/INTELLIGENCE/MENTALITY) |
| `skill/` | 技能池與效果,依主動/被動/LEADER 分類(`SkillLibrary` 的 `_active_skills()`/`_passive_skills()`/`_leader_skills()`,用 `SkillBuilder` 鏈式組裝);數值計算/戰鬥表現在 `SkillEffectLibrary`,一律呼叫 `System/battle/combat_resolver.gd` |
| `trait/` | 角色個性/特質(`CharacterTrait`+`TraitController`,資料模型,機制未接) |
| `party/` | 小隊,由多個 `Character` 組成(`Party.characteres`) |
| `battle/` | 自動戰鬥流程與戰報,見下方拆解 |
| `util/` | `GameEnums`(所有列舉+label 靜態函式)、`Util`(隨機/UUID/棋盤距離)、`level_system.gd` |
| `event/` | 大地圖地點事件(酒館搭訕/城門挑戰/閒聊等),共用基底 `LocationEvent`,見下方「事件與跨場景資料交接」 |
| `marriage/` | 聯姻規則(`MarriageRule`:告白資格/成功率判定)與告白 payload(`MarriageProposalRequest`) |
| `time/` | 世界時間曆法(`WorldTime`)與推進/固定事件派發規則(`WorldTimeController`),見下方「世界時間」 |
| `family_tree/` | 從任一角色出發,沿 `Character.parent`/`mate`/`children` 邊做世代分組,產出祖譜樹狀結構(`FamilyTreeBuilder`/`FamilyTreeUnit`),見下方「祖譜」 |
| `nation/` | 六大國家(對應 `GameEnums.BloodlineNation`)的靜態身分資料:國家名稱、低血/高血稱呼(`Nation`/`NationLibrary`),見下方「國家好感度」 |

`battle/` 內部依職責拆成多個檔案,而不是全部塞進單一 `BattleCharacter`:`Battle`(回合迴圈/
佈陣/勝負判定)、`BattleCharacter`(戰場上一個角色的狀態容器:HP/座標/buff/技能表,方法多是
薄封裝,實際算法轉發給下面幾個服務類別)、`BattleAi`(每回合的行動決策:骰行動類型/選
技能/AOE 選目標)、`MovementPlanner`(移動/尋路計算)、`CombatResolver`(閃避/暴擊/守護
判定、傷害/治療施放——`BattleCharacter.attack()` 與 `SkillEffectLibrary` 的技能效果都呼叫
這裡,不再互相呼叫對方)、`StatModifier`(單筆素質加成/減益資料)、`events/`(型別化戰報
事件 `BattleEvent` 子類別,見 Spec.md 一)。

士兵/陣形系統已整個移除(暫時不需要這些設計)。武器(`GameEnums.WeaponType`)保留,但只
作為角色的基本攻擊距離/技能綁定標籤,不是可拾取裝備的武器系統。編制階層是
`Character`(角色)⊂ `Party`(小隊),`BattleController.get_random_battle()` 直接拿
`Party` 對戰,每個角色各自佔一格獨立作戰(見 `System/battle/battle_character.gd` 的
`BattleCharacter`,直接包一個 `Character`)。玩家小隊人數之後會開放玩家配置與科技研發
提升,目前上限固定 6 人(對應戰場 6 路縱隊)。`PartyController.get_random_party()` 生成
的隨機小隊(遊蕩敵人/城門守衛/測試戰鬥共用同一入口)人數與整隊等級改依 `RankType`
(F~SSS)查表決定,不再固定 6 人——難度曲線調參全部集中在 `party_controller.gd` 的
`RANK_LEVEL_RANGE`/`RANK_PARTY_SIZE_RANGE` 兩個常數,之後要調難度曲線只改這裡。

## 戰鬥系統(System/battle + Scenes/Battle)

`Battle.start()` 一次性把整場戰鬥模擬完,事件存進 `battle.battle_log`(`Array[BattleEvent]`,
型別化子類別,見 Spec.md 一);`battle.gd` 事後依序重播,不影響模擬。事件合約細節、戰場
座標/移動/閃避/勝負公式見 Spec.md 一、二。固定跑 10 回合,總大將沿用現有隊長機制
(`Party.leader`/`BattleCharacter.is_leader`):總大將陣亡立即分出勝負,雙方總大將都撐過 10
回合則直接判平手,不比較雙方剩餘 HP;角色 HP 歸零視為戰敗(`DefeatedEvent`)。

畫面元件已拆分單一職責:`battle.gd`(整合層,重播時連續的 `move`/`daze` 事件會併發
播放 2~3 個加速演示;`attack`/`skill` 則跟緊接在後面的 `dodge`/`damage` 反應事件
合併同時播放,不分先後拍;戰報文字可滑鼠懸停看判定明細,見 Spec.md 一;另有暫停/
繼續按鈕與戰鬥結束結果 Dialog)、`battle_board.gd`(格線/座標換算,必須是獨立節點,插在
`BoardPanel` 之後、`UnitsLayer` 之前,否則會被根節點不透明子節點蓋住)、
`battle_unit_visual.gd`(單一角色動畫/受擊反應/閃避反應/傷害飄字——未命中只晃一下,
不閃白,不再顯示技能名稱橫幅)、`battle_party_roster.gd`(頭像列,含血條、點擊頭像
開啟 `CharacterPanel`;角色行動時頭像會往戰場方向靠近一點提示輪到誰,放技能時
頭像框額外變色高亮,取代舊版頭上飄字)、`battle_log_panel.gd`(戰報文字)。

角色美術暫代:全部共用 `Images/Warrier/animated_sprite_2d.tscn`,動畫全設 loop,
`animation_finished` 不會觸發,等待動畫改用「幀數/播放速度」算時長(`wait_for_animation()`)。

角色頭像:`Images/Face/` 隨機取一張,`FaceController` 指派給 `Character.face_path`。

## 共用 UI

`CharacterPanel`(autoload,見 `project.godot` 與 `Scenes/CharacterPanel/`)是彈出式角色
資料面板,任何場景呼叫 `CharacterPanel.open_for_character(character)` 即可開啟,右上角 × 關閉。

`BattleReportStore`(autoload,見 `Scripts/Autoload/battle_report_store.gd`)是全域戰報
存取點與場景間播放交接用的 `pending_report`。跟 `CharacterPanel` 一樣屬於 Scenes 層的
session 單例,兩個 autoload 的定位一致——`System/` 底下不會有需要當 autoload 的例外。

## 祖譜(System/family_tree + Scenes/FamilyTree)

入口只有一處:`Scenes/CharacterRoster/character_roster.gd` 最上方「觀看祖譜」按鈕,對
目前在角色列表選取的那一張卡片開啟(不是隊伍角色、也不是全部角色的清單)。走
`SceneHandoffStore.queue(FamilyTree.FOCUS_MAILBOX_KEY, character)` 交接起點角色,再
`NavigationStore.go_to("res://Scenes/FamilyTree/family_tree.tscn")` 切場景,`family_tree.gd`
的 `_ready()` 用 `take()` 一次性讀出(不是 Dialogue 那種需要撐住 lambda 生命週期的用途)。

`FamilyTreeBuilder.build(focus)`(`System/family_tree/family_tree_builder.gd`)沿
`children`(世代 +1)/`parent`(世代 -1)/`mate`(世代不變)三種邊做 BFS,把 `focus` 所在的
整個連通「親族圖」全部走過一輪——父母、祖父母、配偶、子女、孫子女……只要沿血緣/婚姻邊
連得到都會出現在樹上,不是只往下長。BFS 算出來的世代是相對 `focus`(=0)的值,可能是
負數(祖先),走完後整體平移(減去最小值、+1)讓最上層那一代變成世代 1(樹頂)——`focus`
不一定落在世代 1,要看它在整個親族圖裡的實際位置。走完後分組成 `FamilyTreeUnit`(一對
夫妻或一個單身角色)。已知限制:若某個子孫的配偶本身也是樹內已出現的血親(表親聯姻),
理論上會有兩條血親線可以連到上一代,`_find_parent_unit()` 只認第一個找到的,不畫第二條線,
避免變成非樹狀的蜘蛛網(遊戲企劃設定總整理.md 二十三節已列為已知的未來問題,
`family_tree` 這版不處理)。

死亡角色(`Character.is_dead`,見「老年與死亡」)一樣會出現在樹上(死亡不影響
`parent`/`mate`/`children` 參照),卡片不特別反灰,只在「年齡」那一列數值後綴
「(已故)」(`FamilyTreeCanvas._build_person_column()`),跟 `CharacterDetailView`
彈出面板的年齡欄呈現方式統一。

`Scenes/FamilyTree/family_tree_canvas.gd` 的 `FamilyTreeCanvas` 拿到 `FamilyTreeUnit` 陣列後
自己算版面座標(後序遞迴分配 x slot、`generation` 決定 y)手動 `position`/`size` 每張卡片、
覆寫 `_draw()` 畫世代間的直角連接線——這一層是純版面/像素計算,不是規則邏輯,所以留在
Scenes 而不是 System(比照 `battle_board.gd` 的格線/座標換算)。卡片沒有配偶時只留一欄,
不留空欄佔位——所以卡片寬度分 `CARD_WIDTH_SINGLE`/`CARD_WIDTH_COUPLE` 兩種,但排版仍統一
用較寬那個當 slot 間距置中對齊,卡片幾何中心永遠等於「本人與配偶之間的中線」(單人卡就是
那一欄的中線),連接線直接讀這個中心點。卡片內容(頭像/姓名/年齡/性別/血統清單+計量表)
跟 `CharacterDetailView._populate_bloodline()` 同一套資料來源/配色(`Bloodline.
get_nonzero_entries()` + `GameEnums.bloodline_full_label`/`bloodline_nation_color`),血統
清單固定只留約 3~4 條的高度,超過用內部 `ScrollContainer` 捲動、不撐高卡片。整欄
(不只小頭像)都能點擊開 `CharacterPanel`,且 `ScrollContainer` 範圍內按住可拖曳平移
(`FamilyTreeCanvas._input()`,不受卡片 `mouse_filter=STOP` 影響;拖曳距離超過門檻才算
「有拖曳」,放開時才不會被誤判成點擊開錯面板)。

## 國家好感度(System/nation + NationFavorStore)

`Nation`/`NationLibrary`(`System/nation/`)是六大國家(`GameEnums.BloodlineNation`)的靜態
身分資料:國家名稱、低血/高血稱呼,全部直接呼叫 `GameEnums.bloodline_nation_label()`/
`bloodline_full_label()` 組出來,不重複維護一份標籤表——`NationLibrary.get_all()`/
`get_by_id()` 是唯一取用入口,呼叫端不要自己 `Nation.new(id)`。

玩家對每個國家的好感度是會變動的玩家資料,不是靜態規則,所以不放在 `System/nation/`,
比照 `BaseResourceStore` 的慣例存在 `NationFavorStore`(autoload,
`Scripts/Autoload/nation_favor_store.gd`):`Dictionary` 存 `國家 id → 好感度`,
`get_favor(nation_id)`/`add_favor(nation_id, amount)`,`changed` 訊號供 UI 即時刷新。累積
好感度數值→`GameEnums.RankType`(F~SSS)等級的門檻表是靜態規則,放在
`System/nation/nation_favor_rank.gd`(`NationFavorRank.rank_for_favor()`/
`label_for_favor()`),不放進 `NationFavorStore`。「依好感度升級城鎮功能」仍是之後的事,
目前只有等級查詢,沒有任何解鎖效果。

遊蕩者(`RoamingEnemy`)打贏會替一個國家加好感度:生成時
`RoamingEnemySpawner._nearest_town_nation()` 依生成座標找離它最近的城鎮
(`MapObject.get_all()` 篩 `MapObjectType.TOWN`),把該城鎮的 `nation` 一併帶進
`PartyController.get_random_party(rank_type, nation)`,讓「這附近的盜賊」統一是那個國家的
血統(`Party.nation_type`,比照 `Party.rank_type` 只在明確指定 nation 時才有值)。戰鬥
結算時 `Battle.enemy_nation_type` 沿用 `enemy_party.nation_type`,`System/battle/
battle_reward.gd` 的 `grant_victory_favor(battle)` 依 `enemy_rank_type` 查
`RANK_NATION_FAVOR` 表發好感度給該國家——只有贏才加,戰敗/平手不倒扣,呼叫點跟
`grant_victory_exp`/`settle_money` 是同一組(見「戰鬥系統」節)。

## 世界時間(System/time + WorldTimeStore)

`WorldTime`(`System/time/world_time.gd`)是純曆法算式(12 個月/每月 30 天/全年 360 天,
架空紀年、不對應真實西元/BC,遊戲開始固定是 `START_YEAR` 年 1 月 1 日,年份只會往上加不會
往回推算,見檔案內註解),`WorldTimeController`(`System/time/world_time_controller.gd`)
包一層「推進後跨過幾天邊界」的偵測,逐天派發已註冊的 day/month/year 固定事件——不是每
frame 觸發,是每跨過一天才觸發一次,快轉一次跳好幾天一樣會逐天觸發,不會漏掉中間的月/
年事件。兩者都是 `RefCounted`,不自己跑迴圈。

`WorldTimeStore`(autoload,`Scripts/Autoload/world_time_store.gd`)是這個 controller 唯一
的持有者,應用程式全程存活,取代舊版「`WorldTime` 由 `Scenes/Map/map.gd` 自己 `new`、進出
地圖手動把 `day_accumulator`/`is_playing` 存進 `MapSessionStore` 再讀出來還原」的作法——
現在世界時間不會因為玩家離開/返回大地圖而重置。實際推進(`advance(delta)`)綁在
`HeaderBar._process()`(見下方 HeaderBar 說明),不是綁在個別場景腳本:只要場景掛了
`HeaderBar`,`is_playing` 為真時世界時間就會走;沒掛 `HeaderBar` 的場景(例如 MapLocation
的地點選單)本來就把 `is_playing` 停在 `false`,不需要推進。這樣任何掛了 `HeaderBar` 的
新場景會自動獲得走時間的能力,不用自己再持有一份 `WorldTime` 或手動呼叫 `advance()`。

其他系統要在「跨過一天/月/年邊界」時收到通知,兩種管道擇一:

- System 層(RefCounted 規則邏輯):直接呼叫
  `WorldTimeStore.controller.register_day_event()`/`register_month_event()`/
  `register_year_event()`,傳入的 `Callable` 會被永久保存,注意下方「RefCounted 生命週期
  陷阱」——裸方法參照撐不住呼叫端物件的引用計數。
- Scenes 層(場景腳本):接 `WorldTimeStore` 的 `day_passed`/`month_passed`/`year_passed`
  訊號即可(見 `map.gd` 用 `day_passed` 驅動小隊 HP 自然回復,`Character.advance_hp_regen()`),
  Node 的訊號連線會在場景節點釋放時自動斷開,不會殘留、也不會像上面 Callable 陣列那樣
  越存越多。

`HeaderBar`(`Scripts/UI/header_bar.gd`)是完全自給自足的共用頂部列,呼叫端只要
`HeaderBar.new()` 掛進場景的 CanvasLayer 就好,不需要接訊號或每幀同步任何狀態——倍速
按鈕(`▶️1x`/`▶️2x`/`▶️3x`/`⏩DEMO` 四顆互斥單選按鈕,`ButtonGroup` 確保同時只有一顆
按下)點下去、或鍵盤 1/2/3/4,都在 `HeaderBar` 內部直接呼叫
`WorldTimeStore.set_speed_level(level)`;Space 鍵直接呼叫 `WorldTimeStore.toggle_playing()`。
`HeaderBar` 是全域唯一的倍速/暫停控制入口,場景腳本(`map.gd`/`base.gd`)不用再各自寫一份
鍵盤 `_unhandled_input()`。四個等級都寫進同一個 `play_speed_multiplier`(1.0/2.0/3.0/100.0,
`SPEED_MULTIPLIERS`)——DEMO(4)只是數字比較大,跟 1x/2x/3x 走同一條路、一樣受
`is_playing` 控管,沒有另開 `Timer` 或繞過暫停的特殊通道。`HeaderBar._process()` 自己拿
這個倍率乘 `delta` 呼叫 `WorldTimeStore.controller.advance()` 推進世界時間、再更新時間
文字,用 `⏩`(播放中且倍速等級是 DEMO)/`▶️`(播放中)/`⏸️`(暫停)三個圖示跟倍速按鈕的
視覺語言呼應。`Scenes/Map/map.gd._process()` 額外拿同一份 `play_speed_multiplier` 套用在
地圖移動速度上(`HeaderBar` 不知道地圖移動這件事,只管世界時間本身),讓走路跟時間流逝
維持同一套加速比例。`HeaderBar` 是全新節點(每次進場景都重新 `HeaderBar.new()`),
`_ready()` 建立按鈕時直接讀 `WorldTimeStore.speed_level` 同步外觀,不需要呼叫端額外同步。

## 老年與死亡(System/character + WorldTimeEventLibrary)

`AgingRule`(`System/character/aging_rule.gd`,`RefCounted`)集中管理兩條隨年齡變化的門檻,
全部是可調常數,方便之後調整/角色差異化(見檔案內註解):`BASE_AGING_LINE`(衰老線,預設
50 歲)、`BASE_DEATH_LINE`(死亡線,預設 80 歲)、`CLINIC_LINE_BONUS_PER_LEVEL`(醫療所
每升一級兩條線各自 +5,不是漸增)。實際門檻 `get_aging_line()`/`get_death_line()` = 基礎值
+ `BaseBuildingProgressStore.get_level(GameEnums.BuildingType.CLINIC) * 5`——CLINIC 最高
9 級時是 95 歲/125 歲,沒有刻意湊整數到 100/130,維持「每級 +5」這個規則本身最單純。死亡
機率 `get_death_chance_percent()` 是加速型曲線(`DEATH_CHANCE_CURVE_EXPONENT`,預設
2 次方):未達衰老線 0%,死亡線以上 100%,中間依比例的平方內插,前期低、接近死亡線才
陡升。

`WorldTimeEventLibrary._age_up()`(每年觸發,見「世界時間」)在幫每個角色 `age_up()` 之後
呼叫 `_process_aging(character)`:年齡跨過衰老線第一次會掛上 `AgingRule.create_aging_trait()`
建立的衰老特性(全素質固定打七折,見下段),之後每年只要還在衰老線以上就
`AgingRule.roll_death()` 骰一次是否過世。玩家固定主角(`Character.is_protagonist`)**不**
豁免——跟角色列表解雇功能特別擋掉主角/隊長是兩回事(解雇是怕玩家手滑卡死流程,老死是
機率自動觸發)。衰老特性一旦掛上不會因為 CLINIC 之後升級、衰老線後退而被摘除,是刻意的
簡化行為(不做「回春」),之後如果要改可以在 `_process_aging()` 加對稱的移除邏輯。

衰老特性透過 `CharacterTrait.stat_multiplier`(預設 1.0,`is_aging` 旗標標記——不比對
`name` 字串,比照 `Character.knows_guard_skill()` 用旗標而非顯示名稱字串比對的既有慣例)
套用:`Character._get_real_potential()` 乘上全部特性 `stat_multiplier` 的連乘
(`_trait_stat_multiplier()`),`strength`/`agility`/...等既有 getter 全部自動套用,不用
另外修改 `CombatResolver`/`BaseProduction`。這個欄位是通用機制,之後其他特性要做類似的
素質加成/減益效果可以直接重用,不必只綁死給衰老特性。

角色死亡的唯一入口是 `CharacterDeathController.kill()`(`System/character/`):依序清掉
`BaseDispatchStore` 的根據地派遣、`PartyStore.grid`/`PartyStore.party`(小隊編成/戰場站位,
含隊長 fallback),確認清乾淨「需要角色實際在場」的地方後才把角色從
`CharacterRosterStore`(可操控池)移除。跟解雇不同的是**不**從 `AllCharacterStore` 移除,
只標記 `Character.is_dead = true`——祖譜(`FamilyTreeBuilder`)是沿 `AllCharacterStore`
裡還存在的 Character 物件走 `children`/`parent`/`mate` 邊,拔掉物件會讓親族圖斷線;死亡
角色仍會出現在祖譜裡與 `CharacterDetailView`(`CharacterPanel`/`CharacterRoster` 共用)的
家族分頁,兩處都不反灰、不改姓名,統一只在「年齡」數值後面加「(已故)」(例如
「64(已故)」),點擊一樣能開 `CharacterPanel` 查看完整資料。`is_dead` 的角色
`Character.age_up()` 直接跳過,不再隨世界時間增齡。

死亡把角色從 `PartyStore.party.characteres` 清掉之後,如果整隊死到淨空(玩家固定主角
不豁免老死,見上方決策),`kill()` 直接 `NavigationStore.go_to("res://Scenes/GameOver/
game_over.tscn")` 切去 GAME OVER 畫面——跟 `System/event/` 底下的 `LocationEvent` 一樣,
RefCounted 規則物件本來就會在需要時直接驅動場景轉換,不是只有 Scenes 層按鈕處理常式才
能切場景。`game_over.gd` 只有兩個出口:「讀取存檔」共用 `SaveSlotPicker.open_load_menu()`
(跟 `HeaderBar`/`Scenes/Base/base.gd` 的讀檔入口同一份邏輯,讀檔成功會自動切去大地圖)、
「回到主選單」`NavigationStore.go_to("res://Scenes/main.tscn")`。GAME OVER 畫面沒有
`HeaderBar`,世界時間本來就不會在這裡繼續推進,不需要額外暫停。

## 事件與跨場景資料交接(LocationEvent + SceneHandoffStore)

大地圖地點事件(`System/event/town/*Event.gd`,例如 `TownTavernEvent`/`TownGateEvent`/
`TownChatEvent`;`System/event/base/*Event.gd`,例如 `/`BaseBuildingEvent`——
「進入根據地」沒有對應事件,`map_location.gd` 直接切場景)共用基底 `LocationEvent`
(`RefCounted`,不是 Node):呼叫端(Scenes 層,
例如 `map_location.gd`/`base.gd` 的按鈕)只呼叫一次子類別的 `trigger(...)`,接下來對話/
戰鬥怎麼串、播完要回哪裡,全部交給事件物件自己接管,文案常數跟流程方法集中寫在同一個
class 裡。事件是 `RefCounted` 而非 `Node`,因為整段流程常橫跨好幾次場景切換(例如
`MapLocation → Dialogue → Battle → Dialogue → MapLocation`),中途發起事件的場景節點早就
被釋放了。

**跨場景資料轉手一律走 `SceneHandoffStore`**(autoload,`Scripts/Autoload/scene_handoff_store.gd`)
這個通用信箱,不要再為每個新情境各開一支 `pending_xxx` 欄位 + Autoload .gd(舊的
`DialogueStore`/`ProposalStore` 已合併掉,不要再新增類似的專用 autoload)。用字串 key
分流不同用途,同一時間可以有好幾筆資料同時待處理(例如 `TownTavernEvent` 一次呼叫
會先 queue `"marriage_proposal"` 給下下個場景用,又 queue `"dialogue"` 給下一個場景用):

- `queue(key, payload, next_scene_path, result_callback)` 存資料,再自己切場景。
- `take(key)` 讀取後立刻清空——一次性用途(例如 `MarriageProposalRequest`)。
- `peek(key)` 讀取後保留不清——目前只有對話系統用,見下方生命週期陷阱。
- payload 型別不限定,呼叫端跟接收端自己約定;資料不只一個欄位時另外寫一個小型
  `RefCounted` 資料類別(比照 `System/marriage/marriage_proposal_request.gd`),裡面放一個
  `const MAILBOX_KEY` 讓兩端共用同一把 key,不要去改 `SceneHandoffStore`/`SceneHandoff`
  (`Scripts/scene_handoff.gd`,純資料信封,不是 autoload)這兩支通用檔案本身。

**對話系統**(`Scenes/Dialogue/dialogue_box.gd`)是最大宗的使用者:`LocationEvent.goto_dialogue()`
把 `Dialogue` 塞進 key `"dialogue"`(常數 `LocationEvent.DIALOGUE_MAILBOX_KEY`)、切去
`dialogue_box.tscn`,`dialogue_box.gd` 讀取時用 `peek()` 而不是 `take()`——因為
`DialogueLine.choices` 裡可能嵌著捕捉呼叫端 `self` 的 lambda(例如 `TownGateEvent`
「闖進去」選項接 `AskBattle.ask(...)`),提早清掉這份參照會讓觸發事件的 `RefCounted`
物件提早被釋放,導致後續 callback 悄悄失效。

**RefCounted 生命週期陷阱(容易踩雷,務必注意)**:`Callable` 綁在方法上時(例如
`SceneHandoffStore.queue(..., _on_result)` 直接傳裸方法名稱)底層只存 `ObjectID`,不會讓
`RefCounted` 的引用計數增加——事件物件沒有其他地方被強參照時,`trigger()`/`_start()`
一返回就會立刻被釋放,`callback` 到了該被呼叫的時候早已失效(`Callable.is_valid()` 悄悄
回傳 `false`,不會報錯,呼叫端多半會 fallback 成別的預設行為,例如直接跳回上一頁、跳過
原本該播的反應對話——非常難察覺,只能靠實際跑一輪整段流程才會發現)。要讓事件物件撐到
callback 真正被呼叫的那一刻,必須包一層 lambda 讓它捕捉 `self`(例如
`func(accepted, a, b): _on_result(accepted, a, b)` 或 `func(): AskBattle.ask(..., _on_result)`),
靠 Variant 對 `RefCounted` 的 `Ref<>` 語意撐住,不能直接傳裸方法參照當 callback。

## Unity → Godot 移植備忘

`Guid` → `Util.generate_uuid()`;GDScript 無多載 → 改用 `get_skill_list_by_rank()` 這種
獨立命名;`Skill.range` → `skill_range`(避免蓋掉內建 `range()`)。完整清單見 Spec.md 四。

## 已知待辦

見 [Spec.md](Spec.md) 五。
