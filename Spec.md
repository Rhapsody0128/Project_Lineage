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
- 行動(`BattleHero.action()`):`search_enemy()` 找格子曼哈頓距離最近的敵人;權重表
  抽 `ActionType`(ATTACK/DAZE/SKILL 固定各 25,ESCAPE 只在 `hp_ratio<50%` 才列入,
  CONFUSE 保留但抽選池暫關)。基本攻擊(ATTACK)依武器決定攻擊距離
  (`GameEnums.WEAPON_BASIC_ATTACK_RANGE`:近戰劍/盾/匕首=1、遠程弓/法杖/權杖=2),
  在範圍內才出手,否則先往目標移動一次再重新檢查。SKILL 改成先抽出實際要放的技能,
  用該技能自己的 `Skill.range` 判斷能不能出手(不是武器距離),不夠近一樣先移動、以該
  技能射程為目標距離,移動後仍搆不到就不出手,不會退化亂放。技能施放權重目前直接採技能
  本身的 `base_chance`(沒有武器/陣形位置加成)。
- 傷害公式:基本攻擊與技能共用 `SkillEffectLibrary` 裡「武器 → 攻擊素質/防禦素質」的
  配對(`_attack_value()`/`_defense_value()`,法杖智慧 vs 信仰、弓靈巧 vs 體質、盾
  力量*0.4+體質*0.6 vs 體質、匕首力量*0.4+敏捷*0.6 vs 體質、權杖智慧*0.4+信仰*0.6 vs
  信仰、劍與徒手 EMPTY 都是力量 vs 體質),差異只在倍率:基本攻擊固定
  `SkillEffectLibrary.basic_attack_damage()` 用倍率 1,技能用 `Skill.skill_ratio`
  (目前 2~3)。
- 範圍效果:`Skill.area_shape`(`GameEnums.AreaShape`:SINGLE 單體、RADIUS 以命中目標為
  中心的菱形範圍、LINE 貫穿、SQUARE 正方形範圍)+ `Skill.area_size` 決定技能命中目標後
  實際波及的敵人,`Skill.resolve_targets()` 算出完整命中清單,範圍內每個目標各自按自己
  的防禦素質算傷害(不因波及多人而讓輸出膨脹或衰減)。目前只有火球術是 `RADIUS, 2`,
  其餘技能都是 `SINGLE, 1`。技能目前仍不判定閃避(`judge_dodge()` 只用在基本攻擊)。
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
- 技能目前不判定閃避(只有基本攻擊會呼叫 `judge_dodge()`),範圍技能命中判定也還沒有
  「目標死活以外」的地形/隊形加成
- `Scenes/Battle/battle_unit_visual.gd` 角色右下角常駐的武器類型文字是測試階段除錯用
  (`WEAPON_LABEL_POSITION`),正式美術/UI 定案後要整段移除或改成圖示
- 個性/特質(`System/trait/`)只有資料模型(名稱+描述+正負中性)與抽樣池(目盲/勇猛/
  膽小三選二),機制效果(命中率/AI 傾向等)尚未接上
- 血統/學院/婚姻/城鎮/英靈殿等企劃概念尚無對應 System 模組
- CONFUSE(叛變攻擊己方)機制已寫好但抽選池暫時關閉,等魅惑狀態系統接上再開放
- 專案尚無獨立 DEX 屬性,閃避公式暫借用 `perception` 欄位代替
- `Hero.age` 目前只是產生時隨機指定的靜態數值,尚無老化/死亡/婚姻等生命週期機制
