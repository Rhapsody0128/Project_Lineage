# Spec.md(技術規格,給 AI 助理讀)

分層原則、資料夾對照、戰鬥元件拆分見 [CLAUDE.md](CLAUDE.md)。這份文件補完 CLAUDE.md
沒展開的細節:戰報事件合約、戰鬥數值公式、驗證方式、Unity 移植對照、已知待辦。
遊戲設計概念見 [遊戲企劃設定總整理.md](遊戲企劃設定總整理.md)。

## 一、戰報事件合約(System/battle ↔ Scenes/Battle)

`Battle.start()` 一次性跑完整場模擬,每發生一件事呼叫 `log_event(dict)` 存進
`battle_log: Array[Dictionary]`。事件必須自帶當下快照數值(傷害量、剩餘 HP 等),
因為模擬跑完後物件狀態已是最終值,場景端不能事後回頭讀「目前狀態」。

`battle.gd._play_battle_log()` 事後依序重播(`await`/Tween/動畫),純粹播放結果,不影響
模擬。新增事件型別時:

- 型別放 `event.type`(String)
- 需要對應畫面節點的欄位放 `BattleHero` 物件本身當 Dictionary key(不要只存名字字串,
  否則畫面端沒辦法定位是哪個節點)
- `Battle._format_event()` 補純文字除錯版
- `battle.gd` 的 `match` 補畫面處理分支
- `attack`/`skill` 事件在 log 裡永遠緊接著 `dodge` 或 `damage`(`BattleHero.attack()`
  的實作保證),`battle.gd._play_battle_log()` 會把這兩筆合併同時播放(見四)——新增
  「攻擊類」事件時如果還是這種「動作+反應」的兩段式,直接沿用這個合併機制即可
- 事件可選帶 `detail: String`(判定/骰值/公式全文),`battle.gd._hint()` 會用
  RichTextLabel 的 `[hint=...]` 標籤包住對應戰報文字,滑鼠移過去就彈出完整說明;
  detail 內容不能含方括號 `[` `]`,會被誤判成 BBCode 標籤提早截斷

## 二、戰鬥數值細節

- 戰場:`GRID_COLS=12`(左右)、`GRID_ROWS=6`(上下),正面棋盤,無斜角投影。我方沿
  最左列、敵方沿最右列置中部署,相向而行。
- 編制:`Hero`(角色)⊂ `Party`(小隊,`Party.heroes`),純組織分組,不參與戰鬥判定。
  `BattleController.get_random_battle()` → `Battle._init()` 的 `_attach_battle_heroes()`
  直接把小隊裡的角色攤平成一維陣列,每個角色各自用一個 `BattleHero` 包裝、各佔一格
  獨立作戰。目前寫死 1 小隊=6 名隨機角色(對應戰場 6 路縱隊),之後小隊人數會開放
  玩家配置、可被科技研發提升。
- HP:士兵/武器/陣形系統已整個移除,角色直接有自己的 HP(`Hero.hp`,上限
  `Hero.HP_MAX=600`,目前全角色統一固定值,還沒有依素質/等級計算的公式)。
  `BattleHero.be_attacked()` 傷害直接扣 `hero.hp`,歸零視為戰敗(`defeated` 事件)。
- 勝負:固定跑 `Battle.TOTAL_ROUND=10` 回合。總大將沿用現有隊長機制(`Party.leader`/
  `BattleHero.is_leader`):`Battle.is_decided` 判斷任一方總大將陣亡就提前結束戰鬥;
  `Battle.result`(`GameEnums.BattleResultType`)只看雙方總大將死活決定 `SELF_WIN`/
  `ENEMY_WIN`/`DRAW`,跑滿 10 回合時雙方總大將必定都還存活(否則早就提前結束),此時直接
  判 `DRAW`,不比較 HP。`self_total_hp`/`enemy_total_hp` 只保留給畫面展示用。
- 行動(`BattleHero.action()`):`search_enemy()` 找格子曼哈頓距離最近的敵人(ATTACK/
  ESCAPE 用);權重表抽 `ActionType`(ATTACK/DAZE/SKILL 固定各 25,ESCAPE 只在
  `hp_ratio<50%` 才列入,CONFUSE 保留但抽選池暫關)。基本攻擊(ATTACK)依武器決定攻擊
  距離(`GameEnums.WEAPON_BASIC_ATTACK_RANGE`:近戰劍/盾/匕首=1、遠程弓/法杖/捕夢網=2),
  在範圍內才出手,否則先往目標移動一次再重新檢查;若已經在射程內但距離小於射程(遠程
  武器才有意義,`atk_range>1`),會先用 `_kite_to_max_range()` 退到剛好等於射程再出手,
  拉開跟敵人的距離、不會退出射程外浪費這次攻擊。SKILL 改成先抽出實際要放的技能,再用
  `_pick_aoe_primary_target()` 從存活敵人中選「以該敵人為中心可以命中最多目標」的一個
  當主要目標(單體技能命中數恆為 1,同分退化成選最近敵人,行為等同舊版);用該技能自己
  的 `Skill.range` 判斷能不能出手(不是武器距離),不夠近一樣先移動、以該技能射程為目標
  距離,已經在範圍內但距離小於射程一樣會 `_kite_to_max_range()` 退到剛好等於射程,移動
  後仍搆不到就不出手,不會退化亂放。技能施放權重目前直接採技能本身的 `base_chance`
  (沒有武器/陣形位置加成)。
- 傷害公式:基本攻擊與技能共用 `SkillEffectLibrary`「武器→攻擊素質/防禦素質」配對
  (`_attack_value()`/`_defense_value()`),差異只在倍率(基本攻擊 1、技能用
  `Skill.skill_ratio`);`_skill_damage()` 的封頂比例只看素質本身,倍率只放大最終傷害。
- 範圍效果:`Skill.area_shape`(SINGLE/RADIUS/LINE/SQUARE)+ `area_size` 決定
  `resolve_targets()` 算出的命中清單,範圍內每個目標各自獨立判定閃避/暴擊/傷害,
  不互相牽連。目前只有火球術是 `RADIUS, 2`,其餘都是 `SINGLE, 1`。
- 移動:`BASE_MOVE_STEPS=2`,敏捷每滿 `AGILITY_PER_EXTRA_STEP=25` 多走 1 格;可穿過
  己方存活角色,只有敵方存活角色擋路,被擋會側移繞路;遠程武器/技能在射程內但距離
  小於射程時會用 `_kite_to_max_range()` 退到剛好等於射程再出手。
- 閃避:`judge_dodge()`,魔法攻擊(`GameEnums.WEAPON_IS_MAGIC`)無視閃避必定命中;
  物理攻擊依防禦方 AGI vs 攻擊方 DEX 算閃避率,公式與常數見函式註解。
- 暴擊:`judge_crit()`,物理、魔法攻擊都會判定,攻擊方一律吃 DEX,防禦方抵抗素質
  依攻擊種類換(物理吃 VIT、魔法吃 MEN),命中且觸發暴擊時傷害乘上
  `CRIT_DAMAGE_MULTIPLIER`(1.6),公式與常數見函式註解。畫面端一般傷害顯示白字、
  暴擊顯示紅字放大。
- 技能分類:`Skill.is_passive`(開戰即套用一次或反應式觸發,不吃行動骰選)+
  `Skill.is_leader_skill`(只有隊長能用),`SkillLibrary` 依此分成 `_active_skills()`/
  `_passive_skills()`/`_leader_skills()` 三區。`Skill.skill_type` 決定
  `resolve_targets()` 挑目標的陣營(ATTACK/DEBUFF 打敵方、BUFF/HEAL/DEFEND 打我方),
  `AreaShape.ALL_ALLIES` 無視距離命中施法者+全隊。
- 素質修正:`BattleHero.add_stat_modifier()` 疊加暫時或永久的素質加成/減益,
  `rounds_remaining<0` 是永久(被動技能用),否則每 `Battle._round_end()` 倒數 1 回合、
  到期自動移除;同一個(素質, 倍率)重複套用只會刷新回合數,不會無限疊加。
- 守護(盾系被動):`BattleHero.resolve_guard()` 在單體物理攻擊命中判定前檢查,
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

- 士兵(`Soldier`)、武器(`Weapon`)、陣形(`Formation`)系統已整個移除,暫時不需要這些
  設計;角色 HP 現在統一固定 `Hero.HP_MAX=600`,還沒有依素質/等級計算血量的公式
- 小隊編制(`Party.heroes`)目前是寫死的隨機 6 人小隊,還沒有玩家自訂編隊 UI
- 範圍技能命中判定還沒有「目標死活以外」的地形/隊形加成
- `Scenes/Battle/battle_unit_visual.gd` 角色右下角常駐的武器類型文字是測試階段除錯用
  (`WEAPON_LABEL_POSITION`),正式美術/UI 定案後要整段移除或改成圖示
- 個性/特質(`System/trait/`)只有資料模型(名稱+描述+正負中性)與抽樣池(目盲/勇猛/
  膽小三選二),機制效果(命中率/AI 傾向等)尚未接上
- 血統/學院/婚姻/城鎮/英靈殿等企劃概念尚無對應 System 模組
- CONFUSE(叛變攻擊己方)機制已寫好但抽選池暫時關閉,等魅惑狀態系統接上再開放
- `Hero.age` 目前只是產生時隨機指定的靜態數值,尚無老化/死亡/婚姻等生命週期機制
