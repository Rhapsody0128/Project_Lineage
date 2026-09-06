# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案

Godot 4.7(GL Compatibility)遊戲專案「Project L」,主場景 `Scenes/main.tscn`,視窗 1600x900。
純 GDScript,無 build/lint/test 工具鏈。

- 事件合約/戰鬥數值公式/Unity 移植對照/已知待辦等深入細節 → [Spec.md](Spec.md)
- 遊戲設計(血統/家族/婚姻/學院等企劃內容)→ [遊戲企劃設定總整理.md](遊戲企劃設定總整理.md)

## 驗證方式

```
GODOT="<實際安裝路徑依機器調整,例如 .../Godot_v4.7.x-stable_win64[_console].exe>"
"$GODOT" --headless --editor --quit-after 10   # 全專案語法掃描
```

執行檔路徑/版本因機器而異,不寫死絕對路徑;沒有 `_console` 版本時,一般 `_win64.exe`
搭配 shell 的 stdout/stderr 重導向(`> log 2>&1`)一樣能正常擷取語法掃描結果。乾淨掃描
會印出專案初始化進度條、以無害的 `WARNING: Scan thread aborted...` 結尾;若額外看到
`Parse Error`/`SCRIPT ERROR` 或指向 `res://System`、`res://Scenes` 的錯誤行,才代表有
語法問題。

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

- `trait/`:角色個性/特質資料模型(`Trait`)+靜態總表(`TraitLibrary`)+隨機抽選
  (`TraitController`),比照 `SkillLibrary`/`SkillController` 的分層慣例。機制效果(命中率/
  戰鬥AI 傾向等)目前**未接**,不要假設已生效;只有 `Trait.title_adjective`(形容詞形態,
  例如「勇猛」→「勇猛的」)已經接上——出生時抽到的第一個特性(`traits[0]`)固定當這個
  人物的形容詞來源(見 `Character.title_adjective`),跟 `NobleTitleRule` 的爵位稱號組合
  進 `Character.title_full_name`,格式「「形容詞+爵位稱號」姓 · 名」,例如「勇猛的騎士」
  威廉 · 華勒斯。`AgingRule` 掛的衰老特性一律 `append()` 加在陣列尾端,不會頂替掉
  `traits[0]` 這個形容詞來源。**`title_full_name` 只給 Dialogue 對話名牌/內文用**
  (`BaseMarriageEvent`/`TownTavernEvent` 搭訕求婚流程的台詞與名牌),其餘一般 UI(角色
  詳情/角色列表/兵營各分頁/酒館招募/聯姻`StrongholdMarriagePanel`與告白
  `MarriageProposalPanel` 的 `CharacterDetailView`與 FaceOff 資訊等)一律改讀
  `Character.display_name`(只有 given name,不含姓氏也不含頭銜)——`CharacterDetailView`
  的 `show_title` 欄位已移除,不再有例外。
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

## UI 共用寫法分類(UiStyle 與各類共用元件)

專案裡「同一種寫法被多個畫面重複使用」大致分成六類,新增畫面前先檢查有沒有對應分類可以
直接重用,不要重新手刻一份。

- **樣式產生器**(`Scripts/UI/ui_style.gd`,`class_name UiStyle`,純 static func 集合,
  不是元件、不能 `new()`)——羊皮紙/木牌視覺語言的唯一真相來源,50+ 檔呼叫。
  `bordered_panel()` 是最底層(四邊等寬邊框+圓角 `StyleBoxFlat`),之上疊了一層「配方」:
  `apply_parchment_panel()`(羊皮紙木框面板背景,依寬高比裁圖+`resized` 訊號自動重裁)、
  `apply_wood_plaque_button()`/`style_panel_action_button()`(木牌鐵框按鈕,後者是前者
  再包一層固定 16px 字+`SIZE_SHRINK_BEGIN`,給面板內操作鈕用)、`parchment_row_style()`
  (清單/卡片行底色)、`right_border_style()`/`bottom_border_style()`/
  `transparent_panel_style()`(單邊分隔線/純透明蓋色,給「內容自然往下長、不需要獨立
  面板」的區塊)、`apply_parchment_scrollbar()`(捲軸配色)。`color_from_seed()`/
  `family_banner_path()`(依字串決定穩定色相/家徽貼圖)不是樣式,是「暫代美術」的共用
  亂數種子邏輯,見「祖譜」節。新增羊皮紙/木牌風格畫面一律先查這支檔案有沒有現成配方,
  不要在場景腳本裡另刻一份 `StyleBoxFlat`/`StyleBoxTexture`。
- **彈出面板殼**——`ActionPanel`/`CharacterSelectOverlay`(見上文)之外,`ConfirmDialog`
  (autoload,`ask()`/`notify()` 兩個入口,是否或純通知)、`SkillReplaceDialog`(見
  「兵營」節)、`SaveSlotPicker`(存/讀檔清單,借 `ActionPanel` 外殼而非自成一層)都屬於
  同一類「蓋在目前畫面上、關掉不影響底下狀態」的殼,差別只在關閉方式(×/是否/選一個)。
- **選人/清單元件**——`CharacterAvatarCard`(頭像卡片,`available`/`force_dim` 控制
  可選/反灰)+`CharacterSelectBar`(排序列+頭像網格,`setup(characters, card_factory,
  ...)` 灌卡片工廠)+`CharacterSortFilterBar`(排序下拉+武器篩選 CheckBox,被
  `CharacterSelectBar` 內部使用,也可單獨借用),三者組合成 `CharacterSelectPanel`/
  `CharacterSelectOverlay`。任何「挑一個/多個角色」的畫面一律拼這三塊。
- **懸停提示按鈕**(`_make_custom_tooltip()` 慣例)——`CostTooltipButton`/
  `MoraleStatusButton` 兩處覆寫 `Control._make_custom_tooltip()`(`HeaderBar`/
  `BaseActionPanel` 其餘的 tooltip 都是純 `tooltip_text` 字串,沒有這層),外層直接吃
  引擎內建 `TooltipPanel` 底色、不疊自己的底,回傳圖示+文字排版好的 `Control`。兩處都把
  內容產生邏輯抽成 `_build_tooltip_content()`,hover(`_make_custom_tooltip()`)跟觸控
  替代路徑共用同一份。觸控替代路徑是 `UiStyle.show_tap_popover(anchor, content)`(點擊/
  長按彈出同一份內容包在 `PopupPanel` 裡,點外部或 Esc 自動關閉):`MoraleStatusButton`
  點擊本身不觸發遊戲動作,直接在 `pressed` 呼叫;`CostTooltipButton`
  點擊本身就是建造/升級動作,不能直接接 `pressed`,改成按住 `LONG_PRESS_SEC`(0.45 秒)
  才觸發預覽,觸發當下立刻把自己 `disabled=true` 讓即將到來的放開不會被引擎判定成點擊,
  彈窗關閉時才還原,按住時間不到門檻的正常短按完全不受影響。之後新增同類「花費/數值
  明細」hover tooltip,一律比照這兩處的 `_build_tooltip_content()` + `show_tap_popover()`
  寫法,不要只做 hover 版本。
- **手繪可拖曳/可縮放畫布**(`PannableZoomableCanvas`,`Scripts/UI/`)——
  `FamilyTreeCanvas`/`TechTreeCanvas` 都是「自己算版面座標、`_draw()` 手畫卡片與連接線、
  `ScrollContainer` 內可拖曳平移+雙指縮放」的同一種寫法,拖曳平移+雙指縮放判定已經抽成
  這個共用基底類別(`extends Control`,子類別 `extends PannableZoomableCanvas`,寫法
  比照 `System/battle/events/` 的 `BattleEvent` 子類別慣例),子類別只要覆寫
  `_rebuild_at_zoom()`,把原本 `render()` 用到的版面/字級常數(改名成 `_BASE` 後綴)
  乘上基底類別的 `zoom` 重新算一次。縮放刻意不用 `Control.scale`(會跟 ScrollContainer
  的捲動範圍打架,見該檔案開頭大段註解),改成每次 zoom 改變就整個重新算版面,
  `custom_minimum_size` 天生就是縮放後的正確尺寸。只支援觸控雙指縮放,不接桌面滑鼠
  滾輪(滾輪在這兩個畫面本來就是 `ScrollContainer` 內建垂直捲動,疊上去會互搶)。
  新增同類手繪版面畫布(自算座標+ `_draw()` 連接線+需要拖曳平移)一律 `extends
  PannableZoomableCanvas`,不要重新複製一份拖曳判定。`BattleBoard`/`PartyEditBoard`/
  `BarracksGridExpandPanel` 是另一種「棋盤格」寫法,三者已經共用
  `BoardTileRenderer.draw_board()`(見「戰鬥系統」節),各自只留 `TILE_SIZE`/
  `BOARD_ORIGIN` 常數自訂位置與格子大小,是本節唯一「已經正確抽共用、沒有複製貼上」的
  案例,新增棋盤格畫面比照這個寫法。
- **角色詳情面板**(`CharacterDetailView`)——分頁式(素質/技能/婚姻/家族)左側詳情
  面板,`CharacterPanel`/聯姻相關面板共用同一份,見「trait」節。

**手機/PC 通用移植現況**(先鎖橫向為前提的漸進式處理,見下方個別狀態):
`project.godot` 已加 `window/handheld/orientation="landscape"` 鎖定橫向。
`world_inner.gd` 的地圖縮放已支援雙指觸控(`InputEventScreenTouch`/
`InputEventScreenDrag` 追蹤兩指座標算間距變化,`_apply_zoom(factor, center_screen_pos)`
統一滾輪/雙指縮放的「縮放中心點對應世界座標不動」邏輯,不再各自各寫一份);拖曳平移/
點擊移動則沿用引擎觸控自動模擬滑鼠事件,未額外改動。上方「懸停提示按鈕」的觸控替代
路徑已完成。`FamilyTreeCanvas`/`TechTreeCanvas` 已透過 `PannableZoomableCanvas`
(見上方「手繪可拖曳/可縮放畫布」)補上雙指縮放,原本重複貼上的拖曳邏輯也一併整併。
**尚未處理**:`BattleBoard`/`PartyEditBoard`/`BarracksGridExpandPanel` 這類棋盤格畫面
的 `TILE_SIZE`/`BOARD_ORIGIN` 等常數各自獨立一份、互不共用,也沒有全域的「設計基準
尺寸/最小觸控尺寸」常數表,這幾個棋盤格畫面也還沒有雙指縮放手勢;部分畫面(例如
`nation_relations.tscn`)用 `layout_mode = 0` 固定 pixel offset 寫死
版面,且數字(`offset_right=1600`)跟 project.godot 實際視窗寬 1632 對不上,只是碰巧
視覺上還過得去;`window/stretch/mode` 是 `canvas_items`、`aspect` 未設(引擎預設
`keep`),遇到跟 16:9 差異大的長寬比只會整體縮放+留黑邊,不會重排版面——鎖橫向情境下
這點刻意不處理;小型圖示按鈕/CheckBox 的觸控可點擊尺寸還沒逐一抽查。`export_presets.cfg`
目前只有 Windows/Web 兩個 preset,還沒建立 Android/iOS——這步需要另外在機器上裝
Android SDK/JDK 並在 Godot 編輯器下載對應版本 export template,是一次性互動式環境
設置,不是單純改程式碼能完成的。

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

## 節奏小遊戲(System/rhythm + Scenes/RhythmGame)

`RhythmChart`(`hint_beats`/`correct_beats` 兩條「相對音樂開頭秒數」時間戳陣列)+
`RhythmChartStore`(每個生產建築一份 JSON,存在 `System/rhythm/charts/<BuildingType 大寫
拼法>.json`,同一檔內再分 `regular`(常規版)/`variation`(變奏版)兩個完整子譜,見
`RhythmChartStore.VARIANTS`)是資料層;`RhythmGameTest` 獨立測試場景(F6 直接跑)底下
A(打提示譜)/B(打玩家正確譜)/C(觀看,播提示音)/D(遊玩,不播提示音)四個模式,靠
`Scenes/RhythmGame/rhythm_record_view.gd`/`rhythm_play_view.gd` 錄製與試玩,見兩支檔案
檔頭註解。玩法定案、素材做好後才嵌入根據地生產建築面板,目前跟根據地系統還沒整合。

**譜面設計鐵律:hint 一律是「先示範、玩家隔一小段時間後才作答」的召喚應答結構**,不能讓
`hint_beats`/`correct_beats` 兩條時間戳重疊或無時間差(那樣提示音等於直接把答案唸在同一拍
上,見 C 模式「觀看」檔頭註解)。同一個樂句的 hint 音符數與 correct 音符數要一一對應——hint
樂句播完間隔一小段固定時間,對應的 correct 樂句才開始,兩者旋律形狀一致(同一組節奏往後平移
一段固定間隔),不是各自獨立、互不相干的節奏。`regular`/`variation` 兩個版本都要遵守這套
「先示範、後打擊」結構,差別只在密度:`regular` 維持穩定的主拍(quarter beat 等距、不切分),
`variation` 在同一套召喚應答骨架不變的前提下,音符密度與裝飾音/切分音要明顯比 `regular` 多
(見 `RhythmChartStore` 檔頭「變奏版切分音/裝飾音較多、更有節奏遊戲感,但音符仍量化在同一套
節奏格上,不會跑掉節奏」的既有設計描述)。手刻/佔位譜面照這個公式排出時間戳即可;真正要對準
實際 BGM 拍點,還是要靠 A(打提示譜)/B(打玩家正確譜)兩個模式對正式音樂實際錄一遍取代。

**斷點式教學/應答(另一套機制,跟上面 A~D 的靜態譜面並存,不互相影響)**:`RhythmBuildingPanel`
另外多兩顆按鈕——E(斷點設定)/F(斷點遊玩)。斷點(`break_points`,一個 `Array[float]`,存在
`RhythmChartStore` 同一份 JSON 的頂層 key,跟 `regular`/`variation` 同層但不分變體,因為兩個
變體共用同一份 BGM 素材)描述的是**歌曲本身的樂句/段落分界**,由 E
(`Scenes/RhythmGame/rhythm_breakpoint_editor_view.gd`,骨架比照 `RhythmRecordView`,聽 BGM
手動打點存檔)人工標定,也可以先用 `Tools/rhythm/detect_breakpoints.py`(離線 Python 工具,
librosa 結構分段,預設不覆蓋已有斷點的建築)批次跑出初稿再人工微調。

F(`RhythmPlayView` 的 `breakpoint_mode=true`)的正確譜不是存檔資料,改由
`RhythmBreakpointChartGenerator.generate_hybrid()`(`System/rhythm/
rhythm_breakpoint_chart_generator.gd`)用計算的方式算出來——**不是憑空亂數生成音符**
(早期版本這樣做過,結果音符沒卡在音樂節奏上,已改掉),而是吃選定 variant 已經用 A 模式
錄好的真實提示譜(`RhythmChartStore.load_chart(...).hint_beats`,音符本來就落在真實音樂
節奏上)當教學段內容來源。斷點把 `[0, CHART_DURATION_SEC]` 切成一段段,奇數段(第 1、3、
5…段)當教學段、偶數段(第 2、4、6…段)當應答段,兩兩配對:把落在教學段內(扣掉頭尾
`BOUNDARY_MARGIN` 秒緩衝)的提示譜音符,依「在教學段內的相對比例位置(0~1)」等比例縮放
對應到緊接應答段的可用空間,算出 `correct_beats`——兩段長度不一定相等也不會超出範圍。
同一組斷點+提示譜每次算出來的結果完全相同(先求音符準確卡在節奏上,不要求像 A~D 以外的
早期構想那樣每輪隨機)。斷點總數是奇數、最後落單一段沒有配對應答段時,那一段不生成任何
音符(已知簡化)。

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

## 國際戰爭(System/war + NationRelationStore)

跟「國家好感度」(玩家→國家)刻意分開的另一條軸線:國與國之間會不會開戰、打得如何,
是動態的國家關係資料,存在 autoload `NationRelationStore`
(`Scripts/Autoload/nation_relation_store.gd`)——跟 `NationFavorStore` 同一套慣例,這裡
只負責持有資料/讀寫入口/發 News/存檔,實際的機率與數值規則全部是 `System/war/` 底下的
純 `RefCounted` 類別。

- **`WarTension`**(0~100,`NationRelationStore.tension`,`min_id_max_id` 字串組 key)是
  每組國家對「有沒有理由開戰」的長期壓力值,唯一改動入口是
  `NationRelationStore.modify_war_tension()`。開局每組國家對給一個 0~
  `WarTensionRule.INITIAL_TENSION_MAX` 的隨機起始值(不是全部從 0 開始,否則幾十年都爬
  不到宣戰門檻),沒有戰爭的國家對每月疊加一次 `±MONTHLY_RANDOM_DRIFT_RANGE` 隨機波動
  (邊境摩擦簡化版)、每年再扣一次 `PEACETIME_YEARLY_DECAY`——兩者同時存在是刻意設計:
  decay 是長期拉回和平的系統性力道,drift 是疊在上面有正有負的短期雜訊,兩者一起才會讓
  張力自然爬升,不會只單調下降。正在交戰的國家對張力改由戰場結果推動,不跑這兩個
  月/年例行處理。
- **`War`**(`System/war/war.gd`)是一整場戰爭的容器,`attacker`/`defender`
  +`battle_power_a/b`(宣戰當下定值的**國力基準**,不會被玩家個別戰場的貢獻改動)+
  `war_exhaustion_a/b`(0~100,只在交戰中才有意義)+`active_battles`
  (`Array[WarBattle]`)。玩家對整場戰爭最多選邊一次(`player_side`,
  `NationRelationStore.set_player_side()` 是唯一入口),`player_war_contribution` 只反映
  這場 War 期間的戰功,停戰時歸零、不跨戰爭累積。
- **`WarBattle`**(`war_battle.gd`)是地圖上實際看得到的戰場物件,同一場 War 最多同時
  `WarBattleSpawner.MAX_CONCURRENT_BATTLES`(4)個,命名刻意避開
  `System/battle/battle.gd` 的 `Battle`(單場戰鬥模擬),兩者不是同一種東西。生成時
  (`WarBattleSpawner.spawn_battle()`)自己的 `battle_power_a/b` 由 War 的國力基準乘上
  `WarBattleRankRule` 依隨機骰出的 `rank_type`(F~SSS,決定敵方強度/初始戰力倍率/結算前
  最長月數,不再依附戰爭規模——舊版 WarScale 已移除)換算出來,之後兩者各自獨立漂移,
  不會再跟國力基準同步。`battle_progress`(-100~100,正值 nation_a 優勢)由
  `WarBattleSimulation.advance_month()` 每月自動演化(領先方戰力損耗打折,讓優勢方越打
  越穩),達到 `SETTLEMENT_PROGRESS_THRESHOLD` 或拖到 `max_duration_months` 由
  `BattleResultGrader.grade()` 判出七級戰果(壓倒性勝利…壓倒性失敗),換算成雙方
  `WarExhaustionRule` 疲憊增量,呼叫 `NationRelationStore.settle_battle()` 結算——單一
  戰場結算不影響 War 本身,`WarBattleSpawner` 照樣會在額度內持續補新戰場進來,也不會
  發 News(News 只留給整場 War 的宣戰/停戰)。
- **停戰**:`war_world_time_events.gd` 每月用雙方平均疲憊查
  `WarTruceRule.truce_probability()`(機率式,疲憊再高也不會 100% 必然停戰)骰一次,
  骰中呼叫 `NationRelationStore.resolve_truce()`——結束這整場 War、把張力打折保留
  (`WarTruceRule.post_truce_tension()`),並依雙方停戰當下疲憊值高低判斷玩家支援的一方
  有沒有贏(疲憊較低視為相對佔優),贏才把累積戰功換算成金幣+好感度一次發放
  (`WarContributionRule.money_for_contribution()`/`favor_for_contribution()`),沒贏
  不發獎勵但戰功紀錄本身不因此消失,無論輸贏戰功都歸零。
- **玩家連續作戰**(`WarCampaignController`,見 `System/event/map/war_battle_event.gd`
  逐場呼叫):玩家投入戰場後最多連打 10 場個人戰鬥,只要連勝才能繼續往下打,一輸/平手
  就停在那一場——流程橫跨多次 Dialogue↔Battle 場景切換是非同步的,不能寫成一次跑完的
  同步迴圈,所以 `WarCampaignController` 只提供 `apply_contribution()`(單場結果換算成
  這個 WarBattle 的 `battle_progress`/`battle_power` 位移+戰功)跟
  `settle_battle_if_ready()` 給呼叫端逐場呼叫,自己不持有「跑一整輪」的迴圈。戰功公式
  `rank_type + streak_count`(這一輪連續作戰內第幾場,每次玩家重新投入同一戰場都是全新
  一輪從 1 重算),只有贏才有分。
- **`WarDiplomacyAi`**(`war_world_time_events.gd` 的 `yearly_tick()` 呼叫):每年對每個
  國家骰兩階段——Phase 1 用 `BASE_WANT_CHANCE`+對外最高 `WarTension`×`TENSION_SLOPE`
  (封頂 `MAX_WANT_CHANCE`)骰「今年想不想開戰」,骰中才進 Phase 2,候選排除自己/已在
  交戰的對象/張力低於 `WarTensionRule.DECLARE_CANDIDATE_TENSION_THRESHOLD` 的國家,再用
  `WarTension` 當權重加權隨機選一個目標(不是永遠選張力最高的那個)。

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

衰老特性透過 `Trait.stat_multiplier`(通用欄位,`is_aging` 旗標標記,不比對
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
