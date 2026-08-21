class_name UltimateLibrary
extends RefCounted

## 奧義總表。新增奧義請加一個 _xxx() 組裝函式,依作用對象加進 self_ultimates()(對己方,
## 祭壇購買用)或 enemy_ultimates()(對敵方,禁忌祭壇購買用),寫法比照 SkillLibrary 的
## _active_skills()/_passive_skills() 分類方式。
##
## self_ultimates()/enemy_ultimates() 用 static var 快取,只在第一次呼叫時真的組裝
## Ultimate 物件——Ultimate.id 是隨機 UUID(見 ultimate.gd _init()),若每次呼叫都重新
## build() 會產生新的 id,BaseAltar 賣出的「購買次數」是靠 UltimateStore 以 id 為 key
## 累加,id 一旦不穩定,買到的次數就會跟戰鬥實際扣的次數對不上,所以這裡必須快取,
## 保證整個遊戲全程同一個奧義只有一個 id。

static var _self_cache: Array[Ultimate] = []
static var _enemy_cache: Array[Ultimate] = []


## 對己方生效的奧義(祭壇購買),目前只有天降甘霖。
static func self_ultimates() -> Array[Ultimate]:
	if _self_cache.is_empty():
		_self_cache.append(_rain_of_blessing())
	return _self_cache


## 對敵方生效的奧義(禁忌祭壇購買),目前只有龍捲風。
static func enemy_ultimates() -> Array[Ultimate]:
	if _enemy_cache.is_empty():
		_enemy_cache.append(_tornado())
	return _enemy_cache


static func build() -> Array[Ultimate]:
	var library: Array[Ultimate] = []
	library.append_array(self_ultimates())
	library.append_array(enemy_ultimates())
	return library

## 依名稱找奧義:Ultimate.id 是隨機 UUID、重開遊戲會變(見上方註解),存檔/讀檔
## (Scripts/Autoload/save_load_store.gd)要還原 Party.ultimates/UltimateStore 剩餘次數
## 只能靠名稱比對——奧義名稱本來就唯一,找不到回傳 null。
static func get_by_name(ultimate_name: String) -> Ultimate:
	for ultimate in build():
		if ultimate.name == ultimate_name:
			return ultimate
	return null

## 天降甘霖:施放後下一回合開始時,resolve_line 才顯示(不是施放當下的預告),
## 同時全體友軍(含施法者本人)恢復生命上限的 40%。一場戰鬥只能放一次。
static func _rain_of_blessing() -> Ultimate:
	return (UltimateBuilder.new()
		.name("天降甘霖")
		.description("下一回合開始時,天顯神蹟降下傾盆大雨,全體友軍恢復生命上限的 40%")
		.resolve_line("天顯神蹟,在危急時刻降下了傾盆大雨,滋潤全軍傷勢")
		.rank(GameEnums.RankType.F)
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
		.rank(GameEnums.RankType.F)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.2)
		.resolve_action(Callable(UltimateEffectLibrary, "tornado_resolve"))
		.build())

## Party 建立時預設配置的奧義清單,目前所有小隊(含隨機生成的敵方小隊)都拿同一份。
static func default_ultimates() -> Array[Ultimate]:
	return build()
