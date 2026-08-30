class_name InheritanceConstants
extends RefCounted

## 遺傳系統集中常數表:血統/素質/潛力各遺傳計算共用同一份,未來新增遺傳因素
## (特殊遺傳/突變等)也統一放這裡,方便集中調整,不要散落進各個 XxxInheritance 檔案。

const CHILD_STARTING_AGE := 1

## 血統變異機率表,key 是變異倍率(字串,配合 Util.get_random_chance_item() 的
## Dictionary[String, float] 簽名),value 是機率權重。實際變量 = 倍率 * Bloodline.STEP。
const BLOODLINE_MUTATION_CHANCES: Dictionary = {
	"0": 60.0, # 普通遺傳
	"1": 30.0, # 輕微變異
	"2": 10.0, # 大變異
}

## 「血統純化」科技線(TechEffectType.BLOODLINE_MUTATION_SHIFT_ADD)的「偏移階數」:
## 每一階把 10 點權重從「普通遺傳」搬到「輕微變異」、5 點權重從「輕微變異」搬到
## 「大變異」,搬移量各自不超過來源目前剩餘的權重(minf 夾住),不會搬出負數權重。
## BloodlineInheritance.inherit() 一律呼叫這支函式,不要直接讀 BLOODLINE_MUTATION_CHANCES。
static func bloodline_mutation_chances() -> Dictionary:
	var shift := int(TechStore.get_bonus(GameEnums.TechEffectType.BLOODLINE_MUTATION_SHIFT_ADD))
	var zero: float = BLOODLINE_MUTATION_CHANCES["0"]
	var one: float = BLOODLINE_MUTATION_CHANCES["1"]
	var two: float = BLOODLINE_MUTATION_CHANCES["2"]
	for i in range(shift):
		var move_to_one := minf(10.0, zero)
		zero -= move_to_one
		one += move_to_one
		var move_to_two := minf(5.0, one)
		one -= move_to_two
		two += move_to_two
	return {"0": zero, "1": one, "2": two}

const POTENTIAL_STAT_VARIANCE_RATIO := 0.1 # 素質理論值 ±10%
const POTENTIAL_STAT_MIN := 0.0
const POTENTIAL_STAT_MAX := 200.0 # 對應 Potential 註解「區間 0-200」

const POTENTIAL_RATIO_VARIANCE := 0.2 # 潛力 ratio 理論值 ±0.2(絕對值,非比例)
const POTENTIAL_RATIO_MIN := Potential.BASE_RATIO
const POTENTIAL_RATIO_MAX := Potential.MAX_RATIO
