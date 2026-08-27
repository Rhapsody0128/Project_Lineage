class_name UltimateBuilder
extends RefCounted

## 奧義建構器,鏈式組裝取代位置參數建構子,寫法比照 SkillBuilder(見 skill_builder.gd
## 開頭註解的理由)。用法:UltimateBuilder.new().name("天降甘霖").delay_rounds(1)....build()

var _ultimate := Ultimate.new()

func name(value: String) -> UltimateBuilder:
	_ultimate.name = value
	return self

func description(value: String) -> UltimateBuilder:
	_ultimate.description = value
	return self

func rank(value: GameEnums.RankType) -> UltimateBuilder:
	_ultimate.rank = value
	return self

func resolve_line(value: String) -> UltimateBuilder:
	_ultimate.resolve_line = value
	return self

func delay_rounds(value: int) -> UltimateBuilder:
	_ultimate.delay_rounds = value
	return self

func max_uses_per_battle(value: int) -> UltimateBuilder:
	_ultimate.max_uses_per_battle = value
	return self

func effect_ratio(value: float) -> UltimateBuilder:
	_ultimate.effect_ratio = value
	return self

func secondary_ratio(value: float) -> UltimateBuilder:
	_ultimate.secondary_ratio = value
	return self

func buffed_potential_types(value: Array[int]) -> UltimateBuilder:
	_ultimate.buffed_potential_types = value
	return self

func duration_rounds(value: int) -> UltimateBuilder:
	_ultimate.duration_rounds = value
	return self

func cast_action(value: Callable) -> UltimateBuilder:
	_ultimate.cast_action = value
	return self

func resolve_action(value: Callable) -> UltimateBuilder:
	_ultimate.resolve_action = value
	return self

func build() -> Ultimate:
	return _ultimate
