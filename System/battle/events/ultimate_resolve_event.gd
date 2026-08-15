class_name UltimateResolveEvent
extends BattleEvent

## 奧義的延遲效果實際生效當下記一筆(見 Ultimate.resolve()/Battle._round_start())。
## 施放(cast)當下不記錄、不顯示任何東西——resolve_line 不是「即將發生」的預告,
## 而是效果生效那一刻本身的天象描述(例如「天顯神蹟,在危急時刻降下了傾盆大雨」),
## 只在這個事件觸發時顯示一次。

var actor: BattleHero
var actor_name: String
var ultimate_name: String
## 生效當下顯示給玩家看的台詞(Ultimate.resolve_line),戰場中央浮字用這個,
## 不是某個角色頭像旁邊喊招式名稱,見 Scenes/Battle/battle.gd 的 _apply_ultimate_resolve()。
var flavor_text: String

func _init(p_actor: BattleHero, p_ultimate_name: String, p_flavor_text: String, p_detail: String = "") -> void:
	super._init(GameEnums.BattleEventType.ULTIMATE_RESOLVE, p_detail)
	actor = p_actor
	actor_name = p_actor.name
	ultimate_name = p_ultimate_name
	flavor_text = p_flavor_text

func to_debug_string() -> String:
	return "奧義「%s」生效:%s" % [ultimate_name, flavor_text]
