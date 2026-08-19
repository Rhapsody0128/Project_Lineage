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
| `character/` | 角色(騎士本人),含 `face_path`/`age`/`traits`/`hp`(目前固定上限 600) |
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

入口只有一處:`CharacterDetailView`(`Scenes/CharacterPanel/character_detail_view.gd`)的
「家族」分頁最上面「觀看祖譜」按鈕,對目前分頁顯示的角色開啟。走
`SceneHandoffStore.queue("family_tree_focus", character)` 交接起點角色,再
`NavigationStore.go_to("res://Scenes/FamilyTree/family_tree.tscn")` 切場景,`family_tree.gd`
的 `_ready()` 用 `take()` 一次性讀出(不是 Dialogue 那種需要撐住 lambda 生命週期的用途)。

`FamilyTreeBuilder.build(focus)`(`System/family_tree/family_tree_builder.gd`)裡 `focus`
角色永遠是世代 1(樹的頂端),只沿 `children`/`mate` 兩種邊往下做世代 BFS(走 `children`
邊世代 +1、走 `mate` 邊世代不變)——不追 `parent` 邊,祖譜線一律只往下長,不會往上長出
`focus` 的祖先,才不會因為雙親兩側血緣記錄深淺不一(例如一邊是初始角色沒有記錄祖先、
另一邊往上還有好幾代)讓樹在中途冒出斷頭的孤立節點,看起來像同時往上又往下分裂。走完
`focus` 所在的整個連通「子孫圖」後,分組成 `FamilyTreeUnit`(一對夫妻或一個單身角色)。
已知限制:若某個子孫的配偶本身也是樹內已出現的血親(表親聯姻),理論上會有兩條血親線
可以連到上一代,`_find_parent_unit()` 只認第一個找到的,不畫第二條線,避免變成非樹狀的
蜘蛛網(遊戲企劃設定總整理.md 二十三節已列為已知的未來問題,`family_tree` 這版不處理)。

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
`get_favor(nation_id)`/`add_favor(nation_id, amount)`,`changed` 訊號供 UI 即時刷新。目前
只記錄數值本身,「依好感度升級城鎮功能」是之後的事,這裡先不做任何等級/門檻換算。

## 世界時間(System/time + WorldTimeStore)

`WorldTime`(`System/time/world_time.gd`)是純曆法算式(12 個月/每月 30 天/全年 360 天,
天文紀年,見檔案內註解),`WorldTimeController`(`System/time/world_time_controller.gd`)
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
