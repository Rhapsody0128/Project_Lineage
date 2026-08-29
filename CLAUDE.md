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

大部分資料夾內容從名稱/檔名即可推知,不重複列舉,只記容易搞混的例外:

- `trait/`:角色個性/特質資料模型(`CharacterTrait`+`TraitController`),機制目前**未接**,不要假設已生效。
- `nation/`:國家的靜態身分資料(名稱、稱呼),是資料定義層;玩家對各國好感度是動態資料,存在
  autoload `NationFavorStore`,不在這裡——見下方「國家好感度」。
- `academy/`:留學規則(`AcademyRule`)——出生當下選國家留學,含國家↔武器對照表,見下方
  「新生兒命名與留學」。
- `time/`/`family_tree/`/`event/`/`battle/`/`skill/`/`character/` 各自的規則細節見下方對應章節。

`battle/` 內部依職責拆成多個檔案,而不是全部塞進單一 `BattleCharacter`:`Battle`(回合迴圈/
佈陣/勝負判定)、`BattleCharacter`(戰場上一個角色的狀態容器:HP/座標/buff/技能表,方法多是
薄封裝,實際算法轉發給下面幾個服務類別)、`BattleAi`(每回合的行動決策:普通攻擊/發呆/撤退/每個已學會的技能全部攤平在同一張情境
權重表裡一次骰選、AOE 選目標,見下方「戰鬥 AI 決策」)、`MovementPlanner`(移動/尋路計算)、`CombatResolver`(閃避/暴擊/守護
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

## 技能系統(System/skill)

120 條技能(武器主動 54、武器被動 6、通用被動 18、大將技 18、血統覺醒技 24)分五個檔案
維護,`SkillLibrary.build()` 只是薄聚合層依序 `append_array()`:`SkillLibraryWeapon`
(六武器各 9 階 F~SSS)、`SkillLibraryWeaponPassive`(六武器各一支反應式被動,不分階級)、
`SkillLibraryPassive`(不綁定武器,9 階各 2 支)、`SkillLibraryLeader`(只有隊長能用,9 階
全隊增益 + 9 階全體敵人減益)、`SkillLibraryBlood`(六大血統各 4 支,限定高血
`Character.can_use_skill()` 的血統守門)。技能數值/效果一律寫在 `SkillEffectLibrary`,
呼叫 `CombatResolver` 判定,不直接碰 `BattleCharacter`。

技能之間的差異靠 `Skill` 資料欄位表達(`effect_stat`/`secondary_stat`+`secondary_ratio`
雙屬性乘區、`mechanics: Array[GameEnums.SkillMechanic]`、`true_hit`/`multi_strike_count`/
`duration_rounds`),不是各寫一個同名微調效果函式——`SkillEffectLibrary` 因此只有一組
「效果配方」(`weapon_attack`/`generic_attack`/`heal`/`shield`/`stat_buff`/`stat_debuff`/
`mechanic_debuff` 等,武器/血統版差異靠 `Callable.bind()` 綁參數),BattleAi 也只看這些
欄位骰選,不看技能叫什麼名字。`SkillMechanic` 目前涵蓋:`ARMOR_PIERCE`/`GUARANTEED_CRIT`
(破防/必定暴擊)、`COUNTER`/`PERFECT_DODGE`/`REACTIVE_HEAL`(武器被動的反應式判定,
`CombatResolver.judge_reactive_trigger()` 共用同一套「固定機率骰一次」)、
`TAUNT`/`SEAL`/`FEAR`/`HEAL_DOWN`/`CLEANSE`(施加前經 `judge_status_resist()` 抵抗判定,
意志/精神越高越容易抵抗)、`EXTRA_HIT_ON_ATTACK`/`AREA_EXPAND_ON_ATTACK`(只影響普通攻擊,
不會讓武器主動技一併觸發)、`DAMAGE_REDUCTION`/`CHANCE_ARMOR_PIERCE`/
`CHANCE_GUARANTEED_CRIT`/`DODGE_COUNTER`/`KILL_MOMENTUM`/`LIMITED_EXECUTE_COUNTER`
(通用被動專用,見 `SkillLibraryPassive` 檔頭註解)、`GRANT_ARMOR_PIERCE`/
`GRANT_GUARANTEED_CRIT`(全隊限時破防/必定暴擊,見 `BattleCharacter.armor_pierce_rounds`/
`guaranteed_crit_rounds`——`duration_rounds` 回合內一律生效,不是機率觸發;1 回合天然對應
「每個角色一回合只行動一次」,取代「全隊下一擊無視防禦/必中」這種需要暫時覆寫判定的不可行
設計,見破陣先鋒/常勝威名)。護盾(`SkillType.SHIELD`)是獨立於 HP 之外的緩衝值
(`BattleCharacter.shield_points`,`CombatResolver.apply_damage()` 扣血前先扣這個)。

以下設計已知是簡化/暫代,之後要改直接找對應位置:「攏絡」(魅惑倒戈)只做了抵抗判定,
沒有實際的戰場陣營轉換,亂軍之聲/豹瞳魅惑暫時用恐懼代替(見 `SkillLibraryLeader`/
`SkillLibraryBlood` 檔頭註解)。

## 戰鬥 AI 決策(System/battle/battle_ai.gd)

`BattleAi.take_turn()` 是單一層級的情境權重骰選(`_build_action_chance_map()`),不是
「先骰行動類型、骰到技能才再骰一次」的兩層架構:普通攻擊/發呆/撤退(HP 低於
`ESCAPE_HP_THRESHOLD` 才列入)加上已學會的每個技能,全部攤平進同一張候選表一起比權重。
非顯而易見的規則:

- 普通攻擊、撤退是跟技能公平競爭的戰術選項;發呆權重刻意壓得很低(`DAZE_BASE_WEIGHT`),
  只是「找不到任何值得做的事」時的保底值,不是常態選項。撤退同理不是「HP 低於門檻就強制
  撤退」,而是跟其他候選一起進池子公平競爭,避免行為太機械。
- HEAL 不吃自身 `base_chance`,改依隊友受傷程度動態給權重;BUFF/DEBUFF 對已生效同一組
  修正的目標打折(`STAT_SKILL_ACTIVE_DISCOUNT`)避免重複施放;ATTACK 類依
  `_best_aoe_hit_count()`(以最划算敵人為中心實際打得到幾人)加權,不是看存活敵人總數——
  敵人分散時 AOE 也可能只打到 1 個。
- 被動技能可用 `Skill.ai_weight_multipliers`(key 是 `SkillType`)對普攻+攻擊技能一起套
  AI 個性乘數(`BattleCharacter.ai_personality_multiplier()`),目前無技能使用此欄位,
  之後設計「狂戰」「醫療」類被動可直接掛 `SkillBuilder.ai_weight_multiplier()`。
- 骰選前用 `_shortlist_top_candidates()` 只留權重最高的前 `ACTION_SHORTLIST_SIZE` 個做
  加權隨機,避免用不上的技能稀釋機率。
- 行動順序(`Battle.action_order`,依 action_speed)在回合開始排一次,跟「這一刻該做
  什麼」是分開的兩層——真正輪到時才讀「當下」戰場狀態,不是回合開始就寫死的行動。
- `_build_action_chance_map()` 同一迴圈回傳 `weights`(骰選用)與 `notes`(權重成因,
  併入 `action_detail` 供戰報 UI 懸停顯示),兩者保證同步,不會分開算導致兜不起來。

## 共用 UI

`CharacterPanel`(autoload,見 `project.godot` 與 `Scenes/CharacterPanel/`)是彈出式角色
資料面板,任何場景呼叫 `CharacterPanel.open_for_character(character)` 即可開啟,右上角 × 關閉。

`BattleReportStore`(autoload,見 `Scripts/Autoload/battle_report_store.gd`)是全域戰報
存取點與場景間播放交接用的 `pending_report`。跟 `CharacterPanel` 一樣屬於 Scenes 層的
session 單例,兩個 autoload 的定位一致——`System/` 底下不會有需要當 autoload 的例外。

`CharacterSelectBar`(`Scenes/CharacterSelect/character_select_bar.gd`,純 script Control,
不是 autoload)是共用的「角色頭像網格 + 排序/篩選」元件,取代各畫面各自重複的選人清單
寫法:`setup(characters, card_factory, initial_sort_key, show_weapon_filter)` 灌資料,
`card_factory` 是 `func(character) -> Control`,回傳的卡片要有 `character`/`selected`
屬性跟 `character_selected` 訊號(`CharacterAvatarCard` 頭像卡就符合這個形狀)。這個元件
不含自己的 `ScrollContainer`,設計上配合下方彈出面板殼使用,一律不切場景。

近全螢幕/近大彈窗的內容一律走同一層共用外殼——`ActionPanel`(autoload,
`Scenes/ActionPanel/action_panel.gd`)。寬度/外框/標題列/× 關閉鈕全部只由這一層控制,
不疊多層 CanvasLayer 互相影響(舊版 `FullscreenOverlay` 已移除)。非顯而易見的規則:

- `open_custom(title, content, on_close, min_size)` 是**取代**而不是疊加——換內容時舊
  content 會被 `queue_free()`。呼叫端要「取消回到前一步」不能單純 `close()` 復原,要在
  `on_close` 裡重新呼叫建構前一步內容的入口,重開一份全新 content,不能復用已釋放的舊
  content。`close(trigger_callback)` 傳 `false` 表示呼叫端已自行決定好下一步,蓋掉預設
  `on_close` 續接,避免兩條後續流程搶著跑。
- content 內部任何可能超出自身框架的子區塊(清單/網格)要呼叫
  `ActionPanel.wrap_scrollable(control)` 取得已設好樣式的 `ScrollContainer`,不要各自
  手刻,也不要放著讓外層 `ItemsList` 的 `ScrollContainer` 整包被撐高變成捲動整個面板。
  content 本身要設 `size_flags_vertical=EXPAND_FILL`,否則版面會被壓縮成一小條。
- 內容的操作按鈕一律用 `ActionPanel.set_title_action_button()` 塞進標題列跟 × 同一行,
  不要在內容底部另排一排。跟 × 功能重複的「取消/婉拒」鈕直接刪除(× 本來就觸發
  `on_close`);只有「取消當前多步驟操作、回到同一個 content 的前一步」這種**不**等同
  關閉整個 ActionPanel 的取消鈕才保留在內容區塊裡。

`CharacterSelectOverlay`(`Scenes/CharacterSelect/character_select_overlay.gd`)是唯一
例外——`extends CanvasLayer` 自成一層(layer 比 ActionPanel 高),不借用 ActionPanel,
因為它經常需要疊加在「目前已開著的 ActionPanel 內容之上」而不取代它(例如根據地建築
面板開著時彈出的派遣/兵營/領導人選人清單)。外觀沿用 ActionPanel 的視覺語言與
`DEFAULT_MIN_SIZE`,內部塞 `CharacterSelectPanel`(左側 `CharacterDetailView` + 右側
`CharacterSelectBar`)。呼叫端 `new()` 塞進場景樹、呼叫 `open_picker(...)`,`close()`
時自己 `queue_free()`——不是 autoload 單例,疊上來時底下的 ActionPanel 內容不受影響。

## 兵營(System/base + Scenes/Base/barracks_*.gd)

兵營六大項目——傳授/歷練/戰場擴充/戰術格開發(空殼)/隊長訓練/變換隊形——`BarracksPanel`
只是嵌在 `base_action_panel.gd` 裡的總覽(`_build_barracks_panel()` 掛載,六顆按鈕列表,
寫法比照 `_build_warehouse_section()` 直接把內容加進 `self`),**每顆按鈕各自呼叫
`ActionPanel.open_custom()` 開一份全新內容**(比照 `_open_weapon_craft_panel()` 寫法,
`on_close` 一律回 `BaseBuildingEvent.open_action_panel(building)`),不是原地切換內容——
六個子畫面(`BarracksTeachPanel`/`BarracksExpeditionPanel`/`BarracksGridExpandPanel`/
戰術格開發用的就地小 `content`/`BarracksLeaderTrainingPanel`/`BarracksFormationPanel`)
各自獨立場景腳本。原本「角色自己單獨學技能」的自學訓練(`BarracksTrainingStore`/
`BarracksTraining`)已整個刪除,被「傳授」(師徒制)完全取代。

角色技能數量上限 `Character.MAX_SKILLS`(=4,`CharacterDetailView.SKILL_SLOT_COUNT` 引用
同一個常數,不重複定義)是**規則層限制**,不只是 UI 固定畫 4 格。任何學技能的地方都要走
唯一入口 `SkillLearnFlow.try_learn(character, skill, on_done)`:技能格未滿直接學會;已滿
彈全域 autoload `SkillReplaceDialog`(CanvasLayer,純程式碼組節點無 `.tscn`,外殼比照
`AskBattle` 的 DimBg+CenterContainer+PanelContainer 公式,`layer=40` 蓋過
`CharacterSelectOverlay` 的 30)讓玩家選替換掉哪一個技能或放棄學習,替換/放棄都由
`SkillReplaceDialog` 自己完成 `skill_list` 異動。`on_done(applied: bool)` 只有 `true`
(真的學會/替換成功)才該執行有副作用的後續(師父 `taught_skill_count` 遞增、隊長訓練扣
金幣),放棄學習不該有任何副作用。傳授/隊長訓練/歷練收成(見下)三個呼叫點共用同一套。

- **傳授**(`BarracksTeachPanel`):左 `CharacterDetailView` + 右上師父/學生兩個槽位
  (點擊切換 `_pick_target` 再從下方 `CharacterSelectBar` 選人)+ 師父技能清單(可點選,
  旁邊另有學生已學技能唯讀清單方便對照,不能選)+ 標題列(跟 × 同排)「傳授」鈕兩者+
  技能都選了才能按。師父把自己 `skill_list` 裡的技能教給學生,立即生效(不花資源/天數)。
  不限傳授次數(`Character.taught_skill_count` 只是累計次數,頁面上方顯示目前選定師父的
  傳授次數供參考,不構成限制),只受兩個限制:師父年齡門檻
  (`BarracksTeachingRule.MIN_TEACHER_AGE_BY_RANK`,F~SSS 等差 -5:
  40/45/50/55/60/65/70/75/80)、技能 rank ≤ 兵營等級。血統覺醒技(`SkillLibraryBlood`)
  內部 `rank` 統一填 F 不代表難度,這裡跟隊長訓練都要用 `SkillRankRule.effective_rank()`
  換算(血統技能一律當 A 級技能看待),不能直接讀 `skill.rank`。傳授成功後師父/學生槽位
  維持選定不清空,方便連續傳授同一組師徒多支技能。
- **歷練**(`BarracksExpeditionPanel`,版面比照 `WorkerDispatchPanel` 三塊式——左詳情/
  右上名額格/右下角色清單點卡片即派遣,但這裡本身已是獨立 ActionPanel 畫面,不用再包一層
  `CharacterSelectOverlay`):派角色出去固定一年(`WorldTime.DAYS_PER_YEAR`),名額 = 兵營
  等級(滿等 9 人,送出當下若角色在小隊裡且非隊長會自動移出小隊,寫法比照
  `BaseDispatchStore.dispatch()`;隊長不能送去歷練)。`BarracksExpeditionStore`
  (autoload)逐日倒數,天數歸零當下就結算好(技能池比照傳授的 rank cap 概念、
  `randi_range(1,2)` 抽技能 + `BattleReward.exp_for_expedition()` 給滿額經驗,不像月結算
  派駐只給 10%),但存進「待確認」桶,角色狀態顯示 `GameEnums.CharacterStatus.ON_EXPEDITION`,
  要玩家自己點名額格(顯示「待確認」角標)才真正發技能/經驗、恢復可操作——技能發放要先
  逐一跑過 `SkillLearnFlow`(一次可能 1~2 個,可能連續彈 `SkillReplaceDialog`)才呼叫
  `BarracksExpeditionStore.finalize_collect()`,所以 `collect()` 拆成唯讀的
  `get_completed_skills()` + `finalize_collect()`(只管經驗/清紀錄/發 NEWS)兩段。臨時
  召回(`recall()`,點「剩 N 天」角標,`ConfirmDialog` 二次確認)不結算任何獎勵。偶遇事件
  特性(trait)機制未接,這次刻意不實作,只在 `_roll_result()` 留掛勾點註解。
- **戰場擴充**(`BarracksGridExpandPanel`):花科研點數(`GameEnums.ResourceType.RESEARCH`)
  指定解鎖 `PartyStore.grid`(6x6 戰場編成格)的任一格,花費依已解鎖格數等差遞增
  (`GridExpansionRule`,5/10/15/20……)。跟 `party_edit.gd` 的「加大格子(D)」DEMO 按鈕
  (隨機解鎖、免費,純測試用)並存,兩者互不影響,`PartyEditGrid.unlock_cells()` 本身是
  聯集寫入。這裡不重用 `PartyEditBoard`(那顆的座標常數是為 `party_edit.tscn` 滿版場景
  量身訂做),自己用 `BoardTileRenderer` 畫一份縮小版棋盤,頁面上會顯示目前科研存量。
- **隊長訓練**(`BarracksLeaderTrainingPanel`,版面比照傳授但只有一個角色槽位,技能清單
  緊接在槽位下方同頁展開):花金錢(`LeaderTrainingRule.GOLD_COST_BY_RANK`)學會
  `SkillLibraryLeader` 的隊長技能(增益/減益都算),不限定角色是否為現任隊長——隊長技能
  誰都能學,只有戰鬥中 `BattleCharacter.is_leader` 才會被納入行動候選,兵營端不重複擋。
  只有真的學會(含技能滿 4 替換成功)才扣金幣,放棄學習不扣款。
- **變換隊形**(`BarracksFormationPanel`):頁面頂部顯示倉庫目前金錢存量,角色槽位選定後
  展開 `BattleCostView` 隊形預覽 + 兩顆按鈕花金錢重抽角色的 `BattleCost`(戰場佔位形狀),
  格數不變,不經過 `SkillLearnFlow`(跟學技能無關)。「重抽形狀」
  (`BattleCostController.reroll_shape()`,花費 `FormationRerollRule.SHAPE_REROLL_COST`=100)
  重新 flood-fill 長出全新連通形狀;「重抽佔位」(`reroll_anchor()`/
  `BattleCost.rebase_anchor()`,花費 `ANCHOR_REROLL_COST`=50)形狀輪廓不變,只是換一格當
  佔位格(`cells[0]`,站立/旋轉軸心)。重抽後若角色目前在 `PartyStore.grid` 上已有站位,
  不主動核對/搬移合法性,比照「戰場擴充」額外解鎖格只聯集不核對現有站位的既有寬鬆慣例。
- **戰術格開發**:`BarracksPanel` 按鈕 handler 就地建一個只顯示「開發中」的最小 content,
  不另開檔案,之後有詳細設計再回來擴充/搬成獨立檔案。

## 祖譜(System/family_tree + Scenes/FamilyTree)

入口只有一處:角色列表最上方「觀看祖譜」按鈕,對目前選取的那張卡片開啟,走
`SceneHandoffStore` 交接起點角色後切場景,`take()` 一次性讀出。

`FamilyTreeBuilder.build(focus)` 沿 `children`/`parent`/`mate` 三種邊做 BFS,走完整個
連通親族圖(不是只往下長)。世代是相對 `focus`(=0)的值,走完整體平移讓最上層變世代
1——`focus` 不一定落在世代 1。已知限制:表親聯姻會讓某節點理論上有兩條血親線連到上一代,
`_find_parent_unit()` 只認第一條,不畫第二條,避免樹變蜘蛛網(遊戲企劃設定總整理.md
二十三節已列為已知問題,這版不處理)。死亡角色一樣出現在樹上,不反灰,只在年齡後綴
「(已故)」,跟 `CharacterDetailView` 呈現方式統一。

`FamilyTreeCanvas` 自己算版面座標、手動擺放每張卡片、`_draw()` 畫連接線——純版面計算,
留在 Scenes 而非 System(比照 `battle_board.gd`)。卡片無配偶時只留一欄不佔空欄,但排版
統一用較寬的雙人欄位當 slot 間距置中對齊,幾何中心永遠是「本人與配偶的中線」,連接線讀
這個中心點。`ScrollContainer` 範圍內可拖曳平移(拖曳距離超過門檻才算拖曳,避免放開時被
誤判成點擊開錯面板)。

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
`RoamingEnemySpawner._try_spawn_in_cell()` 依生成座標查
`System/map/map_terrain_mask.gd` 的地圖色塊 mask(`MapTerrainMask.nation_at()`)——
色塊圖(`Images/Map/map_terrain.png`)用六色畫出六國地形範圍,查不到(山岳鏤空/海面/
地圖外「無色區」)就放棄這次生成,不落在任何單一國家身上,所以遊蕩者一定生在某個
色塊範圍內。查到的 nation 帶進 `PartyController.get_random_party(rank_type, nation)`,
不只整隊統一標成 `Party.nation_type`,連隊內每個角色的 `Bloodline` 也一併強制成該國
血統(`BloodlineController.get_random_bloodline(rank, nation)`)。生成後敵人會原地遊蕩
(`RoamingEnemy.advance_wander()`,`WANDER_RADIUS`,移動範圍卡在 `MapTerrainMask` 可行走
處但不限制留在同一國色塊內,可能遊蕩跨過國界),所以真正觸發遭遇(`RoamingEnemyEvent.
_start()`)那一刻,會重新用敵人「目前座標」查一次 mask、覆寫 `party.nation_type`——
好感度/委託獎勵看的是「在哪裡被擊退」(遭遇地點鄰近哪一國),不是牠出生或血統上屬於
哪一國,所以哪一國的血統跑到別國地盤上被打贏,好感度一樣算給遭遇當地那一國。戰鬥
結算時 `Battle.enemy_nation_type` 沿用 `enemy_party.nation_type`,`System/battle/
battle_reward.gd` 的 `grant_victory_favor(battle)` 依 `enemy_rank_type` 查
`RANK_NATION_FAVOR` 表發好感度給該國家——只有贏才加,戰敗/平手不倒扣,呼叫點跟
`grant_victory_exp`/`settle_money` 是同一組(見「戰鬥系統」節)。遭遇對話的背景圖
(`RoamingEnemyEvent._background_path()`)同樣是查敵人目前座標的地形,不是牠的血統國家。
各地形產出的遊蕩者稱呼不是統一的「強盜」,依 `GameEnums.terrain_bandit_label()`
(平原→強盜/山地→山賊/高原→異端/森林→綠林者/沙漠→沙匪/冰原→浪跡者)換算文案,城堡
攻略(`CastleSiegeEvent`)、討伐委託文案(`QuestLibrary`)共用同一份對照表
(`GameEnums.bandit_label_for_nation()`)。

## 消息(System/news + NewsStore)

`NewsEntry`(`System/news/news_entry.gd`)是一則永久留存的消息紀錄(遊戲內時間文字 +
系統時間文字 + 內容 + 分類 + 已讀旗標),`NewsController.post(content, category)`
(`System/news/news_controller.gd`)是唯一寫入端,一步到位建立 `NewsEntry` 存進
`NewsStore`(autoload,`Scripts/Autoload/news_store.gd`)——其他系統要發布消息一律呼叫
這支,不直接碰 `NewsStore`。`category` 是 `GameEnums.NewsCategory`(`MAJOR`/`DAILY`,
對應 `Scenes/News/news_list.gd` 的「重大」/「日常」分頁),呼叫端一律要明確指定,故意不給
預設值——目前 `MAJOR` 是角色生老病死等重大人生事件(成年/衰老/懷孕/生產/結婚/死亡,見
`WorldTimeEventLibrary`/`CharacterDeathController`/`BaseMarriageEvent`/
`TownTavernEvent`),`DAILY` 目前只有兵營學會技能(傳授/歷練歸來,見
`Scenes/Base/barracks_panel.gd`/`Scripts/Autoload/barracks_expedition_store.gd`),之後
會陸續加入更多瑣碎事件。委託完成(`QuestStore._grant_reward_and_complete()`)只跳 `MessageBar`
提示,刻意不寫進 `NewsController`——不算重大事件,也不想讓「日常」分頁被委託洗版。

未讀機制:`NewsEntry.is_read` 新建時預設 `false`,`NewsStore.mark_category_read(category)`
把該分類目前所有消息一次標記已讀。`news_list.gd` 打開分頁畫面時,先讀每則消息當下的
`is_read` 狀態決定要不要在列尾畫紅色未讀圓點,清單建完才呼叫 `mark_category_read()`——
不能反過來,不然圓點畫出來當下就被自己清掉。只標記「目前看得到的那個分頁」(`_tabs.
current_tab`),切到另一個分頁時才由 `tab_changed` 訊號補標記——沒點開過的分頁不會被
悄悄標成已讀。存檔沿用既有慣例(見下方「世界時間」等節),`category`/`is_read` 都寫進
`to_save_data()`/`load_save_data()`;讀取舊存檔(沒有這兩個欄位)時 `category` 預設當
`MAJOR`、`is_read` 預設當 `true`,避免舊存檔一次跳出一大堆補標的未讀消息。

## 世界時間(System/time + WorldTimeStore)

`WorldTime`(架空曆法算式,見檔案內註解)與 `WorldTimeController`(推進後偵測跨過幾天
邊界、逐天派發已註冊的 day/month/year 事件——不是每 frame 觸發,快轉跳好幾天也會逐天
補發,不漏中間的月/年事件)都是 `RefCounted`,不自己跑迴圈,由 `WorldTimeStore`
(autoload)全程持有,取代舊版進出地圖手動存讀 `day_accumulator` 的作法——世界時間不會
因為離開/返回大地圖而重置。

推進(`advance(delta)`)綁在 `HeaderBar._process()`,不綁個別場景腳本:場景只要掛了
`HeaderBar` 就自動獲得走時間能力,不用自己持有 `WorldTime` 或手動呼叫 `advance()`;沒掛
`HeaderBar` 的場景(例如 MapLocation 選單)`is_playing` 本來就停在 `false`。

其他系統要在跨日/月/年邊界收到通知,兩種管道擇一:System 層呼叫
`WorldTimeStore.controller.register_day_event()`/`_month_event()`/`_year_event()`(傳入
`Callable` 永久保存,注意下方「RefCounted 生命週期陷阱」——裸方法參照撐不住引用計數);
Scenes 層直接接 `day_passed`/`month_passed`/`year_passed` 訊號(隨場景節點釋放自動斷開,
不會越存越多)。

`HeaderBar` 是自給自足的共用頂部列,只要 `new()` 掛進場景就好,不需接訊號或每幀同步。
倍速按鈕(1x/2x/3x/DEMO,`ButtonGroup` 互斥)與 Space(暫停)都直接呼叫
`WorldTimeStore.set_speed_level()`/`toggle_playing()`,是全域唯一的倍速/暫停入口,場景
腳本不用各自寫鍵盤輸入處理。DEMO 只是 `play_speed_multiplier` 數字比較大,跟 1x/2x/3x
走同一條路、一樣受 `is_playing` 控管,沒有另開 Timer 或繞過暫停的特殊通道。
`Scenes/Map/map.gd._process()` 額外拿同一份倍率套用在地圖移動速度上(HeaderBar 本身不知道
地圖移動,只管世界時間),讓走路跟時間流逝維持同一套加速比例。

## 老年與死亡(System/character + WorldTimeEventLibrary)

`AgingRule`(`System/character/aging_rule.gd`)集中管理衰老線/死亡線兩條門檻,兩者都會隨
CLINIC 建築等級提升而後退(數值見檔案內常數)。死亡機率曲線是加速型(前期低、接近死亡線
才陡升),不是線性內插。

`WorldTimeEventLibrary._age_up()`(每年觸發)幫角色 `age_up()` 後呼叫 `_process_aging()`:
跨過衰老線第一次掛上衰老特性(全素質打折),之後每年在衰老線以上就骰一次死亡。玩家固定
主角**不**豁免老死——跟角色列表解雇功能特別擋掉主角/隊長是兩回事(解雇是防手滑卡流程,
老死是機率自動觸發)。衰老特性掛上後不會因 CLINIC 升級、衰老線後退而摘除,是刻意的簡化
(不做「回春」)。

衰老特性透過 `CharacterTrait.stat_multiplier`(通用欄位,`is_aging` 旗標標記,不比對
name 字串)套用,`Character._get_real_potential()` 乘上全部特性的 `stat_multiplier` 連乘
——之後其他特性做類似素質加成/減益都可直接重用這個欄位,不必只綁死給衰老特性。

角色死亡的唯一入口是 `CharacterDeathController.kill()`:依序清掉根據地派遣、小隊編成/
戰場站位(含隊長 fallback)後才把角色從 `CharacterRosterStore`(可操控池)移除。跟解雇
不同的是**不**從 `AllCharacterStore` 移除,只標記 `is_dead = true`——祖譜沿
`AllCharacterStore` 裡的 Character 物件走親緣邊,拔掉物件會讓親族圖斷線。死亡角色仍會
出現在祖譜與角色詳情的家族分頁,不反灰、不改名,只在年齡後綴「(已故)」。

衰老/死亡的狀態變化(掛衰老特性、`is_dead` 標記)對 `AllCharacterStore` 裡所有角色一律
照跑,但 NEWS/MessageBar 通知(`WorldTimeEventLibrary._process_aging()` 的衰老文案、
`CharacterDeathController.kill()` 的死亡文案)只在角色死亡/衰老當下**還在**
`CharacterRosterStore` 裡才發——配偶、未成年小孩本來就不在 roster 裡也要正常衰老/死亡,
但玩家不操控他們,不需要被這些通知打擾;解雇的角色（`is_dismissed`）本來就已經連
`AllCharacterStore` 都被移除,自然也不會再進這兩個函式。

死亡把角色清出小隊後,如果整隊死到淨空(主角不豁免,見上方),`kill()` 直接切去 GAME
OVER 畫面——跟 `LocationEvent` 一樣,RefCounted 規則物件本來就會在需要時直接驅動場景轉換,
不是只有 Scenes 層按鈕才能切場景。GAME OVER 畫面沒有 `HeaderBar`,世界時間本來就不會
在這裡繼續推進。

## 新生兒命名與留學(System/academy + LifeEventQueueStore)

小孩出生(`WorldTimeEventLibrary._deliver_child()`)當下觸發一個全螢幕場景
(`Scenes/LifeEvent/life_event_scene.tscn`),命名跟決定未來留學國家合併在同一個畫面
(不分兩次彈窗,也不用等到 7 歲——出生當下就決定成長方向,是刻意的簡化)。System 層
RefCounted 規則(`_deliver_child()`)直接驅動 Scenes 層切場景,沿用「老年與死亡」一節
`CharacterDeathController.kill()` 直接切場景的同一套慣例。

`LifeEventQueueStore`(autoload,`Scripts/Autoload/life_event_queue_store.gd`)是這個場景
唯一的觸發入口:`queue_child(child)` 把待顯示的小孩塞進內部佇列。第一個小孩用
`NavigationStore.go_to()` 切過去——這個場景沒有 `HeaderBar`,世界時間依既有慣例自動停止
推進,不用另外手動暫停。同一個月有好幾個小孩同時出生時,`_busy` 旗標擋下重複切場景,
場景這邊按下確認後呼叫 `LifeEventQueueStore.finish_current()`:還有排隊中的小孩就用
`get_tree().reload_current_scene()` 原地換下一個小孩重來一輪(不會多推一層
`NavigationStore` 歷史),全部處理完才 `NavigationStore.go_back()` 回到觸發當下玩家原本
所在的場景。這個場景沒有「稍後再決定」的略過機制,只有一顆「確認」鈕,選了留學國家
才能按。

留學選定當下立即生效:`AcademyRule.enroll(character, nation)` 把 `character.weapon`
換成該國對應武器,並用 `SkillController.get_random_initial_skill_list(weapon, noble_rank,
bloodline)`——跟 `CharacterController.get_random_character()` 生成一般角色同一套抽選
邏輯——重骰一次技能表,不是固定塞一支技能。國家↔武器對照(`AcademyRule.NATION_WEAPON`)
沿用《遊戲企劃設定總整理.md》既有企劃表(獅→大劍/鷹→弓/豹→匕首/熊→大盾/龍→法仗/
鹿→捕夢網),跟 `GameEnums.WeaponType`/`BloodlineNation` 兩個 enum 各自的宣告順序不同
(豹/熊對調),查表而非用 enum 值互轉。六國按鈕的說明文字(`AcademyRule.NATION_FLAVOR`)
刻意精簡,是給玩家讀的風味敘述,不是機制說明。

`life_event_scene.gd`(`Scenes/LifeEvent/`)結構比照 `FamilyTree`:固定外框(背景/標題)
寫在 `.tscn`,動態內容(左側 `CharacterDetailView` + 右側命名/選國家)在 `_ready()`
程式化建構;跟 `FamilyTree` 一樣透過 `SceneHandoffStore` 一次性 `take()` 讀入要顯示的
角色(mailbox key 是 `LifeEventQueueStore.MAILBOX_KEY`)。命名輸入框打字當下只更新
`CharacterDetailView` 的姓名文字做即時預覽,真正寫回 `Character.name` 要等按下確認。

## 事件與跨場景資料交接(LocationEvent + SceneHandoffStore)

大地圖地點事件(`System/event/town/*Event.gd`、`System/event/base/*Event.gd`;「進入根據地」
沒有對應事件,`map_location.gd` 直接切場景)共用基底 `LocationEvent`(`RefCounted`,不是
Node):呼叫端只呼叫一次子類別的 `trigger(...)`,接下來對話/戰鬥怎麼串、播完回哪裡全部
交給事件物件自己接管。是 `RefCounted` 而非 `Node`,因為流程常橫跨好幾次場景切換(例如
`MapLocation → Dialogue → Battle → Dialogue → MapLocation`),中途發起事件的場景節點早就
被釋放了。

**跨場景資料轉手一律走 `SceneHandoffStore`**(autoload)這個通用信箱,不要再為每個新情境
各開一支 `pending_xxx` 欄位 + Autoload .gd。用字串 key 分流不同用途,同一時間可以有好幾筆
資料同時待處理、互不覆蓋。這一套只在**真的要切場景**時才需要——不切場景、只是疊加彈出
面板的情境(見「共用 UI」的 `ActionPanel.open_custom()`/`CharacterSelectOverlay`)直接用
closure 傳資料/callback 即可,不要為了套這套 mailbox 模式硬切一次場景。

- `queue(key, payload, next_scene_path, result_callback)` 存資料再自己切場景。
- `take(key)` 讀取後立刻清空,一次性用途;`peek(key)` 讀取後保留不清,目前只有對話系統用
  (見下方生命週期陷阱)。
- payload 型別不限定;資料不只一個欄位時寫一個小型 `RefCounted` 資料類別,放一個
  `const MAILBOX_KEY` 讓兩端共用,不要去改 `SceneHandoffStore`/`SceneHandoff` 這兩支通用
  檔案本身。

**對話系統**(`Scenes/Dialogue/dialogue_box.gd`)讀取時用 `peek()` 而不是 `take()`——因為
`DialogueLine.choices` 裡可能嵌著捕捉呼叫端 `self` 的 lambda,提早清掉參照會讓觸發事件的
`RefCounted` 物件提早被釋放,導致後續 callback 悄悄失效。

**RefCounted 生命週期陷阱(容易踩雷,務必注意)**:`Callable` 綁在裸方法上(例如
`SceneHandoffStore.queue(..., _on_result)` 直接傳方法名稱)底層只存 `ObjectID`,不會讓
`RefCounted` 引用計數增加——事件物件沒有其他強參照時,`trigger()` 一返回就會被釋放,
`callback` 到了該被呼叫時早已失效(`Callable.is_valid()` 悄悄回傳 `false`,不會報錯,
呼叫端多半 fallback 成預設行為,例如跳過原本該播的反應對話——非常難察覺,只能靠實際跑
一輪整段流程才會發現)。要讓事件物件撐到 callback 真正被呼叫,必須包一層 lambda 讓它捕捉
`self`(例如 `func(): AskBattle.ask(..., _on_result)`),靠 Variant 對 `RefCounted` 的
`Ref<>` 語意撐住,不能直接傳裸方法參照當 callback。

## Unity → Godot 移植備忘

`Guid` → `Util.generate_uuid()`;GDScript 無多載 → 改用 `get_skill_list_by_rank()` 這種
獨立命名;`Skill.range` → `skill_range`(避免蓋掉內建 `range()`)。完整清單見 Spec.md 四。

## 已知待辦

見 [Spec.md](Spec.md) 五。
