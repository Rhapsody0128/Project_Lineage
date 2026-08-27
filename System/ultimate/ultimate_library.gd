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


## 對己方生效的奧義(祭壇購買),F~SSS 共 9 個,設計依據見「奧義擴充設計」章節——刻意讓
## 每個 Rank 走不同效果軸線(治療/護盾/素質增益/淨化/破防/必定暴擊…),不是同一效果加大
## 數字,避免高階單純輾壓低階。
static func self_ultimates() -> Array[Ultimate]:
	if _self_cache.is_empty():
		_self_cache.append(_rain_of_blessing())
		_self_cache.append(_light_bastion())
		_self_cache.append(_battle_fervor())
		_self_cache.append(_purification_hymn())
		_self_cache.append(_holy_blade())
		_self_cache.append(_war_god_possession())
		_self_cache.append(_slumber_prayer())
		_self_cache.append(_divine_sanctuary())
		_self_cache.append(_genesis_goddess())
		for ultimate in _self_cache:
			ultimate.category = GameEnums.UltimateCategory.BLESSING
	return _self_cache


## 對敵方生效的奧義(禁忌祭壇購買),F~SSS 共 9 個,低中階刻意留幾個「純控場、不傷血」
## 的奧義(凋零詛咒/絕望迷霧/夜嚎凶兆/萬鬼緘默),對付特定敵方陣型時比高階傷害奧義更好用,
## 高階奧義才開始把傷害跟控場疊在一起。
static func enemy_ultimates() -> Array[Ultimate]:
	if _enemy_cache.is_empty():
		_enemy_cache.append(_tornado())
		_enemy_cache.append(_withering_curse())
		_enemy_cache.append(_despair_mist())
		_enemy_cache.append(_night_howl())
		_enemy_cache.append(_silent_ghosts())
		_enemy_cache.append(_hellfire())
		_enemy_cache.append(_corrosive_tide())
		_enemy_cache.append(_abyssal_gaze())
		_enemy_cache.append(_final_judgment())
		for ultimate in _enemy_cache:
			ultimate.category = GameEnums.UltimateCategory.CALAMITY
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


# =========================================================
# 自身BUFF奧義 E~SSS(祭壇購買),F 級是既有的天降甘霖
# =========================================================

## 聖光壁壘:全體友軍獲得生命上限 35% 的護盾。
static func _light_bastion() -> Ultimate:
	return (UltimateBuilder.new()
		.name("聖光壁壘")
		.description("下一回合開始時,聖光凝成壁壘,全體友軍獲得生命上限 35% 的護盾")
		.resolve_line("聖光自天而降,凝成守護全軍的壁壘")
		.rank(GameEnums.RankType.E)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.35)
		.resolve_action(Callable(UltimateEffectLibrary, "light_bastion_resolve"))
		.build())

## 戰意昂揚:全體友軍 力量/敏捷 +20%,持續 3 回合。
static func _battle_fervor() -> Ultimate:
	return (UltimateBuilder.new()
		.name("戰意昂揚")
		.description("下一回合開始時,戰神低語灌入全軍血脈,全體友軍力量/敏捷 +20%,持續 3 回合")
		.resolve_line("戰神低語灌入全軍血脈,士氣如虹")
		.rank(GameEnums.RankType.D)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.20)
		.duration_rounds(3)
		.resolve_action(Callable(UltimateEffectLibrary, "battle_fervor_resolve"))
		.build())

## 淨罪聖詠:全體友軍回復生命上限 25%,並各自清除一項異常狀態。
static func _purification_hymn() -> Ultimate:
	return (UltimateBuilder.new()
		.name("淨罪聖詠")
		.description("下一回合開始時,聖詠迴盪戰場,全體友軍回復生命上限 25%,並清除一項異常狀態")
		.resolve_line("聖詠迴盪戰場,滌淨傷痛與詛咒")
		.rank(GameEnums.RankType.C)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.25)
		.resolve_action(Callable(UltimateEffectLibrary, "purification_hymn_resolve"))
		.build())

## 聖劍顯現:全體友軍獲得「破防」,下一擊(1 回合內)必定無視防禦。
static func _holy_blade() -> Ultimate:
	return (UltimateBuilder.new()
		.name("聖劍顯現")
		.description("下一回合開始時,虛空浮現聖劍虛影,全體友軍下一擊必定無視防禦(1 回合)")
		.resolve_line("虛空中浮現聖劍虛影,劍氣所指,萬甲皆碎")
		.rank(GameEnums.RankType.B)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.duration_rounds(1)
		.resolve_action(Callable(UltimateEffectLibrary, "holy_blade_resolve"))
		.build())

## 戰神附體:全體友軍獲得「必定暴擊」,下一擊(1 回合內)必定暴擊。
static func _war_god_possession() -> Ultimate:
	return (UltimateBuilder.new()
		.name("戰神附體")
		.description("下一回合開始時,戰神之魂降臨全軍,全體友軍下一擊必定暴擊(1 回合)")
		.resolve_line("戰神之魂降臨全軍,每一擊皆是必殺")
		.rank(GameEnums.RankType.A)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.duration_rounds(1)
		.resolve_action(Callable(UltimateEffectLibrary, "war_god_possession_resolve"))
		.build())

## 安寢祝禱:全體友軍回復生命上限 50%,並額外獲得生命上限 25% 的護盾。
static func _slumber_prayer() -> Ultimate:
	return (UltimateBuilder.new()
		.name("安寢祝禱")
		.description("下一回合開始時,安寢女神俯瞰戰場,全體友軍回復生命上限 50%,並獲得生命上限 25% 的護盾")
		.resolve_line("安寢女神俯瞰戰場,傷勢與危難一併撫平")
		.rank(GameEnums.RankType.S)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.50)
		.secondary_ratio(0.25)
		.resolve_action(Callable(UltimateEffectLibrary, "slumber_prayer_resolve"))
		.build())

## 神域庇護:全體友軍獲得生命上限 45% 的護盾,並獲得「破防」1 回合。
static func _divine_sanctuary() -> Ultimate:
	return (UltimateBuilder.new()
		.name("神域庇護")
		.description("下一回合開始時,神域結界降臨,全體友軍獲得生命上限 45% 的護盾,並下一擊必定無視防禦(1 回合)")
		.resolve_line("神域結界降臨,庇護之力銳不可當")
		.rank(GameEnums.RankType.SS)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.45)
		.duration_rounds(1)
		.resolve_action(Callable(UltimateEffectLibrary, "divine_sanctuary_resolve"))
		.build())

## 創世女神降臨:全體友軍回復 45% + 護盾 30% + 清除一項異常狀態 + 獲得「必定暴擊」1 回合,
## 四個效果一次到位的壓軸奧義。
static func _genesis_goddess() -> Ultimate:
	return (UltimateBuilder.new()
		.name("創世女神降臨")
		.description("下一回合開始時,創世女神親臨戰場,全體友軍回復生命上限 45%、獲得生命上限 30% 的護盾、清除一項異常狀態,並下一擊必定暴擊(1 回合)")
		.resolve_line("創世女神親臨戰場,萬物在她面前重獲新生與力量")
		.rank(GameEnums.RankType.SSS)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.45)
		.secondary_ratio(0.30)
		.duration_rounds(1)
		.resolve_action(Callable(UltimateEffectLibrary, "genesis_goddess_resolve"))
		.build())


# =========================================================
# 傷害敵人奧義 E~SSS(禁忌祭壇購買),F 級是既有的龍捲風
# =========================================================

## 凋零詛咒:敵方全體 力量/體質 -20%,持續 3 回合,純減益不造成傷害。
static func _withering_curse() -> Ultimate:
	return (UltimateBuilder.new()
		.name("凋零詛咒")
		.description("下一回合開始時,枯萎氣息瀰漫戰場,敵方全體力量/體質 -20%,持續 3 回合")
		.resolve_line("枯萎氣息瀰漫戰場,敵軍血肉逐漸凋零")
		.rank(GameEnums.RankType.E)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.20)
		.duration_rounds(3)
		.resolve_action(Callable(UltimateEffectLibrary, "withering_curse_resolve"))
		.build())

## 絕望迷霧:敵方全體陷入「降治療」,持續 3 回合。
static func _despair_mist() -> Ultimate:
	return (UltimateBuilder.new()
		.name("絕望迷霧")
		.description("下一回合開始時,絕望迷霧籠罩敵陣,敵方全體陷入降治療狀態,持續 3 回合")
		.resolve_line("絕望迷霧籠罩敵陣,一切救贖都變得徒勞")
		.rank(GameEnums.RankType.D)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.duration_rounds(3)
		.resolve_action(Callable(UltimateEffectLibrary, "despair_mist_resolve"))
		.build())

## 夜嚎凶兆:敵方全體陷入「恐懼」,持續 2 回合。
static func _night_howl() -> Ultimate:
	return (UltimateBuilder.new()
		.name("夜嚎凶兆")
		.description("下一回合開始時,夜梟凶嚎劃破戰場,敵方全體陷入恐懼,持續 2 回合")
		.resolve_line("夜梟凶嚎劃破戰場,敵軍心生怯意")
		.rank(GameEnums.RankType.C)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.duration_rounds(2)
		.resolve_action(Callable(UltimateEffectLibrary, "night_howl_resolve"))
		.build())

## 萬鬼緘默:敵方全體陷入「封印」,持續 2 回合,無法使用主動技能。
static func _silent_ghosts() -> Ultimate:
	return (UltimateBuilder.new()
		.name("萬鬼緘默")
		.description("下一回合開始時,亡靈之手掩住敵軍咽喉,敵方全體陷入封印,持續 2 回合")
		.resolve_line("亡靈之手掩住敵軍咽喉,號令再也傳不出口")
		.rank(GameEnums.RankType.B)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.duration_rounds(2)
		.resolve_action(Callable(UltimateEffectLibrary, "silent_ghosts_resolve"))
		.build())

## 業火焚天:敵方全體受生命上限 28% 傷害,並體質 -15%,持續 2 回合。
static func _hellfire() -> Ultimate:
	return (UltimateBuilder.new()
		.name("業火焚天")
		.description("下一回合開始時,業火自天而降,敵方全體受生命上限 28% 傷害,並體質 -15%,持續 2 回合")
		.resolve_line("業火自天而降,焚盡敵軍軀體與意志")
		.rank(GameEnums.RankType.A)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.28)
		.secondary_ratio(0.15)
		.duration_rounds(2)
		.resolve_action(Callable(UltimateEffectLibrary, "hellfire_resolve"))
		.build())

## 腐蝕黑潮:敵方全體受生命上限 25% 傷害,並陷入「封印」1 回合。
static func _corrosive_tide() -> Ultimate:
	return (UltimateBuilder.new()
		.name("腐蝕黑潮")
		.description("下一回合開始時,黑潮腐蝕大地,敵方全體受生命上限 25% 傷害,並陷入封印,持續 1 回合")
		.resolve_line("黑潮腐蝕大地,敵軍武藝盡數鈍化")
		.rank(GameEnums.RankType.S)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.25)
		.duration_rounds(1)
		.resolve_action(Callable(UltimateEffectLibrary, "corrosive_tide_resolve"))
		.build())

## 深淵凝視:敵方全體受生命上限 25% 傷害,並陷入「恐懼」2 回合。
static func _abyssal_gaze() -> Ultimate:
	return (UltimateBuilder.new()
		.name("深淵凝視")
		.description("下一回合開始時,深淵睜眼凝視戰場,敵方全體受生命上限 25% 傷害,並陷入恐懼,持續 2 回合")
		.resolve_line("深淵睜眼凝視戰場,敵軍膽寒欲潰")
		.rank(GameEnums.RankType.SS)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.25)
		.duration_rounds(2)
		.resolve_action(Callable(UltimateEffectLibrary, "abyssal_gaze_resolve"))
		.build())

## 終焉審判:敵方全體受生命上限 35% 傷害,並陷入「恐懼」2 回合 + 「封印」1 回合,三個效果
## 一次到位的壓軸奧義。
static func _final_judgment() -> Ultimate:
	return (UltimateBuilder.new()
		.name("終焉審判")
		.description("下一回合開始時,終焉之鐘敲響,敵方全體受生命上限 35% 傷害,並陷入恐懼(2 回合)與封印(1 回合)")
		.resolve_line("終焉之鐘敲響,審判降臨,萬軍膽裂魂散")
		.rank(GameEnums.RankType.SSS)
		.delay_rounds(1)
		.max_uses_per_battle(1)
		.effect_ratio(0.35)
		.duration_rounds(2)
		.resolve_action(Callable(UltimateEffectLibrary, "final_judgment_resolve"))
		.build())

## Party 建立時預設配置的奧義清單,目前所有小隊(含隨機生成的敵方小隊)都拿同一份。
static func default_ultimates() -> Array[Ultimate]:
	return build()
