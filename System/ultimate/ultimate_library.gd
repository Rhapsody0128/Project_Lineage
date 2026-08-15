class_name UltimateLibrary
extends RefCounted

## 奧義總表。新增奧義請加一個 _xxx() 組裝函式並加進 build(),寫法比照 SkillLibrary。
## Party 預設奧義配置見 default_ultimates(),由 PartyController 建立小隊時呼叫。

static func build() -> Array[Ultimate]:
	var library: Array[Ultimate] = []
	library.append(_rain_of_blessing())
	library.append(_tornado())
	return library

## 天降甘霖:施放後下一回合開始時,resolve_line 才顯示(不是施放當下的預告),
## 同時全體友軍(含施法者本人)恢復生命上限的 40%。一場戰鬥只能放一次。
static func _rain_of_blessing() -> Ultimate:
	return (UltimateBuilder.new()
		.name("天降甘霖")
		.description("下一回合開始時,天顯神蹟降下傾盆大雨,全體友軍恢復生命上限的 40%")
		.resolve_line("天顯神蹟,在危急時刻降下了傾盆大雨,滋潤全軍傷勢")
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.4)
		.resolve_action(Callable(UltimateEffectLibrary, "rain_of_blessing_resolve"))
		.build())

## 龍捲風:施放後下一回合開始時,resolve_line 才顯示,同時對敵方全體造成其生命上限
## 20% 的傷害。一場戰鬥只能放一次。
static func _tornado() -> Ultimate:
	return (UltimateBuilder.new()
		.name("龍捲風")
		.description("下一回合開始時,天有異象召喚龍捲風,敵方全體受到最大生命 20% 的傷害")
		.resolve_line("天有異相,詭異龍捲風突然出現,狠狠攻擊敵人！")
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.2)
		.resolve_action(Callable(UltimateEffectLibrary, "tornado_resolve"))
		.build())

## Party 建立時預設配置的奧義清單,目前所有小隊(含隨機生成的敵方小隊)都拿同一份。
static func default_ultimates() -> Array[Ultimate]:
	return build()
