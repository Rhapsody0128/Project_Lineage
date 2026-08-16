class_name Ultimate
extends RefCounted

## 奧義資料:跟 Skill 不同,奧義不吃每回合行動骰選,而是玩家在即時戰鬥模式
## (Battle.start_realtime()/step_round())回合間自行決定要不要施放,見
## System/battle/battle.gd 的 cast_ultimate()。施放(cast)當下只是把效果排進佇列,
## 不對外顯示任何東西——resolve_line(例如「天顯神蹟,在危急時刻降下了傾盆大雨」)
## 不是「即將發生」的預告台詞,而是效果生效那一刻本身的天象描述,所以只在延遲
## delay_rounds 回合後真正生效(resolve,由 Battle._round_start() 呼叫)的當下才顯示,
## 施放當下不會另外喊一句不一樣的話。數值效果(治療/傷害等)透過 resolve_action 這個
## Callable 委派給 UltimateEffectLibrary,寫法比照 SkillEffectLibrary。

var id: String
var name: String
var description: String
## 生效當下顯示的天象/特效描述(戰場中央浮字,見 Scenes/Battle/battle.gd 的
## _apply_ultimate_resolve()),例如「詭異龍捲風攻擊敵人」——這時候數值效果才真的套用,
## 施放的當下不會顯示任何東西。
var resolve_line: String
## 施放後延遲幾回合生效:1 代表「這回合施放,下回合開始時生效」。
var delay_rounds: int
## 整場戰鬥最多可施放次數,負數代表不限次數。
var max_uses_per_battle: int
## 效果數值比例,不同奧義各自解讀這個欄位的意義(天降甘霖是回復生命上限的比例、
## 龍捲風是造成傷害的比例)。
var effect_ratio: float
## 施放當下呼叫,簽名 (caster: BattleCharacter, ultimate: Ultimate, resolve_round: int),
## 給需要在施放當下就套用額外效果的奧義用(目前兩個內建奧義都不需要,留空即可)。
var cast_action: Callable
## 延遲生效當下呼叫,簽名 (caster: BattleCharacter, ultimate: Ultimate),做實際數值效果
## (治療/傷害等),由 resolve() 在對應回合到達時呼叫。
var resolve_action: Callable

func _init() -> void:
	id = Util.generate_uuid()

## 施放當下:只給有特殊需求的奧義一個掛勾(cast_action),預設不記錄任何戰報事件、
## 不顯示任何東西——玩家看得到的只有 resolve() 那一刻的 resolve_line。
func cast(caster: BattleCharacter, resolve_round: int) -> void:
	if cast_action.is_valid():
		cast_action.call(caster, self, resolve_round)

func resolve(caster: BattleCharacter) -> void:
	if resolve_line != "":
		caster.battle.log_event(UltimateResolveEvent.new(caster, name, resolve_line, "奧義「%s」生效" % name))
	if resolve_action.is_valid():
		resolve_action.call(caster, self)
